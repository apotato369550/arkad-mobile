import 'package:supabase_flutter/supabase_flutter.dart';
import 'persistence_service.dart';

/// Thrown for cloud-backup failures that have a message worth showing the
/// user (as opposed to being silently retried on the next scheduled run).
class CloudBackupException implements Exception {
  CloudBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper around the Supabase client for the one thing this app uses
/// it for: backing up and restoring a single JSON snapshot per user.
///
/// Identity model: enabling backup silently creates an anonymous Supabase
/// user (see `signInAnonymously`) so backups start immediately with zero
/// signup friction. That's enough to survive an app reinstall on the *same*
/// device, but an anonymous session doesn't transfer to a new device — for
/// that, [linkEmail]/[verifyEmailCode] upgrade the anonymous user to a
/// permanent one identified by email (Supabase's "anonymous sign-in
/// linking" flow), preserving the same user id and therefore the same
/// backup row. Email verification uses a 6-digit OTP typed into the app
/// rather than a magic link, so there's no deep-link/URL-scheme setup on
/// the Flutter side — see the setup instructions for the one Supabase
/// dashboard change (email template) this requires.
class CloudBackupService {
  static const _table = 'backups';

  /// Set once by `main.dart` after a successful `Supabase.initialize` (which
  /// only runs when `.env` has `SUPABASE_URL`/`SUPABASE_ANON_KEY` set — see
  /// [AppConfig.isCloudBackupConfigured]). `Supabase.instance` asserts if
  /// queried before initialization, so this flag — not a live probe — is
  /// what every method below checks first.
  static bool configured = false;

  SupabaseClient get _client => Supabase.instance.client;

  bool get isConfigured => configured;

  User? get currentUser => configured ? _client.auth.currentUser : null;

  /// True once the backup identity is tied to an email — i.e. restorable on
  /// a device other than the one that created it.
  bool get isLinkedToEmail => currentUser?.email != null && currentUser!.isAnonymous == false;

  Future<void> _ensureSession() async {
    if (!configured) {
      throw CloudBackupException('Cloud backup isn\'t configured for this build.');
    }
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } on AuthException catch (e) {
      throw CloudBackupException(e.message);
    }
  }

  /// Uploads the current local state as this user's backup, overwriting
  /// whatever was there before — the backup is a snapshot, not a history.
  Future<void> backupNow(PersistenceService persistence) async {
    await _ensureSession();
    final userId = _client.auth.currentUser!.id;
    try {
      await _client.from(_table).upsert({
        'user_id': userId,
        'data': persistence.buildBackupSnapshot(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw CloudBackupException(e.message);
    }
  }

  /// Fetches the current user's backup snapshot, or null if none exists yet.
  Future<Map<String, dynamic>?> fetchBackup() async {
    await _ensureSession();
    final userId = _client.auth.currentUser!.id;
    try {
      final row = await _client.from(_table).select('data').eq('user_id', userId).maybeSingle();
      return row?['data'] as Map<String, dynamic>?;
    } on PostgrestException catch (e) {
      throw CloudBackupException(e.message);
    }
  }

  /// Fetches and applies the current user's backup snapshot on top of local
  /// state. Throws [CloudBackupException] if there's nothing to restore.
  Future<void> restore(PersistenceService persistence) async {
    final snapshot = await fetchBackup();
    if (snapshot == null) {
      throw CloudBackupException('No backup found for this account yet.');
    }
    await persistence.restoreBackupSnapshot(snapshot);
  }

  /// Step 1 of linking: sends a 6-digit code to [email]. If the current
  /// session is still anonymous, this is an *email change* request (keeps
  /// the same user id/backup); otherwise it's a fresh sign-in.
  Future<void> sendEmailCode(String email) async {
    await _ensureSession();
    try {
      if (_client.auth.currentUser?.isAnonymous ?? false) {
        await _client.auth.updateUser(UserAttributes(email: email));
      } else {
        await _client.auth.signInWithOtp(email: email);
      }
    } on AuthException catch (e) {
      throw CloudBackupException(e.message);
    }
  }

  /// Step 2 of linking: verifies the code sent by [sendEmailCode].
  Future<void> verifyEmailCode({required String email, required String code}) async {
    final wasAnonymous = _client.auth.currentUser?.isAnonymous ?? false;
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: wasAnonymous ? OtpType.emailChange : OtpType.email,
      );
    } on AuthException catch (e) {
      throw CloudBackupException(e.message);
    }
  }
}
