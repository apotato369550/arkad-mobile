"""Backup loading + the same aggregation logic AppState computes before
calling into OpenRouterService (lib/services/app_state.dart:270-320, 671-728).
Ported for offline prompt tinkering — doesn't need to match Dart byte-for-byte,
just closely enough that the analysis prompts see realistic derived numbers."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path

PERIODS = {
    "week": "sevenDays",
    "month": "oneMonth",
    "quarter": "threeMonths",
    "half_year": "sixMonths",
    "year": "oneYear",
    "ytd": "ytd",
}


@dataclass
class DateRange:
    start: date
    end: date  # inclusive


@dataclass(frozen=True)
class CategoryPattern:
    total: float
    count: int
    min_amount: float
    max_amount: float


def load_backup(path: str | Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _tx_date(tx: dict) -> date:
    return datetime.fromisoformat(tx["date"]).date()


def range_for(period: str, today: date | None = None) -> DateRange:
    """Mirrors AnalysisPeriodX.rangeFor — calendar arithmetic, not fixed-length
    windows, so "month" is a true calendar month back."""
    today = today or date.today()
    key = PERIODS.get(period, period)
    if key == "sevenDays":
        start = today - timedelta(days=6)
    elif key == "oneMonth":
        start = _shift_months(today, -1)
    elif key == "threeMonths":
        start = _shift_months(today, -3)
    elif key == "sixMonths":
        start = _shift_months(today, -6)
    elif key == "oneYear":
        start = today.replace(year=today.year - 1)
    elif key == "ytd":
        start = date(today.year, 1, 1)
    else:
        raise ValueError(f"Unknown period: {period}")
    return DateRange(start=start, end=today)


def preceding_range(range_: DateRange) -> DateRange:
    span_days = (range_.end - range_.start).days + 1
    return DateRange(
        start=range_.start - timedelta(days=span_days),
        end=range_.start - timedelta(days=1),
    )


def totals_for_range(transactions: list[dict], range_: DateRange) -> tuple[float, float]:
    income = expense = 0.0
    for t in transactions:
        d = _tx_date(t)
        if d < range_.start or d > range_.end:
            continue
        if t["type"] == "income":
            income += t["amount"]
        else:
            expense += t["amount"]
    return income, expense


def _category_totals(transactions: list[dict], range_: DateRange, tx_type: str) -> dict[str, float]:
    totals: dict[str, float] = {}
    for t in transactions:
        if t["type"] != tx_type:
            continue
        d = _tx_date(t)
        if d < range_.start or d > range_.end:
            continue
        totals[t["category"]] = totals.get(t["category"], 0.0) + t["amount"]
    return totals


def expense_by_category(transactions: list[dict], range_: DateRange) -> dict[str, float]:
    return _category_totals(transactions, range_, "expense")


def income_by_category(transactions: list[dict], range_: DateRange) -> dict[str, float]:
    return _category_totals(transactions, range_, "income")


def category_patterns(
    transactions: list[dict], range_: DateRange, tx_type: str
) -> dict[str, CategoryPattern]:
    """Summarize observed category activity without inferring recurrence."""
    amounts: dict[str, list[float]] = {}
    for transaction in transactions:
        if transaction["type"] != tx_type:
            continue
        transaction_date = _tx_date(transaction)
        if transaction_date < range_.start or transaction_date > range_.end:
            continue
        amounts.setdefault(transaction["category"], []).append(transaction["amount"])

    return {
        category: CategoryPattern(
            total=sum(values),
            count=len(values),
            min_amount=min(values),
            max_amount=max(values),
        )
        for category, values in amounts.items()
    }


def top_category(expense_cats: dict[str, float], total_expense: float) -> tuple[str, float, float] | None:
    if not expense_cats or total_expense <= 0:
        return None
    name, amount = max(expense_cats.items(), key=lambda kv: kv[1])
    return name, amount, amount / total_expense


def savings_rate(total_income: float, total_expense: float) -> float | None:
    if total_income <= 0:
        return None
    return (total_income - total_expense) / total_income


def typical_income_for_period(profile: dict, range_: DateRange) -> float | None:
    typical_monthly = profile.get("typicalMonthlyIncome")
    if not typical_monthly or typical_monthly <= 0:
        return None
    span_days = (range_.end - range_.start).days + 1
    return typical_monthly / 30 * span_days


def _shift_months(d: date, delta: int) -> date:
    month_index = d.month - 1 + delta
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    # Dart's DateTime(y, m, d) with an out-of-range day rolls into the next
    # month; Python's date() raises instead. Clamp to the shifted month's
    # last valid day — close enough for a tinkering tool.
    import calendar

    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)
