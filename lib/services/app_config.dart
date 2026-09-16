import 'package:flutter/foundation.dart' show kDebugMode;

/// Build-time configuration. No secrets are loaded from Flutter assets: assets
/// ship in every APK/IPA and can be extracted.
class AppConfig {
  static const _devApiKey = String.fromEnvironment('ARKAD_DEV_OPENROUTER_KEY');
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isDebugMode => kDebugMode;

  /// Convenience key for local development only. A debug artifact built with
  /// this define contains the key and must never be distributed.
  static String? get debugApiKey {
    if (!kDebugMode || _devApiKey.trim().isEmpty) return null;
    return _devApiKey.trim();
  }

  static String? get supabaseUrl => _supabaseUrl.trim().isEmpty ? null : _supabaseUrl.trim();
  static String? get supabaseAnonKey => _supabaseAnonKey.trim().isEmpty ? null : _supabaseAnonKey.trim();
  static bool get isCloudBackupConfigured => supabaseUrl != null && supabaseAnonKey != null;
}
