#!/usr/bin/env python3
"""Interactive terminal chat against a real backup, using the same
persona + chat_system prompt templates the app loads (tools/agent_lab/prompts/).
For tuning prompt wording before copying it back to assets/prompts/*.md.

Usage:
    python tui_chat.py --backup backups/you@example.com.json --show-prompt
"""

from __future__ import annotations

import argparse
from pathlib import Path

import requests
from dotenv import dotenv_values

from common import load_backup
from prompt_loader import render_prompt

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LAB_DIR = Path(__file__).resolve().parent
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
TRANSACTION_TAG = "arkad_transaction"
RECENT_N = 40


def _load_env() -> dict[str, str]:
    env = dict(dotenv_values(REPO_ROOT / ".env"))
    env.update(dotenv_values(LAB_DIR / ".env"))
    return env


def build_profile_block(profile: dict) -> str:
    parts = []
    if profile.get("displayName"):
        parts.append(f"User: {profile['displayName']}")
    if profile.get("countryCode"):
        parts.append(f"Country: {profile['countryCode']}")
    if profile.get("jobTitle"):
        parts.append(f"Job Title: {profile['jobTitle']}")
    if profile.get("occupationField"):
        parts.append(f"Field: {profile['occupationField']}")
    if profile.get("goalType"):
        goal = profile.get("goalOther") if profile["goalType"] == "Other" and profile.get("goalOther") else profile["goalType"]
        parts.append(f"Goal: {goal}")
    if profile.get("longTermGoal"):
        parts.append(f"Long-term Financial Goal: {profile['longTermGoal']}")
    if profile.get("typicalMonthlyIncome"):
        parts.append(f"Typical Monthly Income: ${profile['typicalMonthlyIncome']:,.2f}")
    if profile.get("savingsGoalAmount"):
        parts.append(f"Savings Goal: ${profile['savingsGoalAmount']:,.2f}")
    if not parts:
        return ""
    body = "\n".join(f"- {p}" for p in parts)
    return f"About the user:\n{body}\n\n"


def build_system_prompt(backup: dict) -> str:
    transactions = backup.get("transactions", [])
    total_income = sum(t["amount"] for t in transactions if t["type"] == "income")
    total_expense = sum(t["amount"] for t in transactions if t["type"] == "expense")

    recent = sorted(transactions, key=lambda t: t["date"], reverse=True)[:RECENT_N]
    transaction_lines = "\n".join(
        f"- {t['date'][:10]} · {t['merchant']} · {t['category']} · "
        f"{'+' if t['type'] == 'income' else '-'}${t['amount']:.2f}"
        for t in recent
    )

    income_categories = sorted({t["category"] for t in transactions if t["type"] == "income"})
    expense_categories = sorted({t["category"] for t in transactions if t["type"] == "expense"})

    return render_prompt(
        "chat_system",
        {
            "persona": render_prompt("persona", {}),
            "profile_block": build_profile_block(backup.get("profile", {})),
            "ledger_count": str(len(transactions)),
            "total_income": f"{total_income:.2f}",
            "total_expense": f"{total_expense:.2f}",
            "transaction_lines": transaction_lines or "(none)",
            "income_categories": ", ".join(income_categories) or "(none)",
            "expense_categories": ", ".join(expense_categories) or "(none)",
            "transaction_tag": TRANSACTION_TAG,
        },
    )


def chat_completion(api_key: str, model: str, messages: list[dict]) -> str:
    resp = requests.post(
        ENDPOINT,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json={"model": model, "messages": messages},
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"].strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", required=True)
    parser.add_argument("--model", default=None, help="OpenRouter model slug (default: $OPENROUTER_MODEL)")
    parser.add_argument("--show-prompt", action="store_true")
    args = parser.parse_args()

    env = _load_env()
    api_key = env.get("OPENROUTER_DEBUG_API_KEY")
    model = args.model or env.get("OPENROUTER_MODEL")
    if not api_key or not model:
        raise SystemExit(
            "Missing OPENROUTER_DEBUG_API_KEY (root .env) or a model slug "
            "(--model, or OPENROUTER_MODEL in tools/agent_lab/.env)."
        )

    backup = load_backup(args.backup)
    system_prompt = build_system_prompt(backup)
    if args.show_prompt:
        print("--- system prompt " + "-" * 40)
        print(system_prompt)
        print("-" * 59)

    messages = [{"role": "system", "content": system_prompt}]
    print(f"Chatting against {model}. Ctrl+D to quit.\n")
    while True:
        try:
            user_message = input("you> ").strip()
        except EOFError:
            print()
            break
        if not user_message:
            continue
        messages.append({"role": "user", "content": user_message})
        try:
            reply = chat_completion(api_key, model, messages)
        except requests.HTTPError as e:
            print(f"[error] {e}\n{e.response.text}")
            messages.pop()
            continue
        messages.append({"role": "assistant", "content": reply})
        print(f"arkad> {reply}\n")


if __name__ == "__main__":
    main()
