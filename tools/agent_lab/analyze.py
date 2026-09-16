#!/usr/bin/env python3
"""Run the four analysis prompts the app actually wires up (AppState.requestAnalysis,
lib/services/app_state.dart:671) against a real backup, and write a combined
text + PDF report. analysis_finances.md is skipped — it has no caller in the app.

Continuity ("previous check-in") is intentionally NOT ported: it depends on
previously-saved analyses, which aren't in a raw backup. Fine for tuning wording.

Usage:
    python analyze.py --backup backups/you@example.com.json --period month --out output/
    python analyze.py --backup backups/you@example.com.json --period week --as-of 2026-09-05
"""

from __future__ import annotations

import argparse
from datetime import date
from decimal import Decimal
from pathlib import Path
import re
import signal
import time

import requests
from dotenv import dotenv_values
from fpdf import FPDF

from common import (
    CategoryPattern,
    DateRange,
    category_patterns,
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
RETRY_DELAYS = (1, 2)
REQUEST_DEADLINE_SECONDS = 90
CURRENCY_SYMBOLS = {
    "EUR": "€",
    "GBP": "£",
    "JPY": "¥",
    "PHP": "₱",
    "USD": "$",
}


def _load_env() -> dict[str, str]:
    env = dict(dotenv_values(REPO_ROOT / ".env"))
    env.update(dotenv_values(LAB_DIR / ".env"))
    return env


def format_money(amount: float, profile: dict) -> str:
    currency_code = str(profile.get("currencyCode") or "USD").upper()
    prefix = CURRENCY_SYMBOLS.get(currency_code, f"{currency_code} ")
    sign = "-" if amount < 0 else ""
    return f"{sign}{prefix}{abs(amount):,.2f}"


def _category_lines(patterns: dict[str, CategoryPattern], profile: dict) -> str:
    lines = []
    for category, pattern in sorted(
        patterns.items(), key=lambda item: item[1].total, reverse=True
    ):
        transaction_word = "transaction" if pattern.count == 1 else "transactions"
        amount_range = ""
        if pattern.count > 1:
            amount_range = (
                f"; observed amounts {format_money(pattern.min_amount, profile)}"
                f"–{format_money(pattern.max_amount, profile)}"
            )
        lines.append(
            f"- {category}: {format_money(pattern.total, profile)} across "
            f"{pattern.count} {transaction_word}{amount_range}"
        )
    return "\n".join(lines)


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
        parts.append(
            f"Typical Monthly Income (do not compare directly with a shorter period): "
            f"{format_money(profile['typicalMonthlyIncome'], profile)}"
        )
    if profile.get("savingsGoalAmount"):
        parts.append(
            f"Savings Goal: {format_money(profile['savingsGoalAmount'], profile)}"
        )
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
    expense_patterns = category_patterns(transactions, range_, "expense")
    income_patterns = category_patterns(transactions, range_, "income")
    prev_income, prev_expense = totals_for_range(transactions, preceding_range(range_))
    rate = savings_rate(total_income, total_expense)
    previous_rate = savings_rate(prev_income, prev_expense)
    top = top_category(expense_cats, total_expense)
    typical_income = typical_income_for_period(profile, range_)
    return {
        "profile": profile,
        "total_income": total_income,
        "total_expense": total_expense,
        "net": total_income - total_expense,
        "expense_cats": expense_cats,
        "income_cats": income_cats,
        "expense_patterns": expense_patterns,
        "income_patterns": income_patterns,
        "prev_income": prev_income,
        "prev_expense": prev_expense,
        "prev_net": prev_income - prev_expense,
        "savings_rate": rate,
        "previous_savings_rate": previous_rate,
        "top": top,
        "typical_income": typical_income,
    }


def render_goal_progress(ctx: dict, range_: DateRange, response_style: str) -> str:
    profile = ctx["profile"]
    derived = []
    if ctx["savings_rate"] is not None:
        derived.append(f"Savings rate this period: {ctx['savings_rate'] * 100:.1f}%")
    if ctx["typical_income"] is not None:
        derived.append(
            "Typical income scaled to this period's length: "
            f"{format_money(ctx['typical_income'], profile)} "
            f"(actual: {format_money(ctx['total_income'], profile)})"
        )
    if ctx["previous_savings_rate"] is not None:
        derived.append(
            f"Previous period's savings rate: {ctx['previous_savings_rate'] * 100:.1f}%"
        )
    derived_block = "\n".join(derived) + ("\n" if derived else "")
    profile_block = _profile_block(profile, leading_newline=True) if profile else ""
    context_block = derived_block + profile_block
    expense_lines = _category_lines(ctx["expense_patterns"], profile)
    return render_prompt(
        "analysis_goal_progress",
        {
            "persona": render_prompt("analysis_persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "total_income": format_money(ctx["total_income"], profile),
            "total_expense": format_money(ctx["total_expense"], profile),
            "net": format_money(ctx["net"], profile),
            "expense_lines": expense_lines or "(no expenses in this period)",
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def render_cost_cutting(ctx: dict, range_: DateRange, response_style: str) -> str:
    profile = ctx["profile"]
    derived = []
    if ctx["top"]:
        name, amount, pct = ctx["top"]
        derived.append(
            f"Largest category: {name} at {format_money(amount, profile)} "
            f"({pct * 100:.0f}% of total expenses)"
        )
    if ctx["prev_income"] or ctx["prev_expense"]:
        derived.append(
            "Previous period: "
            f"income {format_money(ctx['prev_income'], profile)}, "
            f"expenses {format_money(ctx['prev_expense'], profile)}, "
            f"net {format_money(ctx['prev_net'], profile)}"
        )
    derived_block = ("\n" + "\n".join(derived) + "\n") if derived else ""
    profile_block = _profile_block(profile, leading_newline=True) if profile else ""
    context_block = derived_block + profile_block
    category_lines = (
        _category_lines(ctx["expense_patterns"], profile)
        or "(no expenses in this period)"
    )
    return render_prompt(
        "analysis_cost_cutting",
        {
            "persona": render_prompt("analysis_persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "total_income": format_money(ctx["total_income"], profile),
            "total_expense": format_money(ctx["total_expense"], profile),
            "net": format_money(ctx["net"], profile),
            "category_lines": category_lines,
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def render_overall_or_actionable(template: str, question_variant_ctx: dict, range_: DateRange, response_style: str) -> str:
    ctx = question_variant_ctx
    profile = ctx["profile"]
    derived = []
    if ctx["savings_rate"] is not None:
        derived.append(f"Savings rate this period: {ctx['savings_rate'] * 100:.1f}%")
    if template == "analysis_overall_assessment" and (ctx["prev_income"] or ctx["prev_expense"]):
        derived.append("Previous period for comparison:")
        if ctx["prev_income"]:
            derived.append(f"- Income: {format_money(ctx['prev_income'], profile)}")
        if ctx["prev_expense"]:
            derived.append(f"- Expenses: {format_money(ctx['prev_expense'], profile)}")
    if ctx["top"]:
        name, amount, pct = ctx["top"]
        derived.append(
            f"Largest expense category: {name} at {format_money(amount, profile)} "
            f"({pct * 100:.0f}% of total expenses)"
        )
    if ctx["typical_income"] is not None:
        derived.append(
            "Typical income scaled to this period's length: "
            f"{format_money(ctx['typical_income'], profile)} "
            f"(actual: {format_money(ctx['total_income'], profile)})"
        )
    if ctx["net"] < 0:
        derived.append(
            f"Amount needed to break even: {format_money(abs(ctx['net']), profile)}"
        )
    else:
        derived.append(f"Surplus after expenses: {format_money(ctx['net'], profile)}")
    derived_block = ("\n" + "\n".join(derived) + "\n") if derived else ""
    profile_block = _profile_block(profile, leading_newline=True) if profile else ""
    context_block = derived_block + profile_block
    income_lines = _category_lines(ctx["income_patterns"], profile) or "(no income in this period)"
    expense_lines = _category_lines(ctx["expense_patterns"], profile) or "(no expenses in this period)"
    return render_prompt(
        template,
        {
            "persona": render_prompt("analysis_persona", {}),
            "period_start": range_.start.isoformat(),
            "period_end": range_.end.isoformat(),
            "total_income": format_money(ctx["total_income"], profile),
            "total_expense": format_money(ctx["total_expense"], profile),
            "net": format_money(ctx["net"], profile),
            "income_lines": income_lines,
            "expense_lines": expense_lines,
            "context_block": context_block,
            "response_style": response_style,
        },
    )


def _completion_text(decoded: dict) -> str:
    choices = decoded.get("choices")
    if not isinstance(choices, list) or not choices:
        raise ValueError("OpenRouter returned an empty response.")
    choice = choices[0]
    message = choice.get("message") if isinstance(choice, dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, str) or not content.strip():
        raise ValueError("OpenRouter returned an empty response.")
    return content.strip()


def _numeric_claims(text: str) -> set[str]:
    tokens = re.findall(
        r"-?(?:[₱$€£¥]|[A-Z]{3}\s)\d[\d,]*(?:\.\d+)?|-?\d+(?:\.\d+)?%",
        text,
    )
    normalized = set()
    for token in tokens:
        number_start = next(i for i, character in enumerate(token) if character.isdigit())
        prefix = token[:number_start]
        suffix = "%" if token.endswith("%") else ""
        number = token[number_start:].removesuffix("%").replace(",", "")
        normalized.add(f"{prefix}{format(Decimal(number).normalize(), 'f')}{suffix}")
    return normalized


def _validate_analysis_response(
    label: str, text: str, source_prompt: str | None = None
) -> None:
    lowered = text.lower()
    forbidden_artifacts = (
        "thinking process",
        "analyze the user's request",
        "deconstruct the data",
        "user safety:",
    )
    if any(artifact in lowered for artifact in forbidden_artifacts):
        raise ValueError(f"{label} response exposed model meta-commentary.")
    forbidden_inferences = (
        "discretionary",
        "essential cost",
        "optional",
        " sessions",
        " trips",
        " rides",
        " meals",
        " visits",
    )
    if any(inference in lowered for inference in forbidden_inferences):
        raise ValueError(f"{label} response introduced an unsupported inference.")
    if source_prompt is not None:
        unsupported_claims = _numeric_claims(text) - _numeric_claims(source_prompt)
        if unsupported_claims:
            raise ValueError(
                f"{label} response introduced unsupported numeric claims: "
                f"{sorted(unsupported_claims)}"
            )

    required_headings = {
        "Goal progress": ("### Direction", "### Evidence", "### Unknown"),
        "Overall assessment": (
            "### Result",
            "### Driver",
            "### Outlook",
            "### Priority",
        ),
    }
    headings = required_headings.get(label, ())
    if headings and (
        not text.startswith(headings[0]) or any(h not in text for h in headings)
    ):
        raise ValueError(f"{label} response did not follow the required headings.")

    if label == "Cost cutting":
        valid_empty = text == (
            "No responsible cost opportunity can be identified from the supplied data."
        )
        items = re.findall(r"(?m)^\d+\. \*\*Pattern:\*\*", text)
        if not valid_empty and (
            not text.startswith("1. **Pattern:**") or not 1 <= len(items) <= 3
        ):
            raise ValueError("Cost cutting response did not follow the required list format.")

    if label == "Actionable steps":
        items = re.findall(r"(?m)^\d+\. \*\*Evidence:\*\*", text)
        if not text.startswith("1. **Evidence:**") or len(items) != 3:
            raise ValueError(
                "Actionable steps response did not contain exactly three actions."
            )


def _deadline_exceeded(_signum, _frame) -> None:
    raise TimeoutError(
        f"OpenRouter request exceeded {REQUEST_DEADLINE_SECONDS} seconds."
    )


def chat_completion(
    api_key: str,
    model: str,
    system_prompt: str,
    validator=None,
) -> str:
    for attempt in range(len(RETRY_DELAYS) + 1):
        previous_handler = signal.signal(signal.SIGALRM, _deadline_exceeded)
        signal.setitimer(signal.ITIMER_REAL, REQUEST_DEADLINE_SECONDS)
        try:
            resp = requests.post(
                ENDPOINT,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    "X-Title": "Arkad Agent Lab",
                },
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {
                            "role": "user",
                            "content": (
                                "Produce the requested analysis now. Return only the "
                                "final answer in the required format."
                            ),
                        },
                    ],
                    "reasoning": {"exclude": True},
                },
                timeout=60,
            )
            if resp.status_code != 200:
                resp.raise_for_status()
            text = _completion_text(resp.json())
            if validator is not None:
                validator(text)
            return text
        except (requests.RequestException, TimeoutError, ValueError) as error:
            status = getattr(getattr(error, "response", None), "status_code", None)
            retryable = (
                isinstance(error, (TimeoutError, ValueError))
                or status == 429
                or (status is not None and status >= 500)
                or (
                    isinstance(error, requests.RequestException)
                    and status is None
                )
            )
            if attempt >= len(RETRY_DELAYS) or not retryable:
                raise
            time.sleep(RETRY_DELAYS[attempt])
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_handler)

    raise RuntimeError("OpenRouter retry loop exited unexpectedly.")


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
    parser.add_argument(
        "--as-of",
        default=None,
        help="End date in YYYY-MM-DD format (default: today)",
    )
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

    try:
        as_of = date.fromisoformat(args.as_of) if args.as_of else None
    except ValueError:
        parser.error("--as-of must use YYYY-MM-DD format")

    backup = load_backup(args.backup)
    range_ = range_for(args.period, today=as_of)
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
            text = chat_completion(
                api_key,
                model,
                prompt,
                validator=lambda response, section=label, source=prompt: _validate_analysis_response(
                    section, response, source
                ),
            )
        except requests.HTTPError as e:
            text = f"[error] {e}\n{e.response.text}"
        results.append((label, text))

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    date_suffix = f"_{range_.end.isoformat()}" if args.as_of else ""
    label = f"{Path(args.backup).stem}_{args.period}{date_suffix}"
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
