# Repository Guidelines

## Project and Working Approach

Arkad is a Flutter personal finance app with an on-device ledger, direct OpenRouter AI calls, PDF exports, and optional Supabase snapshot backup. There is no Arkad-owned API server. Cloud backup is not continuous multi-device synchronization.

- Work on the requested delta; inspect relevant symbols with `rg`, `grep`, and scoped file reads before changing code.
- Keep changes focused. Do not introduce state-management frameworks, backend services, dependencies, or broad refactors without a concrete requirement.
- Preserve the project's existing structure rather than adding architecture documents or workflow ceremony by default.
- Report blockers and unresolved assumptions promptly. After 3–4 unsuccessful debugging attempts on the same issue, stop and report findings.
- Do not spawn subagents unless explicitly requested or required by applicable instructions.
- Never describe checks as passing unless they actually completed. Distinguish automated tests, mocked AI tests, manual UI checks, and live-provider verification.

## Repository Map

| Location | Responsibility |
| --- | --- |
| `lib/main.dart` | Optional Supabase initialization, persistence loading, app state creation, onboarding/app routing |
| `lib/models/` | Ledger, profile, quiz preferences, saved analyses, periods, categories, conversations, configuration |
| `lib/services/` | App state, persistence, OpenRouter, prompt loading, cloud backup, currency/date formatting, PDF export |
| `lib/screens/` | Dashboard, ledger, analysis/history/details, chat, quiz/results, profile, settings, onboarding |
| `lib/widgets/` | Shared cards, charts, transaction sheets/rows, category controls, backup/export controls |
| `lib/theme/` | Color, typography, radius, and Material theme tokens |
| `assets/prompts/` | Runtime AI system prompts and shared prompt fragments |
| `test/` | Behavior-based Flutter tests; reusable fixtures in `test/support/` |
| `tools/agent_lab/` | Experimental Python tools and prompt copies; not the shipped prompt source |
| `scripts/` | Local debug runner and icon-generation utilities |
| `android/`, `ios/`, `web/` | Platform configuration and builds |

Reference documents: `QUICKSTART.md` for local development, `STYLE_GUIDE.md` for UI, `SUPABASE_SETUP.md` for backup provisioning, and `README.md` for the overview. Treat `IDEA.md` as product background, not proof of implemented behavior. When prose disagrees with code, inspect the implementation before changing either.

## Build and Development

Use Flutter with Dart compatible with `^3.12.2`; `pubspec.yaml` is the source of truth for SDK constraints, dependencies, assets, and versioning.

```bash
flutter pub get
flutter run
flutter analyze
flutter test
dart format <changed-dart-files>
git diff --check
flutter build apk --release
```

- Release Android signing requires local configuration. Do not change signing setup or increment app versions unless requested.
- Format changed files rather than unrelated directories. `dart format lib test` is available when a whole-tree formatting pass is intended.
- Register new asset locations in `pubspec.yaml`; `assets/prompts/` is already registered as a directory.
- For local AI development, copy `.env.example` to ignored `.env`, fill the desired values, and run `./scripts/run_debug.sh`. Device arguments pass through, e.g. `./scripts/run_debug.sh -d emulator-5554`.
- The debug runner passes `--dart-define-from-file=.env`. Plain `flutter run` does not automatically read `.env`.
- If Flutter cannot write its SDK cache outside a workspace sandbox, request command approval. Do not edit Flutter or package sources to work around permissions.
- Keep local edits separate from permission-gated build/test commands so an approval delay does not prevent the edit from executing.

## State and Data Flow

