# Repository Guidelines

## Project Structure & Module Organization

Arkad is a Flutter personal finance app with local persistence, OpenRouter AI features, and optional Supabase cloud backup. Application code lives in `lib/`: `models/` contains data classes, `services/` handles state, persistence, API calls, and exports, `screens/` contains pages, `widgets/` holds reusable UI, and `theme/` defines design tokens. `lib/main.dart` initializes the app.

Tests live in `test/`. Images, fonts, and shipped AI prompts live in `assets/`; register new bundled assets in `pubspec.yaml`. Platform projects are in `android/`, `ios/`, and `web/`. `tools/agent_lab/` contains Python utilities and experimental prompt copies; move finalized prompt changes into `assets/prompts/`.

## Build, Test, and Development Commands

Use Flutter with Dart compatible with `^3.12.2`, as specified in `pubspec.yaml`.

- `flutter pub get` — install dependencies.
- `flutter run` — launch on a connected device or emulator.
- `flutter analyze` — run static analysis with `flutter_lints`.
- `dart format lib test` — format Dart source and tests.
- `flutter test` — run all automated tests.
- `flutter test test/openrouter_service_test.dart` — run parser regression tests.
- `flutter build apk --release` — build an Android release APK; signing requires local configuration.

## Coding Style & Naming Conventions

Use two-space indentation and Dart formatter output. Name files `snake_case.dart`, classes `UpperCamelCase`, and members `lowerCamelCase`; prefix private members with `_`. Follow existing single-quoted strings. Keep business logic in services and reusable presentation in widgets. Reuse `lib/theme/` tokens and follow `STYLE_GUIDE.md` for colors, typography, and shapes.

## Testing Guidelines

Use `flutter_test`, with `*_test.dart` filenames and descriptive behavior-based test names. Existing tests cover onboarding and OpenRouter response parsing. Mock preferences and initialize dotenv in widget tests, following `test/widget_test.dart`. Add regression coverage for changed behavior, including malformed AI responses when relevant. No coverage threshold is configured. Run analysis and tests before submitting code changes.

## Commit & Pull Request Guidelines

Recent commits use `feat:`, `fix:`, and `refactor:` prefixes with concise descriptions. Follow that convention and keep commits focused. PRs should describe the problem and resulting behavior, link relevant issues, report validation, and include screenshots for UI changes.

## Security & Configuration

Keep `.env`, API keys, signing credentials, and backup data out of commits. Create an empty local `.env` for builds, since it is declared as an asset. Never package private keys in release assets. See `SUPABASE_SETUP.md` for cloud backup configuration.
