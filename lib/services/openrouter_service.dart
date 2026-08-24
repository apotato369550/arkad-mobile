import 'dart:convert';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/countries.dart';
import '../models/profile.dart';
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'formatters.dart';

enum OpenRouterErrorKind { invalidKey, rateLimited, network, server, unknown }

class OpenRouterException implements Exception {
  OpenRouterException(this.message, {this.kind = OpenRouterErrorKind.unknown});
  final String message;
  final OpenRouterErrorKind kind;
  @override
  String toString() => message;
}

/// A parsed reply from the agent: the text to show in the chat bubble, plus
/// zero or more structured transactions the agent extracted from the user's
/// message (see IDEA.md § Core idea — conversational ledger entry). These are
/// drafts only — nothing is added to the ledger until the user approves them
/// in the review modal (see ProposedTransactionsSheet).
class AgentReply {
  AgentReply({
    required this.text,
    this.transactions = const [],
    this.referencedTransactionIds = const [],
  });
  final String text;
  final List<LedgerTransaction> transactions;
  final List<int> referencedTransactionIds;
}

/// Direct browser/app → OpenRouter calls, BYOK. No proxy server.
/// See IDEA.md: "All calls are made directly from the browser to OpenRouter,
/// no proxy server" — mirrored here as direct client calls from the app.
class OpenRouterService {
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _transactionTag = 'arkad_transaction';

  /// Shared Arkad persona voice, reused by the chat system prompt and the
  /// one-shot analysis prompt.
  static const _personaIntro =
      "You are Arkad, named for the legendary richest man in Babylon — a patient, warm financial mentor, not a lecturing chatbot. You believe: a part of all one earns is theirs to keep (encourage saving before spending); money must be put to work, not left idle; guard savings from loss (favor sound, proven habits over speculation); a person's ability to earn is their greatest asset (encourage growth, not just cutting); plan for the future. Ground every answer in the user's actual data — their real transactions, categories, and goals — never generic platitudes when specifics are available. Be concise and actionable.";