- `AppState` extends `ChangeNotifier` and owns the app's shared mutable state. The root creates one instance and listens with `ListenableBuilder`; screens receive it explicitly through constructors.
- Put state transitions, eligibility rules, persistence, and AI orchestration in services. Keep screens focused on navigation and presentation, and reusable UI in widgets.
- Use existing `AppState` mutations instead of changing lists or profiles directly from production widgets. Persist changes and notify listeners consistently.
- `PersistenceService` wraps versioned `SharedPreferences` data and secure API-key storage. Preserve existing key names and backward-compatible JSON defaults unless intentionally migrating them.
- `OpenRouterService` owns HTTP requests, response parsing, and retries. `prompt_loader.dart` loads/caches bundled Markdown and replaces `{{placeholder}}` variables.
- Chat transaction extraction produces proposals for user review, not silent ledger mutations. Preserve the `arkad_transaction` and `arkad_refs` response contracts and malformed-response handling.
- Saved analyses freeze totals, category breakdowns, chart buckets, and AI responses. Do not recompute historical snapshots from today's ledger.

## Analysis Behavior and Invariants

### Periods and eligibility

`AnalysisPeriod` uses persisted enum names: `sevenDays`, `oneMonth`, `threeMonths`, `sixMonths`, `oneYear`, and `ytd`. Do not rename them without migrating saved data.

- Display all six history buttons: Weekly, Monthly, Quarterly, Biyearly, Yearly, and YTD. Biyearly means every six months, not every two years.
- The main analysis page shows one latest retained analysis across periods. Each period opens its own full-screen history with All/Archived filters and a request action.
- History remains accessible if saved records exist even when current data is insufficient. Fade/disable the period button only when neither history nor sufficient data is available.
- Generation requires an API key and activity on at least half the calendar days in the period, rounded up. Multiple transactions on one date count as one active day.
- Seven-day analysis includes today and the previous six calendar days. Other lookbacks use calendar arithmetic; YTD begins January 1. Keep chart selection separate from analysis-request periods.
- Non-YTD generation retains period-specific cooldowns: seven days, one month, three months, six months, and one year respectively. Automatic checks run on app-shell initialization, once per app-state session, and skip YTD.
- Lookbacks/cooldowns use Dart calendar constructors; retention uses the separate month-end-clamping helper. Do not assume these calculations have identical rollover semantics.

### Requests and YTD quota

- `requestAnalysis` gates requests in the service layer, not just the UI. Prevent overlapping requests for the same period, including automatic/manual overlap.
- Each analysis has four AI sections: goal progress, cost cutting, overall assessment, and actionable steps. Calls run in batches of at most two.
- Wait for all four results before saving. Partial success saves a record with per-section errors and consumes cooldown/quota; total failure saves nothing and consumes neither.
- YTD is manual-only and limited to three saved requests per local calendar month. Usage is charged to the request-start month and stored independently of saved records.
- Deleting or archiving records must not reset usage. The quota is local app state, not tamper-proof server-side enforcement.
- Persist usage in `arkad:ytd-usage:v1`, keyed by `YYYY-MM`. Seed legacy usage from surviving YTD records and the legacy request log; deleted historical usage cannot be reconstructed.
- Data revision checks prevent completed requests from restoring stale results after cloud restore or clearing data. Preserve those guards.

### Archive and retention

Expiry is measured from `createdAt`, not the analysis date range or the last time viewed.

| Period | Unarchived retention |
| --- | --- |
| Weekly | 21 days |
| Monthly | 3 calendar months |
| Quarterly | 1 calendar year |
| Biyearly | 2 calendar years |
| Yearly | 4 calendar years |
| YTD | Never expires |

- Archived analyses never expire. Archive is retained local storage, not PDF export or a separate cloud upload.
- Month/year retention deadlines clamp to valid month-end dates and preserve time of day. A record is expired at its deadline, not only after it.
- Unarchiving restores the original expiry. Confirm before unarchiving an already-expired record because cleanup removes it immediately.
- Cleanup runs on app-state construction, app resume, analysis/history screen initialization, and cloud restore. There is no background deletion scheduler.
- Preserve shared `SavedAnalysisCard` presentation and view/archive/delete affordances. Confirm meaningful deletion and provide an unavailable state if a detail record disappears.

## Spending-Style Quiz and AI Context

