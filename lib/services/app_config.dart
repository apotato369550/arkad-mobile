import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Debug-only escape hatch: in debug builds, an OpenRouter key from `.env`
/// (never committed) can stand in for a user-supplied BYOK key so the app is
/// usable during development without configuring Settings each time.
class AppConfig {
  /// Normally mirrors Flutter's own build mode, but `.env`'s `DEBUG_MODE`
  /// (`true`/`false`) overrides it when present — lets debug mode be flipped
  /// on a whim without switching between `flutter run` and a release build.
  /// Any other/missing value falls back to [kDebugMode].
  static bool get isDebugMode {
    switch (dotenv.maybeGet('DEBUG_MODE')?.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        return kDebugMode;
    }
  }

  static String? get debugApiKey {
    final key = dotenv.maybeGet('OPENROUTER_DEBUG_API_KEY');
    return (key == null || key.trim().isEmpty) ? null : key;
  }

  /// Project URL and anon (publishable) key for Supabase, used only for
  /// cloud backup. The anon key is safe to ship in the client — Postgres
  /// row-level security is what actually restricts access — but both are
  /// still read from `.env` (never committed) rather than hardcoded so a
  /// fresh checkout without a configured project degrades to "cloud backup
  /// unavailable" instead of pointing at someone else's Supabase project.
  static String? get supabaseUrl {
    final url = dotenv.maybeGet('SUPABASE_URL');
    return (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  static String? get supabaseAnonKey {
    final key = dotenv.maybeGet('SUPABASE_ANON_KEY');
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  static bool get isCloudBackupConfigured => supabaseUrl != null && supabaseAnonKey != null;
}
