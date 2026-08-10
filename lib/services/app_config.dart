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
}