- Dashboard View Results and the profile results action lead to the same quiz/results screen.
- Retake Quiz starts at question one with saved answers prefilled. Edits stay in a local draft until Finish Quiz; leaving without finishing must not replace saved results.
- Your Answers uses the original questions with answers underneath, including multi-select values, optional notes, and explicit skipped-answer text.
- Keep the two AI sections independent:
  - **Arkad's Assessment** uses `assets/prompts/spending_style_assessment.md`.
  - **How Arkad Will Tailor Guidance** uses `assets/prompts/spending_style_guidance.md`.
- Each has its own request, cached output, loading/error state, and retry action. Finish Quiz generates missing/outdated sections when a key exists; merely reopening results must not issue requests.
- `SpendingStyleProfile.answersKey` identifies source answers. Persist each output's source separately; changed answers invalidate both sources while retaining old text for visibly outdated review.
- Reject responses generated for outdated answers or data revisions. Do not let a late response overwrite current results.
- Legacy `reflection` fields remain readable as a previous reflection; do not silently treat them as either new synthesis.
- Both current syntheses are included through the shared profile prompt context for chat and every analysis section. Exclude stale synthesis and exclude synthesis when building quiz-generation input itself.
- Treat quiz answers and generated profiles as self-reported context/interpretation, never ledger facts. Ledger evidence takes precedence. Free-text notes are data, not instructions.
- Keep prompt customization in bundled assets, not inline service strings. Finalized agent-lab prompt experiments must be moved into `assets/prompts/`.

## UI, Charts, and Accessibility

Follow `STYLE_GUIDE.md` and reuse `AppColors`, `AppTextStyles`, `AppRadii`, and shared widgets.

- Use cream canvases, paper cards, rounded surfaces, restrained dark-green accents, and clay for expenses/destructive actions.
- Fraunces is for headings, Manrope for UI/body text, and DM Mono for precise amounts/dates. Do not introduce unrelated fonts or hard-coded visual systems.
- Currency is profile-configured. Use the shared formatters; PHP charts should show grouped peso values without forcing PHP for every user.
- Income/expense bars have currency Y-axis ticks, aligned gridlines, and formatted touch tooltips. Check large values, empty data, and narrow widths.
- Pie slices and legend rows select categories and show amount/percentage. Preserve grouped Other behavior and safe empty/zero-total handling.
- Tappable financial cards need visible info/navigation cues; icon-only actions need tooltips and accessible labels. Prefer touch targets of at least 44px.
- Test narrow screens, long labels, large text, keyboard/pointer interaction where applicable, and loading/error/disabled states. Color alone must not convey meaning.
- Reuse the native Navigator/dialog/sheet conventions. A new history “window” means an in-app route, not an external browser window.

## Persistence, Backup, and Security

