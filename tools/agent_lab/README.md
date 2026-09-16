# agent_lab

Offline testing ground for Arkad's chat + analysis prompts, against real
backed-up data, without running the app. Uses free OpenRouter models so
tuning wording doesn't cost anything.

The prompt copy in `prompts/*.md` is a tinkering copy of `assets/prompts/*.md`
(the app's actual, shipped prompts, loaded at runtime by
`lib/services/prompt_loader.dart`). Tune wording here, then hand-copy the
finished text back into `assets/prompts/`.

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env   # fill in SUPABASE_SERVICE_ROLE_KEY
```

`SUPABASE_SERVICE_ROLE_KEY` is a much higher-privilege secret than the anon
key already in the repo root `.env` — it bypasses RLS entirely, which is
exactly what's needed to look someone up by email. Keep it only in this
folder's `.env` (gitignored), never in the app's.

`SUPABASE_URL` and `OPENROUTER_DEBUG_API_KEY` are read straight from the repo
root `.env` — no need to duplicate them here.

## Usage

```bash
# 1. Fetch a real backup by email
python fetch_backup.py --email you@example.com

# 2. Chat against it interactively
python tui_chat.py --backup backups/you@example.com.json --model <slug> --show-prompt

# 3. Run the four analysis prompts and get a report
python analyze.py --backup backups/you@example.com.json --period month --out output/

# Reproduce a report for a historical end date
python analyze.py --backup backups/you@example.com.json --period week --as-of 2026-09-05 --out output/
```

Check [openrouter.ai/models](https://openrouter.ai/models) for current
`:free` model slugs, and either pass `--model` each time or set
`OPENROUTER_MODEL` in `.env`.

## Known simplifications vs. the app

- `tui_chat.py` sends the most recent 40 transactions as context; it doesn't
  port the app's keyword/date relevance-matching (`_relevantTransactions` in
  `openrouter_service.dart`) — real data is enough for tuning wording.
- `analyze.py` doesn't build a "previous check-in" continuity block — that
  depends on previously-saved analyses, which aren't part of a raw backup.
- Currency/date formatting is approximate (plain `$`/ISO dates), not
  locale-aware like the app's `formatCurrency`/`formatDate`.

None of this affects the persona/instructional prompt text itself — that's
byte-identical to what ships in the app.