  Future<AgentReply> sendMessage({
    required String apiKey,
    required String modelSlug,
    required String userMessage,
    required List<ChatMessage> history,
    required List<LedgerTransaction> ledger,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
    required Profile profile,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final messages = [
      {
        'role': 'system',
        'content': _buildSystemPrompt(
          ledger: ledger,
          incomeCategories: incomeCategories,
          expenseCategories: expenseCategories,
          profile: profile,
          userMessage: userMessage,
        ),
      },
      for (final m in history)
        {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': m.content},
    ];

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: messages,
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    final content = (choices.first['message']?['content'] as String?)?.trim() ?? '';
    return _parseReply(content);
  }

  /// One-shot, non-chat analysis of a time-ranged view of the user's finances.
  /// This is NOT a chat turn: no history, no transaction extraction, and the
  /// response is returned as plain markdown (no arkad_transaction/arkad_refs
  /// block parsing).
  Future<String> analyzeFinances({
    required String apiKey,
    required String modelSlug,
    required Profile profile,
    required DateTimeRange range,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> expenseByCategory,
    double? previousPeriodIncome,
    double? previousPeriodExpense,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final messages = [
      {
        'role': 'system',
        'content': _buildAnalysisPrompt(
          profile: profile,
          range: range,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          expenseByCategory: expenseByCategory,
          previousPeriodIncome: previousPeriodIncome,
          previousPeriodExpense: previousPeriodExpense,
        ),
      },
    ];

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: messages,
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    return (choices.first['message']?['content'] as String?)?.trim() ?? '';
  }

  /// One-shot question: how purposeful the user's spending was this period —
  /// whether it served their stated goals and values or drifted into
  /// impulsive/low-value spending. Same non-chat shape as [analyzeFinances]
  /// — no history, no transaction extraction.
  Future<String> analyzeGoalProgress({
    required String apiKey,
    required String modelSlug,
    required Profile profile,
    required DateTimeRange range,
    required double totalIncome,
    required double totalExpense,
    double? savingsRate,
    double? typicalMonthlyIncomeForPeriod,
    SavedAnalysis? previousAnalysis,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final net = totalIncome - totalExpense;
    final profileLines = _buildProfileSection(profile);
    final continuityLines = _buildContinuitySection(previousAnalysis);

    final derivedLines = StringBuffer();
    if (savingsRate != null) {
      derivedLines.writeln('Savings rate this period: ${(savingsRate * 100).toStringAsFixed(1)}%');
    }
    if (typicalMonthlyIncomeForPeriod != null) {
      derivedLines.writeln(
        'Typical income scaled to this period\'s length: ${formatCurrency(typicalMonthlyIncomeForPeriod)} '
        '(actual: ${formatCurrency(totalIncome)})',
      );
    }

    final prompt = '''
$_personaIntro

You are answering ONE focused question for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: ${formatDate(range.start)} to ${formatDate(range.end)}

Total income: ${formatCurrency(totalIncome)}
Total expenses: ${formatCurrency(totalExpense)}
Net: ${formatCurrency(net)}
${derivedLines.isEmpty ? '' : '$derivedLines'}${profileLines.isEmpty ? '' : '\n$profileLines'}${continuityLines.isEmpty ? '' : '\n$continuityLines'}
Question: How purposeful was the user's spending this period — did it clearly serve their stated goals and values, or did a meaningful share drift into impulsive or low-value spending? Point to specific categories or patterns that show intentional vs. unintentional spending. If no goal or savings target is stated, still assess purposefulness using savings rate and category concentration, and suggest they set a goal in their profile.

$_responseStyle
''';

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: [
        {'role': 'system', 'content': prompt},
      ],
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    return (choices.first['message']?['content'] as String?)?.trim() ?? '';
  }

  /// One-shot question: where this period's spending could have been saved
  /// better, ranked by opportunity. Same non-chat shape as [analyzeFinances].
  Future<String> analyzeCostCutting({
    required String apiKey,
    required String modelSlug,
    required Profile profile,
    required DateTimeRange range,
    required Map<String, double> expenseByCategory,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    double? previousPeriodExpense,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final categoryLines = expenseByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');
    final profileLines = _buildProfileSection(profile);

    final derivedLines = StringBuffer();
    if (topCategoryName != null && topCategoryAmount != null && topCategoryPercent != null) {
      derivedLines.writeln(
        'Largest category: $topCategoryName at ${formatCurrency(topCategoryAmount)} '
        '(${(topCategoryPercent * 100).toStringAsFixed(0)}% of total expenses)',
      );
    }
    if (previousPeriodExpense != null) {
      derivedLines.writeln('Previous period\'s total expenses: ${formatCurrency(previousPeriodExpense)}');
    }

    final prompt = '''
$_personaIntro

You are answering ONE focused question for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: ${formatDate(range.start)} to ${formatDate(range.end)}

Expense breakdown by category:
${categoryLines.isEmpty ? '(no expenses in this period)' : categoryLines}
${derivedLines.isEmpty ? '' : '\n$derivedLines'}${profileLines.isEmpty ? '' : '\n$profileLines'}
Question: Looking at this period's spending, where could money have been saved better? Rank the top 1-3 opportunities and explain concretely what "saved better" would have looked like for each. If the user has fixed monthly obligations on file, don't suggest cutting those — focus on discretionary categories.

$_responseStyle
''';

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: [
        {'role': 'system', 'content': prompt},
      ],
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    return (choices.first['message']?['content'] as String?)?.trim() ?? '';
  }

  /// One-shot question: a short overall assessment of the period's
  /// financial health. Same non-chat shape as [analyzeFinances].
  Future<String> analyzeOverallAssessment({
    required String apiKey,
    required String modelSlug,
    required Profile profile,
    required DateTimeRange range,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> expenseByCategory,
    required Map<String, double> incomeByCategory,
    double? savingsRate,
    double? previousPeriodIncome,
    double? previousPeriodExpense,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    double? typicalMonthlyIncomeForPeriod,
    SavedAnalysis? previousAnalysis,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final net = totalIncome - totalExpense;
    final expenseLines = expenseByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');
    final incomeLines = incomeByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');
    final profileLines = _buildProfileSection(profile);
    final continuityLines = _buildContinuitySection(previousAnalysis);

    final derivedLines = StringBuffer();
    if (savingsRate != null) {
      derivedLines.writeln('Savings rate this period: ${(savingsRate * 100).toStringAsFixed(1)}%');
    }
    if (previousPeriodIncome != null || previousPeriodExpense != null) {
      derivedLines.writeln('Previous period for comparison:');
      if (previousPeriodIncome != null) {
        derivedLines.writeln('- Income: ${formatCurrency(previousPeriodIncome)}');
      }
      if (previousPeriodExpense != null) {
        derivedLines.writeln('- Expenses: ${formatCurrency(previousPeriodExpense)}');
      }
    }
    if (topCategoryName != null && topCategoryAmount != null && topCategoryPercent != null) {
      derivedLines.writeln(
        'Largest expense category: $topCategoryName at ${formatCurrency(topCategoryAmount)} '
        '(${(topCategoryPercent * 100).toStringAsFixed(0)}% of total expenses)',
      );
    }
    if (typicalMonthlyIncomeForPeriod != null) {
      derivedLines.writeln(
        'Typical income scaled to this period\'s length: ${formatCurrency(typicalMonthlyIncomeForPeriod)} '
        '(actual: ${formatCurrency(totalIncome)})',
      );
    }

    final prompt = '''
$_personaIntro

You are answering ONE focused question for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: ${formatDate(range.start)} to ${formatDate(range.end)}

Total income: ${formatCurrency(totalIncome)}
Total expenses: ${formatCurrency(totalExpense)}
Net: ${formatCurrency(net)}

Income breakdown by category:
${incomeLines.isEmpty ? '(no income in this period)' : incomeLines}

Expense breakdown by category:
${expenseLines.isEmpty ? '(no expenses in this period)' : expenseLines}
${derivedLines.isEmpty ? '' : '\n$derivedLines'}${profileLines.isEmpty ? '' : '\n$profileLines'}${continuityLines.isEmpty ? '' : '\n$continuityLines'}
Question: Give a short overall assessment of this period's financial health.

$_responseStyle
''';

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: [
        {'role': 'system', 'content': prompt},
      ],
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    return (choices.first['message']?['content'] as String?)?.trim() ?? '';
  }

  /// One-shot question: 3-5 concrete, specific next actions for the upcoming
  /// period, tied to real numbers where possible. Same non-chat shape as
  /// [analyzeFinances] — dedicated slot rather than folding action items
  /// into the other three questions (see Part D of the analysis-quality
  /// improvement plan).
  Future<String> analyzeActionableSteps({
    required String apiKey,
    required String modelSlug,
    required Profile profile,
    required DateTimeRange range,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> expenseByCategory,
    required Map<String, double> incomeByCategory,
    double? savingsRate,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    SavedAnalysis? previousAnalysis,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw OpenRouterException('No OpenRouter API key configured.');
    }

    final net = totalIncome - totalExpense;
    final expenseLines = expenseByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');
    final incomeLines = incomeByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');
    final profileLines = _buildProfileSection(profile);
    final continuityLines = _buildContinuitySection(previousAnalysis);

    final derivedLines = StringBuffer();
    if (savingsRate != null) {
      derivedLines.writeln('Savings rate this period: ${(savingsRate * 100).toStringAsFixed(1)}%');
    }
    if (topCategoryName != null && topCategoryAmount != null && topCategoryPercent != null) {
      derivedLines.writeln(
        'Largest expense category: $topCategoryName at ${formatCurrency(topCategoryAmount)} '
        '(${(topCategoryPercent * 100).toStringAsFixed(0)}% of total expenses)',
      );
    }

    final prompt = '''
$_personaIntro

You are answering ONE focused question for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: ${formatDate(range.start)} to ${formatDate(range.end)}

Total income: ${formatCurrency(totalIncome)}
Total expenses: ${formatCurrency(totalExpense)}
Net: ${formatCurrency(net)}

Income breakdown by category:
${incomeLines.isEmpty ? '(no income in this period)' : incomeLines}

Expense breakdown by category:
${expenseLines.isEmpty ? '(no expenses in this period)' : expenseLines}
${derivedLines.isEmpty ? '' : '\n$derivedLines'}${profileLines.isEmpty ? '' : '\n$profileLines'}${continuityLines.isEmpty ? '' : '\n$continuityLines'}
Question: Give 3-5 concrete, specific next actions for the upcoming period — tie each to a number where possible (a dollar amount, a percentage, a category). Number the list. If there's a previous check-in above, build on it rather than repeating the same actions verbatim.

$_responseStyle
''';

    final decoded = await _postChatCompletion(
      apiKey: apiKey,
      modelSlug: modelSlug,
      messages: [
        {'role': 'system', 'content': prompt},
      ],
    );
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    return (choices.first['message']?['content'] as String?)?.trim() ?? '';
  }

  /// Performs the raw OpenRouter chat-completions HTTP call: builds the
  /// request, classifies network/HTTP errors into an [OpenRouterException]
  /// with the appropriate [OpenRouterErrorKind], and returns the decoded
  /// JSON response body on success.
  Future<Map<String, dynamic>> _postChatCompletion({
    required String apiKey,
    required String modelSlug,
    required List<Map<String, String>> messages,
  }) async {
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'X-Title': 'Arkad',
        },
        body: jsonEncode({'model': modelSlug, 'messages': messages}),
      );
    } catch (_) {
      throw OpenRouterException(
        'Could not reach OpenRouter. Check your connection.',
        kind: OpenRouterErrorKind.network,
      );
    }

    if (response.statusCode != 200) {
      OpenRouterErrorKind kind;
      String fallback;
      switch (response.statusCode) {
        case 401:
          kind = OpenRouterErrorKind.invalidKey;
          fallback = 'Your OpenRouter API key was rejected. Check it in Settings.';
          break;
        case 429:
          kind = OpenRouterErrorKind.rateLimited;
          fallback =
              'OpenRouter is rate-limiting this model right now — free models often have low limits. Try again in a bit, or switch models in Settings.';
          break;
        default:
          if (response.statusCode >= 500) {
            kind = OpenRouterErrorKind.server;
            fallback = 'OpenRouter is having issues right now. Try again shortly.';
          } else {
            kind = OpenRouterErrorKind.unknown;
            fallback = 'OpenRouter returned ${response.statusCode}.';
          }
      }

      String detail = fallback;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['error'];
        if (err is Map && err['message'] is String) detail = err['message'] as String;
      } catch (_) {}
      throw OpenRouterException(detail, kind: kind);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  AgentReply _parseReply(String content) {
    final (displayText, refIds, transactionMaps) = stripAndParseArkadBlocks(content);

    // Build a draft LedgerTransaction for each parsed map. Each gets a
    // distinct id (base timestamp + loop index) so a multi-item batch never
    // collides on id before the user approves and it's actually added.
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final transactions = <LedgerTransaction>[];
    for (var i = 0; i < transactionMaps.length; i++) {
      final map = transactionMaps[i];
      try {
        final type = (map['type'] as String).toLowerCase() == 'income'
            ? TransactionType.income
            : TransactionType.expense;
        transactions.add(LedgerTransaction(
          id: baseId + i,
          merchant: map['merchant'] as String,
          category: map['category'] as String,
          date: DateTime.now(),
          amount: (map['amount'] as num).toDouble(),
          type: type,
        ));
      } catch (_) {
        // Malformed entry — skip it, don't discard the rest of the batch.
      }
    }

    return AgentReply(
      text: displayText.isEmpty ? content : displayText,
      transactions: transactions,
      referencedTransactionIds: refIds,
    );
  }

  String _buildSystemPrompt({
    required List<LedgerTransaction> ledger,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
    required Profile profile,
    required String userMessage,
  }) {
    final totalIncome = ledger
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalExpense = ledger
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    // Use relevant transactions based on user message, with recent-20 as baseline
    final relevant = _relevantTransactions(userMessage, ledger, incomeCategories, expenseCategories);
    final transactionLines = relevant.map((t) {
      final sign = t.type == TransactionType.income ? '+' : '-';
      return '- ${formatDate(t.date)} · ${t.merchant} · ${t.category} · $sign\$${t.amount.toStringAsFixed(2)}';
    }).join('\n');

    // Build profile section if any profile field is non-empty
    final profileLines = _buildProfileSection(profile);

    return '''
$_personaIntro

${profileLines.isEmpty ? '' : '$profileLines\n'}The user's ledger currently has ${ledger.length} transactions. Total income: \$${totalIncome.toStringAsFixed(2)}. Total expenses: \$${totalExpense.toStringAsFixed(2)}. Relevant transactions:
$transactionLines

Known income categories: ${incomeCategories.join(', ')}
Known expense categories: ${expenseCategories.join(', ')}

You have two jobs:
1. If the user describes one or more transactions in natural language (e.g. "I spent \$12 on lunch at Chipotle" or "spent \$12 on lunch and \$40 on gas" or "got paid \$3200"), extract every transaction described and append, after your short conversational reply, a fenced code block tagged ```$_transactionTag containing ONLY a JSON array of every transaction described (no comments): [{"merchant": string, "category": string (pick the closest known category, or a sensible new one), "amount": number (always positive), "type": "income" | "expense"}, ...]. Always use an array, even for a single transaction. Only emit this block when the user is clearly describing one or more real transactions to log — nothing is added to the ledger automatically, the user reviews and approves each one, so extract everything you're reasonably confident about.
2. When discussing specific transactions from the context above, append a fenced code block tagged ```arkad_refs containing a JSON array of the transaction ids you referenced: [101, 104, 110]. Always include this when you reference specific transactions; only include ids that were actually provided to you.
3. If the user asks an analysis or informational question about their spending, answer it directly and concisely using the ledger data above. Do not emit the transaction code block in this case (but do emit arkad_refs if you reference specific transactions).

Keep replies short, warm, and precise. Never fabricate transactions that weren't described.
''';
  }

  /// Builds a brief "About the user" profile section for the system prompt.
  /// Returns empty string if all profile fields are empty.
  String _buildProfileSection(Profile profile) {
    final parts = <String>[];

    if (profile.displayName.isNotEmpty) {
      parts.add('User: ${profile.displayName}');
    }
    if (profile.countryCode.isNotEmpty) {
      final countryName = countryNameForCode(profile.countryCode) ?? profile.countryCode;
      parts.add('Country: $countryName');
    }
    if (profile.jobTitle.isNotEmpty) {
      parts.add('Job Title: ${profile.jobTitle}');
    }
    if (profile.occupationField.isNotEmpty) {
      parts.add('Field: ${profile.occupationField}');
    }
    if (profile.goalType.isNotEmpty) {
      final goal = profile.goalType == 'Other' && profile.goalOther.isNotEmpty
          ? profile.goalOther
          : profile.goalType;
      parts.add('Goal: $goal');
    }
    if (profile.longTermGoal.isNotEmpty) {
      parts.add('Long-term Financial Goal: ${profile.longTermGoal}');
    }
    if (profile.typicalMonthlyIncome != null && profile.typicalMonthlyIncome! > 0) {
      final formatted = formatCurrency(profile.typicalMonthlyIncome!);
      parts.add('Typical Monthly Income: $formatted');
    }
    if (profile.savingsGoalAmount != null && profile.savingsGoalAmount! > 0) {
      final formatted = formatCurrency(profile.savingsGoalAmount!);
      parts.add('Savings Goal: $formatted');
    }

    if (parts.isEmpty) return '';
    return 'About the user:\n${parts.map((p) => '- $p').join('\n')}\n';
  }

  /// Surfaces the most recent same-period-type analysis's overall assessment
  /// so the model can build on prior commentary instead of repeating it.
  /// Returns '' when there's no prior analysis of this period type, so
  /// first-time requests are unaffected.
  String _buildContinuitySection(SavedAnalysis? previous) {
    final text = previous?.overallText;
    if (previous == null || text == null || text.isEmpty) return '';
    return '''
Previous check-in (as of ${formatMDY(previous.rangeEnd)}): "$text"
Reflect on progress since then where relevant — don't just repeat it.
''';
  }

  /// Shared tone + formatting instructions for the four one-shot analysis
  /// prompts (goal progress / cost cutting / overall / actionable steps).
  /// Scoped to those prompts only — the chat system prompt is untouched.
  static const _responseStyle = '''
Before addressing any concern, name one specific positive thing grounded in the actual data — a category the user controlled well, income earned, progress made. Never fabricate a win. If the period was genuinely difficult, say so plainly and note effort/consistency where visible instead of inventing positives.

Respond in plain markdown only (no code fences around the whole response). Be concise: 2-4 short paragraphs or a short list. Ground your answer in the actual numbers given, not generic advice. Do NOT emit any ```$_transactionTag or ```arkad_refs code blocks — this is commentary only.''';

  /// Builds the system prompt for a one-shot, non-chat qualitative analysis
  /// of a time-ranged view of the user's finances (see [analyzeFinances]).
  String _buildAnalysisPrompt({
    required Profile profile,
    required DateTimeRange range,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> expenseByCategory,
    double? previousPeriodIncome,
    double? previousPeriodExpense,
  }) {
    final net = totalIncome - totalExpense;

    final categoryLines = expenseByCategory.entries
        .map((e) => '- ${e.key}: ${formatCurrency(e.value)}')
        .join('\n');

    final comparisonLines = StringBuffer();
    if (previousPeriodIncome != null || previousPeriodExpense != null) {
      comparisonLines.writeln('\nPrevious period for comparison:');
      if (previousPeriodIncome != null) {
        comparisonLines.writeln('- Income: ${formatCurrency(previousPeriodIncome)}');
      }
      if (previousPeriodExpense != null) {
        comparisonLines.writeln('- Expenses: ${formatCurrency(previousPeriodExpense)}');
      }
    }

    final profileLines = _buildProfileSection(profile);

    return '''
$_personaIntro

You are producing a one-shot qualitative analysis for the app's Analysis screen — this is NOT a conversation, there is no user message to respond to and no follow-up.

Period: ${formatDate(range.start)} to ${formatDate(range.end)}

Total income: ${formatCurrency(totalIncome)}
Total expenses: ${formatCurrency(totalExpense)}
Net: ${formatCurrency(net)}

Expense breakdown by category:
${categoryLines.isEmpty ? '(no expenses in this period)' : categoryLines}
${comparisonLines.toString()}
${profileLines.isEmpty ? '' : '\n$profileLines'}
Respond in markdown only (no code fences around the whole response). Give qualitative commentary on how this period's activity aligns with the user's stated financial goal and savings target (if any), note any notable category concentration, and offer one or two concrete suggestions. Do NOT emit any ```$_transactionTag or ```arkad_refs code blocks — this is commentary only, not a ledger action.
''';
  }

  /// Retrieves relevant transactions based on keyword/category/date matching.
  /// Returns recent transactions by default, plus any that match the user message.
  List<LedgerTransaction> _relevantTransactions(
    String userMessage,
    List<LedgerTransaction> allTransactions,
    List<String> incomeCategories,
    List<String> expenseCategories,
  ) {
    final messageLower = userMessage.toLowerCase();
    final matched = <int>{};

    // Category matches
    final allCategories = [...incomeCategories, ...expenseCategories];
    for (final category in allCategories) {
      if (messageLower.contains(category.toLowerCase())) {
        for (final t in allTransactions) {
          if (t.category.toLowerCase() == category.toLowerCase()) {
            matched.add(t.id);
          }
        }
      }
    }

    // Merchant matches
    final merchants = allTransactions.map((t) => t.merchant).toSet();
    for (final merchant in merchants) {
      if (messageLower.contains(merchant.toLowerCase())) {
        for (final t in allTransactions) {
          if (t.merchant.toLowerCase() == merchant.toLowerCase()) {
            matched.add(t.id);
          }
        }
      }
    }

    // Date phrase matches
    final dateMatches = _matchDatePhrases(messageLower);
    for (final t in allTransactions) {
      for (final dateRange in dateMatches) {
        if (t.date.isAfter(dateRange.$1) && t.date.isBefore(dateRange.$2.add(const Duration(days: 1)))) {
          matched.add(t.id);
        }
      }
    }

    // Start with recent-20 baseline
    final baselineIds = <int>{};
    for (final t in allTransactions.take(20)) {
      baselineIds.add(t.id);
    }

    // Union: matched + baseline
    final allMatched = {...matched, ...baselineIds};

    // Filter and sort by date (newest first)
    final result = allTransactions
        .where((t) => allMatched.contains(t.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Cap at ~40 transactions
    return result.take(40).toList();
  }

  /// Detects date phrases in the message and returns matching date ranges.
  /// Each tuple is (startDate, endDate) inclusive.
  List<(DateTime, DateTime)> _matchDatePhrases(String messageLower) {
    final ranges = <(DateTime, DateTime)>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Today
    if (messageLower.contains('today')) {
      ranges.add((today, today));
    }

    // Yesterday
    if (messageLower.contains('yesterday')) {
      ranges.add((yesterday, yesterday));
    }

    // This week (Monday to Sunday of current week)
    if (messageLower.contains('this week')) {
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      ranges.add((weekStart, weekEnd));
    }

    // This month
    if (messageLower.contains('this month')) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      ranges.add((monthStart, monthEnd));
    }

    // Last month
    if (messageLower.contains('last month')) {
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      ranges.add((lastMonthStart, lastMonthEnd));
    }

    // This year
    if (messageLower.contains('this year')) {
      final yearStart = DateTime(now.year, 1, 1);
      final yearEnd = DateTime(now.year, 12, 31);
      ranges.add((yearStart, yearEnd));
    }

    // Month names (January through December)
    const monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    for (var i = 0; i < monthNames.length; i++) {
      if (messageLower.contains(monthNames[i])) {
        final month = i + 1;
        // Use most recent occurrence of this month
        var targetYear = now.year;
        if (month > now.month) {
          targetYear--;
        }
        final monthStart = DateTime(targetYear, month, 1);
        final monthEnd = DateTime(targetYear, month + 1, 0);
        ranges.add((monthStart, monthEnd));
      }
    }

    return ranges;
  }
}

/// Public function to strip and parse arkad_transaction and arkad_refs blocks.
/// Returns (displayText, referencedTransactionIds, transactionMaps).
/// The displayText has both blocks removed. transactionMaps is a list of raw
/// transaction JSON maps — empty if no transaction block was found or it
/// couldn't be parsed at all. The model is expected to emit a JSON array,
/// but a bare JSON object is also accepted (wrapped into a single-element
/// list) for backward compatibility. Each array element is parsed
/// independently so one malformed entry doesn't discard the whole batch.
(String, List<int>, List<Map<String, dynamic>>) stripAndParseArkadBlocks(String content) {
  // Extract and remove arkad_transaction block
  final transactionPattern = RegExp('```arkad_transaction\\s*([\\s\\S]*?)```', multiLine: true);
  final transactionMatch = transactionPattern.firstMatch(content);

  final transactionMaps = <Map<String, dynamic>>[];
  var displayText = content;

  if (transactionMatch != null) {
    displayText = displayText.replaceRange(transactionMatch.start, transactionMatch.end, '');
    try {
      final decoded = jsonDecode(transactionMatch.group(1)!.trim());
      if (decoded is List) {
        for (final entry in decoded) {
          try {
            transactionMaps.add(entry as Map<String, dynamic>);
          } catch (_) {
            // Malformed entry, skip it but keep the rest of the batch.
          }
        }
      } else if (decoded is Map) {
        try {
          transactionMaps.add(decoded as Map<String, dynamic>);
        } catch (_) {
          // Malformed, treat as empty.
        }
      }
    } catch (_) {
      // Malformed JSON, treat as empty
    }
  }

  // Extract and remove arkad_refs block
  final refsPattern = RegExp('```arkad_refs\\s*([\\s\\S]*?)```', multiLine: true);
  final refsMatch = refsPattern.firstMatch(displayText);

  var refIds = <int>[];
  if (refsMatch != null) {
    displayText = displayText.replaceRange(refsMatch.start, refsMatch.end, '');
    try {
      final decoded = jsonDecode(refsMatch.group(1)!.trim());
      if (decoded is List) {
        refIds = decoded.whereType<int>().toList();
      }
    } catch (_) {
      // Malformed JSON, treat as empty list
    }
  }

  displayText = displayText.trim();
  return (displayText, refIds, transactionMaps);
}