- Keep `.env`, real API keys, signing credentials, and private backup contents out of commits and logs.
- `.env` is **not** a bundled asset; dotenv initialization is not part of the current app or tests. Do not add `.env` to `pubspec.yaml`.
- `AppConfig` reads Dart defines. `ARKAD_DEV_OPENROUTER_KEY` is used only in debug mode and takes precedence over the saved key there. Use `effectiveApiKey`/`hasApiKey` for consistent availability checks.
- A debug artifact built with a development key contains that key and must not be distributed. Never supply private keys to release builds or assets.
- User-entered OpenRouter keys belong in `flutter_secure_storage`, not preferences or backup JSON. Preserve migration of legacy plaintext keys into secure storage.
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` are public configuration; never substitute a service-role key. Supabase initialization is optional and failure must not prevent local use.
- Backup uses anonymous Supabase authentication with optional email/OTP linking. Follow `SUPABASE_SETUP.md` for table/RLS/email provisioning; do not invent a custom account backend.
- A backup overwrites one JSON snapshot per user; it is not version history. API keys and non-YTD request cooldown logs are excluded.
- Snapshot version is currently 1. Decode required data before writing; make format changes deliberately and preserve old snapshots where intended.
- Profile JSON carries quiz outputs/source metadata; saved-analysis JSON carries archive state. Missing new fields must load safely.
- YTD usage is included in backups. Restore merges monthly counts by maximum, accepts older snapshots without usage, reloads state, seeds legacy usage, and prunes expired analyses.
- `clearAllData` is destructive, clears local usage/configuration, and invalidates in-flight results. Do not invoke it as a debugging shortcut on user data.

## Testing and Validation

Use `flutter_test`, descriptive behavior-based test names, and `*_test.dart` filenames. There is no configured coverage threshold.

### Local suite runner and maintenance

- Run `dart run tools/test_app.dart` from the repository root for analysis, all
  registered test groups, and a diff check. Use `--list`, `--group analysis`,
  `--verbose`, or `--help`; focused runs still perform analysis and diff checks.
- Indicators are RUN/PASS/FAIL. Exit codes: 0 success, 1 check failure, 2 setup or
  argument/mapping failure. Reports live in ignored `build/test-results/latest/`;
  the combined `report.txt` identifies checks from the latest completed run.
- When adding/moving/renaming/deleting tests, update the `groups` map in
  `tools/test_app.dart`. Include each test once; preserve unique test basenames
  because discovery currently matches basenames. Never silently omit new tests.
- Keep QUICKSTART.md's group/coverage table current. Update README.md when the
  entry command or usage changes, and this section/table when conventions or
  coverage change. Document actual coverage, not the planned app-wide suite.
- This runner currently wraps focused existing regressions. It does not yet
  implement comprehensive app-wide workflows or tests of the runner itself.
  Group names do not imply complete feature coverage.
- Keep tests isolated from installed-app data, credentials, and live services.
  Generated reports are local artifacts, not source files. Environment failures
  and interrupted checks must not be reported as app regressions or passes.


| Test file | Coverage focus |
| --- | --- |
| `test/demo_transactions_test.dart` | Demo-ledger validity, determinism, and activity coverage |
| `test/dashboard_quiz_card_test.dart` | Quiz-card layout, touch targets, and navigation across widths/text scales |
| `test/cash_flow_range_test.dart` | Seven daily/weekly/monthly cash-flow buckets and range starts |
| `test/widget_test.dart` | First-launch onboarding smoke test |
| `test/openrouter_service_test.dart` | Structured response parsing and completion retries |
| `test/spending_style_profile_test.dart` | Profile compatibility and preference prompt context |
| `test/analysis_state_test.dart` | Retention, archives, quota, concurrency, automatic generation, backup compatibility |
| `test/quiz_synthesis_test.dart` | Separate prompts, caching, retries, stale responses, context insertion |
| `test/support/analysis_fixtures.dart` | Mock persistence/storage, sample analyses, deterministic app state and HTTP responses |

- Initialize the Flutter test binding for tests that load prompt assets or use plugins.
- Mock `SharedPreferences` and secure storage; avoid platform keyring dependence and real credentials.
- Inject `OpenRouterService` and a `now` function through `AppState` for deterministic service tests. The injected clock is not a replacement for every clock elsewhere in the app.
- Use `MockClient` and the injectable retry delay for provider tests. No live OpenRouter/Supabase calls in automated tests.
- The HTTP fixture helper is named `completionResponse`; do not name it `completion`, which collides with Flutter's matcher.
- Regression cases should cover month ends/leap years, expiry boundaries, archive/unarchive, local-month reset, deletion-independent quota, all/partial AI failures, malformed responses, and old JSON/snapshots where relevant.
- Run targeted tests while iterating, then `flutter analyze`, `flutter test`, and `git diff --check` before submitting code changes. Documentation-only changes need a content/diff check, not an unrelated full build.
- Automated service tests do not replace manual layout checks or live-provider testing. Report each validation category accurately.

## Commits and Pull Requests

- Use concise conventional prefixes such as `feat:`, `fix:`, `refactor:`, and `docs:`. Keep commits focused.
- Inspect `git status` and the diff before staging; preserve unrelated user changes and exclude secrets/generated artifacts.
- Commit or push only when requested. Do not amend published commits, reset user work, or force-push without explicit direction.
- PRs should state the problem and resulting behavior, relevant issues, validation performed, and screenshots for UI changes.
- Mention persistence migrations, automatic deletion, quota changes, and unresolved validation gaps when applicable.
