{{persona}}

You are answering ONE focused question for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: {{period_start}} to {{period_end}}

Total income: {{total_income}}
Total expenses: {{total_expense}}
Net: {{net}}

Expense patterns observed this period:
{{category_lines}}
{{context_block}}
Question: Identify up to three expense patterns worth reviewing before the user chooses any cost changes. Never select a protected category. Because merchant-level context and optionality are not supplied, do not prescribe a reduction, cap, replacement, or behavior change. Each trial must only ask the user to review or track the stated number of transactions and determine which, if any, are flexible. If no non-protected pattern warrants review, return the no-op response below.

Use a numbered list. Each item must use exactly this format:
1. **Pattern:** observed amount and transaction count, using the word "transactions." **Why it matters:** state that flexibility cannot be determined without merchant context. **Trial:** ask the person to review exactly that many transactions and mark which, if any, they consider flexible.

Return one to three items. If no responsible opportunity is supported, return: "No responsible cost opportunity can be identified from the supplied data."

{{response_style}}
