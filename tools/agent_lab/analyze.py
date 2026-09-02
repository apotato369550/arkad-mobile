#!/usr/bin/env python3
"""Run the four analysis prompts the app actually wires up (AppState.requestAnalysis,
lib/services/app_state.dart:671) against a real backup, and write a combined
text + PDF report. analysis_finances.md is skipped — it has no caller in the app.

Continuity ("previous check-in") is intentionally NOT ported: it depends on
previously-saved analyses, which aren't in a raw backup. Fine for tuning wording.

Usage:
    python analyze.py --backup backups/you@example.com.json --period month --out output/
"""

from __future__ import annotations

import argparse
from pathlib import Path

import requests
from dotenv import dotenv_values
from fpdf import FPDF

from common import (
    DateRange,
    expense_by_category,
    income_by_category,
    load_backup,
    preceding_range,
    range_for,
    savings_rate,
    top_category,
    totals_for_range,
    typical_income_for_period,
)
from prompt_loader import render_prompt

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
LAB_DIR = Path(__file__).resolve().parent
ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
TRANSACTION_TAG = "arkad_transaction"


def _load_env() -> dict[str, str]:
    env = dict(dotenv_values(REPO_ROOT / ".env"))
    env.update(dotenv_values(LAB_DIR / ".env"))
    return env


def _lines(cats: dict[str, float]) -> str:
    return "\n".join(f"- {k}: ${v:,.2f}" for k, v in cats.items())


def _profile_block(profile: dict, leading_newline: bool) -> str:
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
    body = "\n".join(f"- {p}" for p in parts) + "\n"
    return f"\nAbout the user:\n{body}" if leading_newline else f"About the user:\n{body}"


def compute_context(backup: dict, range_: DateRange) -> dict:
    transactions = backup.get("transactions", [])
    profile = backup.get("profile", {})
    total_income, total_expense = totals_for_range(transactions, range_)
    expense_cats = expense_by_category(transactions, range_)
    income_cats = income_by_category(transactions, range_)
    prev_income, prev_expense = totals_for_range(transactions, preceding_range(range_))
    rate = savings_rate(total_income, total_expense)
    top = top_category(expense_cats, total_expense)
    typical_income = typical_income_for_period(profile, range_)
    return {
        "profile": profile,
        "total_income": total_income,
        "total_expense": total_expense,
        "net": total_income - total_expense,
        "expense_cats": expense_cats,
        "income_cats": income_cats,
        "prev_income": prev_income,
        "prev_expense": prev_expense,
        "savings_rate": rate,
        "top": top,
        "typical_income": typical_income,
    }


