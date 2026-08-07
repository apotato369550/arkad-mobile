# The Ledger — Finance Tracker

A frontend-only personal finance tracker where you record and analyze transactions by talking to an AI agent in plain language, on top of a manually-managed transaction ledger. No backend — everything lives in the browser.

## Core idea

Two ways to manage your ledger:
1. **Manual** — add/edit/delete transactions directly through the UI.
2. **Conversational** — chat with an AI agent ("I spent $12 on lunch at Chipotle") that parses natural-language messages into structured transactions and appends them to the ledger, and can answer analysis questions about your spending.

The AI is BYOK (bring your own key): the user supplies their own OpenRouter API key in Settings. Without a key, the chat clearly explains that and points to Settings — it never fails silently. All calls are made directly from the browser to OpenRouter (`https://openrouter.ai/api/v1/chat/completions`), no proxy server.

## Design thesis — "The Ledger in the Garden"

Organic softness framing financial precision: soft, blob-like, heavily-rounded containers (cards, pills, an animated hero "balance blob") hold exact, monospaced ledger data. That contrast is the one signature idea everything else stays quiet around.

- **Colors**: `cream` (page bg), `paper` (card bg), `sage-tint` / `sage` (secondary surface/accent), `pastel-yellow` (primary accent), `ink` (primary text), `dark-green` (primary/income), `clay` (expense/negative only, used sparingly).
- **Type**: Fraunces (display/headlines/big numbers), Manrope (body/UI), IBM Plex Mono (every currency figure and date, nothing else — this is what makes the "precision" side of the contrast legible).
- **Shape language**: pill-shaped buttons and nav items, `rounded-2xl`+ cards, a slowly-morphing organic blob for the hero balance.

## What it contains

**Views** (left sidebar nav, ChatGPT-inspired: full-height column, nav items anchored toward the bottom)
- **Dashboard** — hero balance blob, income/expense stat cards, a 7-day income-vs-expense bar chart, and a recent-transactions list. Clicking a transaction jumps to Transactions and opens it.
- **Transactions** — full transaction list, "Add Transaction" modal, click any row to open an edit/delete modal.
- **Profile** — editable display name + lifetime income/expense/balance stats.
- **Settings** — OpenRouter API key (BYOK, masked) + model slug, clear key, clear all data.
- **Past Conversations** — opens the persistent chat drawer/history with the AI agent.
- **Chat** (floating action button, available from every view) — slide-in drawer, natural-language transaction entry and spending Q&A.

**Persistence**: browser `localStorage` only, versioned keys for transactions, API config, and chat history. No accounts, no sync, no server.

## Stack

React 19 + Vite + TypeScript + Tailwind CSS v4 (CSS-first `@theme` config, no `tailwind.config.js`), `lucide-react` for icons. No routing library or global state manager — a single view-state switch in `App.tsx`, state created once and prop-drilled down.

## Status

Frontend and aesthetics are the current focus; the OpenRouter integration is real (not mocked). This is a personal/hobby-scale project — no backend, no test suite, no multi-user concerns.
