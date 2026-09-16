from __future__ import annotations

import re
import unittest
from datetime import date
from unittest.mock import Mock, patch

from analyze import (
    _completion_text,
    _validate_analysis_response,
    chat_completion,
    compute_context,
    format_money,
    render_cost_cutting,
    render_goal_progress,
    render_overall_or_actionable,
)
from common import DateRange, category_patterns
from prompt_loader import render_prompt


class AnalysisPromptTest(unittest.TestCase):
    def setUp(self) -> None:
        self.range = DateRange(date(2026, 9, 1), date(2026, 9, 5))
        self.backup = {
            "profile": {
                "displayName": "John",
                "currencyCode": "PHP",
                "goalType": "To Save More",
                "longTermGoal": "Build an emergency fund",
                "typicalMonthlyIncome": 6000.0,
                "savingsGoalAmount": 20000.0,
            },
            "transactions": [
                {
                    "type": "income",
                    "category": "Allowance",
                    "amount": 1000.0,
                    "date": "2026-09-01T09:00:00",
                },
                {
                    "type": "expense",
                    "category": "Food",
                    "amount": 100.0,
                    "date": "2026-09-02T09:00:00",
                },
                {
                    "type": "expense",
                    "category": "Food",
                    "amount": 150.0,
                    "date": "2026-09-03T09:00:00",
                },
                {
                    "type": "expense",
                    "category": "Medical",
                    "amount": 500.0,
                    "date": "2026-09-04T09:00:00",
                },
                {
                    "type": "expense",
                    "category": "Transport",
                    "amount": 50.0,
                    "date": "2026-08-30T09:00:00",
                },
            ],
        }

    def test_format_money_uses_profile_currency_and_fallback(self) -> None:
        self.assertEqual(format_money(1234.5, {"currencyCode": "PHP"}), "₱1,234.50")
        self.assertEqual(format_money(-25, {"currencyCode": "PHP"}), "-₱25.00")
        self.assertEqual(format_money(1234.5, {"currencyCode": "CAD"}), "CAD 1,234.50")

    def test_category_patterns_report_counts_and_ranges(self) -> None:
        patterns = category_patterns(self.backup["transactions"], self.range, "expense")
        self.assertEqual(patterns["Food"].total, 250.0)
        self.assertEqual(patterns["Food"].count, 2)
        self.assertEqual(patterns["Food"].min_amount, 100.0)
        self.assertEqual(patterns["Food"].max_amount, 150.0)
        self.assertEqual(patterns["Medical"].count, 1)

    def test_context_contains_current_and_previous_facts(self) -> None:
        context = compute_context(self.backup, self.range)
        self.assertEqual(context["total_income"], 1000.0)
        self.assertEqual(context["total_expense"], 750.0)
        self.assertEqual(context["net"], 250.0)
        self.assertEqual(context["prev_expense"], 50.0)
        self.assertAlmostEqual(context["savings_rate"], 0.25)

    def test_all_analysis_prompts_render_without_placeholders(self) -> None:
        context = compute_context(self.backup, self.range)
        style = render_prompt("response_style", {"transaction_tag": "arkad_transaction"})
        prompts = [
            render_goal_progress(context, self.range, style),
            render_cost_cutting(context, self.range, style),
            render_overall_or_actionable(
                "analysis_overall_assessment", context, self.range, style
            ),
            render_overall_or_actionable(
                "analysis_actionable_steps", context, self.range, style
            ),
        ]
        for prompt in prompts:
            self.assertIsNone(re.search(r"{{[^}]+}}", prompt))
            self.assertIn("₱", prompt)
            self.assertIn("Use only the facts supplied", prompt)

        self.assertIn("Expense patterns observed this period", prompts[0])
        self.assertIn("across 2 transactions", prompts[0])
        self.assertIn("### Direction", prompts[0])
        self.assertIn("**Pattern:**", prompts[1])
        self.assertIn("### Result", prompts[2])
        self.assertIn("exactly three prioritized actions", prompts[3])
        self.assertIn('Speak directly to the person as "you,"', prompts[0])

    def test_empty_activity_renders_explicitly(self) -> None:
        context = compute_context(
            {"profile": {"currencyCode": "USD"}, "transactions": []}, self.range
        )
        style = render_prompt(
            "response_style", {"transaction_tag": "arkad_transaction"}
        )
        goal_prompt = render_goal_progress(context, self.range, style)
        cost_prompt = render_cost_cutting(context, self.range, style)
        overall_prompt = render_overall_or_actionable(
            "analysis_overall_assessment", context, self.range, style
        )
        self.assertIn("(no expenses in this period)", goal_prompt)
        self.assertIn("(no expenses in this period)", cost_prompt)
        self.assertIn("(no income in this period)", overall_prompt)

    def test_completion_text_rejects_empty_content(self) -> None:
        with self.assertRaisesRegex(ValueError, "empty response"):
            _completion_text({"choices": [{"message": {"content": None}}]})

    @patch("analyze.time.sleep")
    @patch("analyze.signal.setitimer")
    @patch("analyze.signal.signal", return_value=object())
    @patch("analyze.requests.post")
    def test_chat_completion_retries_empty_success(
        self, post: Mock, _signal: Mock, _setitimer: Mock, sleep: Mock
    ) -> None:
        empty = Mock(status_code=200)
        empty.json.return_value = {"choices": [{"message": {"content": None}}]}
        complete = Mock(status_code=200)
        complete.json.return_value = {
            "choices": [{"message": {"content": " Grounded result "}}]
        }
        post.side_effect = [empty, complete]

        result = chat_completion("key", "openrouter/free", "prompt")

        self.assertEqual(result, "Grounded result")
        self.assertEqual(post.call_count, 2)
        sleep.assert_called_once_with(1)
        messages = post.call_args.kwargs["json"]["messages"]
        self.assertEqual([message["role"] for message in messages], ["system", "user"])
        self.assertIn("Return only the final answer", messages[1]["content"])

    def test_response_validator_rejects_meta_commentary_and_missing_schema(self) -> None:
        with self.assertRaisesRegex(ValueError, "meta-commentary"):
            _validate_analysis_response(
                "Actionable steps", "Here's a thinking process:\n1. Inspect data"
            )
        with self.assertRaisesRegex(ValueError, "required headings"):
            _validate_analysis_response(
                "Goal progress", "### Direction\nCloser.\n\n### Evidence\n- Fact"
            )

    def test_response_validator_accepts_compact_schemas(self) -> None:
        _validate_analysis_response(
            "Goal progress",
            "### Direction\nCloser.\n\n### Evidence\n- Fact.\n\n### Unknown\n- None.",
        )
        _validate_analysis_response(
            "Actionable steps",
            "\n".join(
                f"{number}. **Evidence:** Fact. **Action:** Act. **Target:** Check."
                for number in range(1, 4)
            ),
        )

    def test_response_validator_rejects_unsupported_numeric_claim(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported numeric claims"):
            _validate_analysis_response(
                "Goal progress",
                "### Direction\nCloser.\n\n### Evidence\n- Saved ₱150.\n\n"
                "### Unknown\n- None.",
                "Net: ₱100.00",
            )

    def test_response_validator_rejects_unsupported_activity_inference(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported inference"):
            _validate_analysis_response(
                "Cost cutting",
                "1. **Pattern:** Gym across 3 sessions. **Why it matters:** Unknown. "
                "**Trial:** Review it.",
            )


if __name__ == "__main__":
    unittest.main()