def render_goal_progress(ctx: dict, range_: DateRange, response_style: str) -> str:
    derived = []
    if ctx["savings_rate"] is not None:
        derived.append(f"Savings rate this period: {ctx['savings_rate'] * 100:.1f}%")
    if ctx["typical_income"] is not None:
        derived.append(
            f"Typical income scaled to this period's length: ${ctx['typical_income']:,.2f} "
            f"(actual: ${ctx['total_income']:,.2f})"
        )
    derived_block = "\n".join(derived) + ("\n" if derived else "")
    profile_block = _profile_block(ctx["profile"], leading_newline=True) if ctx["profile"] else ""
    context_block = derived_block + profile_block
    return render_prompt(
        "analysis_goal_progress",
        {
            "persona": render_prompt("persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "total_income": f"${ctx['total_income']:,.2f}",
            "total_expense": f"${ctx['total_expense']:,.2f}",
            "net": f"${ctx['net']:,.2f}",
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def render_cost_cutting(ctx: dict, range_: DateRange, response_style: str) -> str:
    derived = []
    if ctx["top"]:
        name, amount, pct = ctx["top"]
        derived.append(f"Largest category: {name} at ${amount:,.2f} ({pct * 100:.0f}% of total expenses)")
    if ctx["prev_expense"]:
        derived.append(f"Previous period's total expenses: ${ctx['prev_expense']:,.2f}")
    derived_block = ("\n" + "\n".join(derived) + "\n") if derived else ""
    profile_block = _profile_block(ctx["profile"], leading_newline=True) if ctx["profile"] else ""
    context_block = derived_block + profile_block
    category_lines = _lines(ctx["expense_cats"]) or "(no expenses in this period)"
    return render_prompt(
        "analysis_cost_cutting",
        {
            "persona": render_prompt("persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "category_lines": category_lines,
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def render_overall_or_actionable(template: str, question_variant_ctx: dict, range_: DateRange, response_style: str) -> str:
    ctx = question_variant_ctx
    derived = []
    if ctx["savings_rate"] is not None:
        derived.append(f"Savings rate this period: {ctx['savings_rate'] * 100:.1f}%")
    if template == "analysis_overall_assessment" and (ctx["prev_income"] or ctx["prev_expense"]):
        derived.append("Previous period for comparison:")
        if ctx["prev_income"]:
            derived.append(f"- Income: ${ctx['prev_income']:,.2f}")
        if ctx["prev_expense"]:
            derived.append(f"- Expenses: ${ctx['prev_expense']:,.2f}")
    if ctx["top"]:
        name, amount, pct = ctx["top"]
        derived.append(f"Largest expense category: {name} at ${amount:,.2f} ({pct * 100:.0f}% of total expenses)")
    if template == "analysis_overall_assessment" and ctx["typical_income"] is not None:
        derived.append(
            f"Typical income scaled to this period's length: ${ctx['typical_income']:,.2f} "
            f"(actual: ${ctx['total_income']:,.2f})"
        )
    derived_block = ("\n" + "\n".join(derived) + "\n") if derived else ""
    profile_block = _profile_block(ctx["profile"], leading_newline=True) if ctx["profile"] else ""
    context_block = derived_block + profile_block
    income_lines = _lines(ctx["income_cats"]) or "(no income in this period)"
    expense_lines = _lines(ctx["expense_cats"]) or "(no expenses in this period)"
    return render_prompt(
        template,
        {
            "persona": render_prompt("persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "total_income": f"${ctx['total_income']:,.2f}",
            "total_expense": f"${ctx['total_expense']:,.2f}",
            "net": f"${ctx['net']:,.2f}",
            "income_lines": income_lines,
            "expense_lines": expense_lines,
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def chat_completion(api_key: str, model: str, system_prompt: str) -> str:
    resp = requests.post(
        ENDPOINT,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json={"model": model, "messages": [{"role": "system", "content": system_prompt}]},
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"].strip()


def _pdf_safe(text: str) -> str:
    # Core Helvetica font is latin-1 only — good enough for a tinkering
    # report; swap for a Unicode TTF font if this ever needs to be pretty.
    return text.encode("latin-1", "replace").decode("latin-1")


def write_pdf(path: Path, title: str, sections: list[tuple[str, str]]) -> None:
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.multi_cell(0, 10, _pdf_safe(title))
    pdf.ln(4)
    for heading, body in sections:
        pdf.set_font("Helvetica", "B", 13)
        pdf.multi_cell(0, 8, _pdf_safe(heading), new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Helvetica", "", 11)
        pdf.multi_cell(0, 6, _pdf_safe(body), new_x="LMARGIN", new_y="NEXT")
        pdf.ln(4)
    pdf.output(str(path))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", required=True)
    parser.add_argument("--period", default="month", choices=["week", "month", "quarter", "half_year", "year", "ytd"])
    parser.add_argument("--model", default=None)
    parser.add_argument("--out", default="output")
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
    range_ = range_for(args.period)
    ctx = compute_context(backup, range_)
    response_style = render_prompt("response_style", {"transaction_tag": TRANSACTION_TAG})

    sections = [
        ("Goal progress", render_goal_progress(ctx, range_, response_style)),
        ("Cost cutting", render_cost_cutting(ctx, range_, response_style)),
        ("Overall assessment", render_overall_or_actionable("analysis_overall_assessment", ctx, range_, response_style)),
        ("Actionable steps", render_overall_or_actionable("analysis_actionable_steps", ctx, range_, response_style)),
    ]

    results = []
    for label, prompt in sections:
        print(f"Calling OpenRouter for: {label}...")
        try:
            text = chat_completion(api_key, model, prompt)
        except requests.HTTPError as e:
            text = f"[error] {e}\n{e.response.text}"
        results.append((label, text))

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    label = f"{Path(args.backup).stem}_{args.period}"
    title = f"Arkad analysis — {label} ({range_.start.isoformat()} to {range_.end.isoformat()})"

    md_path = out_dir / f"{label}.md"
    md_path.write_text(
        f"# {title}\n\n" + "\n\n".join(f"## {h}\n\n{b}" for h, b in results),
        encoding="utf-8",
    )
    pdf_path = out_dir / f"{label}.pdf"
    write_pdf(pdf_path, title, results)

    print(f"Wrote {md_path}")
    print(f"Wrote {pdf_path}")


if __name__ == "__main__":
    main()
