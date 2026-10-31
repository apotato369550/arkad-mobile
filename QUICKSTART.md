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

## Analysis demo ledger

A debug build with no stored ledger generates 24 calendar months of synthetic
income/expenses through today. It includes daily activity for all six analysis
periods, salary with a raise, allowance, freelance income, gifts, December bonuses,
recurring bills, discretionary spending, and occasional large expenses.
Amounts are illustrative currency units, not currency-converted local prices.

Existing stored transactions are left unchanged. To try the expanded seed without
replacing your data, use a separate fresh emulator/device installation. Hot reload
will not replace an existing ledger. Release builds do not seed demo data.
Analysis still requires an API key and follows normal cooldown/quota rules;
automatic non-YTD requests may run when the app shell initializes with a key.
This dataset exercises populated analyses, not insufficient-data or empty-ledger UI.

## Local correctness checks

Run commands from the repository root with Flutter and Dart on your PATH.
No emulator, `.env`, API key, or live OpenRouter/Supabase account is required.
Initial dependency setup may require internet access:

```bash
flutter pub get
dart run tools/test_app.dart
```

### Choose what to run

```bash
dart run tools/test_app.dart --help
dart run tools/test_app.dart --list
dart run tools/test_app.dart --group analysis
dart run tools/test_app.dart --group quiz --verbose
```

Even a focused group run includes `flutter analyze` and `git diff --check`.
Without `--group`, all registered groups run sequentially:

| Group | Current coverage (not full feature coverage) |
| --- | --- |
| `onboarding` | First-launch onboarding smoke test |
| `ledger` | Demo-ledger validity, reproducibility, analysis activity coverage |
| `dashboard` | Daily/weekly/monthly cash-flow bucket ranges; quiz-card layout and navigation |
| `analysis` | Retention, archives, YTD quota, overlap, automatic requests, backup compatibility |
| `quiz` | Profile compatibility, prompt context, separate syntheses, caching/retries/stale responses |
| `chat` | Shell navigation, responsive hub/conversation layout, single-line keyboard behavior; parsing/retries; hub send/reply UI; archive/quote compatibility; stale replies; currency; image normalization, multimodal requests and v2 snapshots |

### Read the result

- `[RUN ]`: a check is executing; `[PASS]`: it completed successfully;
  `[FAIL]`: it returned a failing result. Color is not required.
- Checks continue after test failures so you can see other results too.
- `--verbose` prints diagnostics after each check completes; it is not live streaming.
- Read `build/test-results/latest/report.txt` for the combined report, or the
  group `.log` files beside it for raw Flutter JSON events and diagnostics.
  Reports for executed checks are overwritten on rerun; unrelated old group logs
  may remain. Use the combined report to identify the current run's checks.
- Exit status `0` means requested checks passed, `1` means a check failed, and
  `2` means an argument/group mapping/executable setup error. An interrupted run
  is incomplete, not a pass.

If a check fails, read its log and rerun the affected group. For a single file:

```bash
flutter test test/analysis_state_test.dart
```

A missing Flutter executable, SDK-cache permission error, or dependency download
failure is an environment issue—not proof of an app bug. Group mapping errors
require updating the runner when tests are added/renamed. `diff-check` reports
whitespace problems in working-tree changes, not failed app behavior.

### Coverage limits and maintenance

This is a runner for existing focused regression tests, **not yet the complete
app-wide suite**. Ledger CRUD/search, full navigation and quiz workflows,
chat proposal interactions, settings, and exports still need expanded tests.
Native sharing, device behavior, real cloud access, visual polish, and AI advice
quality require separate QA; mocked AI tests do not validate advice quality.

**When adding, moving, renaming, or deleting tests:** update `groups` in
`tools/test_app.dart` so each test is included once. The runner rejects unassigned
test files and duplicate mapping entries. Keep test basenames unique with the
current basename-based discovery. Update this table and AGENTS.md when coverage
changes, and README.md when commands or entry points change. Do not claim planned
coverage as implemented or commit generated test reports.


## Chat attachments and browser checks

Open **Chat** in the sidebar as a regular app page (hamburger menu, not a back
arrow). Its single-line composer scrolls long text horizontally without growing.
History cards show the first user question, ellipsized to the card width.
After upgrading from the old pushed Chat route, hot restart rather than hot
reload so the previous navigation stack is cleared.
Send a message from the centered composer to create
and open a conversation. The sparkle shortcut focuses that composer. History
supports All/Archived filters and archive/unarchive/delete actions. Reply on an
Arkad response attaches a removable quote to your next message.

The paperclip selects up to 3 JPEG/PNG/WebP images. Inputs must be <=10 MiB and
20 megapixels each. Images are normalized to JPEG without source metadata,
resized to <=1600 pixels on the longest edge and <=1 MiB each. Retained images
are limited to 20 MiB, including archives; delete conversations to free space.
Images are sent to OpenRouter and retained in local history and optional backups.
An image-capable model is required; unsupported providers show errors rather than
silently switching models. Currency comes from Profile, not country inference.

Native attachments use app-private files; web attachments use IndexedDB.
Browser quotas/privacy settings can prevent storage or clear it later. Snapshot
v2 includes images; v1 restores remain supported. Older app versions cannot
restore v2. Backups fail rather than silently omit missing images.

```bash
dart run tools/test_app.dart --group chat
# Requires a Chrome installation; set CHROME_EXECUTABLE if it is not on PATH:
dart run tools/test_app.dart --group chat --web
```

The default runner explicitly skips browser-only storage checks. `--web` adds
`browser_test/chat_attachment_browser_test.dart` on Chrome. Picker/permissions,
real provider vision quality, full-size image presentation and actual cloud
payload limits still require separate device/browser/provider QA.


Chat UI regression tests cover 320px, 390px, and wide layouts at normal and 2×
text size. Local inspection images are written to `build/test-results/chat-ui/`.
These use a bundled fallback font for readable test rendering, not production
font-fidelity checks. Real-device typography, keyboard and picker QA remain separate.


### Chat appears to be thinking indefinitely

Chat now bounds the complete reply operation to 45 seconds, including preparation
and retries. A stalled request returns an error with Retry rather than keeping
the composer disabled. Use **Stop** to stop waiting earlier; your message remains
in history, and Retry does not add it a second time. Late responses are ignored.
Stop is local: it cannot guarantee that the provider stops processing or charging
for an HTTP request already sent. Hot restart after updating this code to clear
an old in-memory request. No data reset is needed.
