# Arkad debug quickstart

Run Arkad locally with your own OpenRouter key without typing it into the app
on every install.

## Prerequisites

- Flutter with Dart compatible with `^3.12.2`
- A connected Android/iOS device or a running emulator
- An [OpenRouter API key](https://openrouter.ai/keys) for AI features

## First run

```bash
flutter pub get
cp .env.example .env
```

Edit `.env` and set your local development key:

```env
ARKAD_DEV_OPENROUTER_KEY=sk-or-v1-...
```

Then start the app:

```bash
./scripts/run_debug.sh
```

Pass normal `flutter run` arguments through the script when needed:

```bash
./scripts/run_debug.sh -d emulator-5554
```

The script calls Flutter with `--dart-define-from-file=.env`. The key is used
only by `kDebugMode`; profile and release builds ignore it and use the key a
user saved in Settings instead.

## Optional cloud backup configuration

Cloud backup is disabled unless both public Supabase values are in `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-publishable-anon-key
```

Follow [SUPABASE_SETUP.md](SUPABASE_SETUP.md) to configure the project and
row-level-security policy.

## Safety boundary

`.env` is gitignored and must stay local. A debug APK built with
`ARKAD_DEV_OPENROUTER_KEY` contains that key, so do not share, upload, or
otherwise distribute that APK. Never place an OpenRouter key or Supabase
service-role key in a release build.

## Checks

```bash
flutter analyze
flutter test
```
