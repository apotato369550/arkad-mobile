# Arkad

A personal finance tracker, built with Flutter. You manage a transaction ledger by hand or by talking to an AI agent in plain language, and get AI-written spending analyses on top of it. No backend of its own — persistence is on-device, and AI calls go straight from the app to OpenRouter.

See [`IDEA.md`](IDEA.md) for the original product concept and [`STYLE_GUIDE.md`](STYLE_GUIDE.md) for the "ledger in the garden" design system (colors, type, shape language, component specs).

## Features

- **Dashboard** — balance blob, income/expense stat cards, a cash-flow chart, and recent activity, with a date-range selector (week/month/year).
- **Transactions** — full ledger, week-paginated list, add/edit modal with an icon-grid category picker (categories color-coded red for expense, green for income), view-before-edit, and search.
- **Categories** — create/delete custom categories per type, pick a brand icon per category from an icon grid.
- **Analysis** — on-demand and automatic AI-written breakdowns of spending (income/expense totals, goal progress, cost-cutting ideas, overall assessment, actionable steps) over a period, saved for later reference, rendered as Markdown.
- **Chat** — natural-language transaction entry ("I spent $12 on lunch at Chipotle") and free-form spending Q&A with the AI agent; conversation history is kept and browsable.
- **Export** — ledger and analysis exported as a formatted, tabular PDF (with charts and rendered Markdown).
- **Profile & onboarding** — display name, country/currency, occupation, financial goal, collected through a short onboarding flow and editable later.
- **Settings** — BYOK OpenRouter API key + model slug (masked, stored in secure storage), clear key, clear all data.

## AI integration (BYOK)

The app never ships its own OpenRouter key. Each user supplies their own key in Settings; it's stored in secure storage on-device and sent directly from the app to OpenRouter — never to any Arkad-run server. Without a key configured, AI features explain that clearly and point to Settings rather than failing silently.

For local development, you can drop a debug-only key in `.env` (never committed) so you don't have to configure Settings on every run:

```
DEBUG_MODE=true
OPENROUTER_DEBUG_API_KEY=sk-or-...
```

This only takes effect in debug builds (see `lib/services/app_config.dart`).

## Stack

- Flutter (Dart SDK `^3.12.2`), Material.
- `google_fonts` (Fraunces, Manrope, DM Mono per the style guide), `fl_chart` for charts, `flutter_markdown` for rendered analysis text.
- `shared_preferences` for versioned local data, `flutter_secure_storage` for the API key.
- `http` + `flutter_dotenv` for the OpenRouter integration and local debug config.
- `pdf` + `printing` for PDF export.

No backend, no accounts, no sync — everything lives on-device.

## Project structure

```
lib/
  models/     data classes (transaction, category, profile, conversation, saved analysis, ...)
  services/   AppState (app-wide state/persistence), OpenRouter client, PDF export, formatters
  screens/    one file per top-level screen/tab
  widgets/    reusable UI (modals, cards, charts, list rows)
  theme/      colors, radii, text styles
```

## Getting started

```
flutter pub get
flutter run
```

To regenerate app icons/splash after changing `assets/icon/*` (config lives in `pubspec.yaml` under `flutter_launcher_icons` / `flutter_native_splash`):

```
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Status

Personal/hobby-scale project — no backend, no test suite, no multi-user concerns. Frontend and aesthetics are the current focus; the OpenRouter integration is real (not mocked).
