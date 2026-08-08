import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/profile.dart';
import '../models/transaction.dart';
import 'formatters.dart';

class OpenRouterException implements Exception {
  OpenRouterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A parsed reply from the agent: the text to show in the chat bubble, plus
/// an optional structured transaction the agent extracted from the user's
/// message (see IDEA.md § Core idea — conversational ledger entry).
class AgentReply {
  AgentReply({
    required this.text,
    this.transaction,
    this.referencedTransactionIds = const [],
  });
  final String text;
  final LedgerTransaction? transaction;
  final List<int> referencedTransactionIds;
}

/// Direct browser/app → OpenRouter calls, BYOK. No proxy server.
/// See IDEA.md: "All calls are made directly from the browser to OpenRouter,
/// no proxy server" — mirrored here as direct client calls from the app.
class OpenRouterService {
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _transactionTag = 'arkad_transaction';

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
      throw OpenRouterException('Could not reach OpenRouter. Check your connection.');
    }

    if (response.statusCode != 200) {
      String detail = 'OpenRouter returned ${response.statusCode}.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final err = body['error'];
        if (err is Map && err['message'] is String) detail = err['message'] as String;
      } catch (_) {}
      throw OpenRouterException(detail);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OpenRouterException('OpenRouter returned an empty response.');
    }
    final content = (choices.first['message']?['content'] as String?)?.trim() ?? '';
    return _parseReply(content);
  }

  AgentReply _parseReply(String content) {
    final (displayText, refIds, transactionJson) = stripAndParseArkadBlocks(content);

    // Try to parse the transaction block if present
    if (transactionJson != null) {
      try {
        final type = (transactionJson['type'] as String).toLowerCase() == 'income'
            ? TransactionType.income
            : TransactionType.expense;
        final transaction = LedgerTransaction(
          id: DateTime.now().millisecondsSinceEpoch,
          merchant: transactionJson['merchant'] as String,
          category: transactionJson['category'] as String,
          date: DateTime.now(),
          amount: (transactionJson['amount'] as num).toDouble(),
          type: type,
        );
        final note = 'Added to your ledger: ${transaction.merchant} · '
            '${formatSignedCurrency(transaction.amount, isIncome: type == TransactionType.income)}';
        return AgentReply(
          text: displayText.isEmpty ? note : '$displayText\n\n$note',
          transaction: transaction,
          referencedTransactionIds: refIds,
        );
      } catch (_) {
        return AgentReply(
          text: displayText.isEmpty ? content : displayText,
          referencedTransactionIds: refIds,
        );
      }
    }

    return AgentReply(
      text: displayText.isEmpty ? content : displayText,
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
You are Arkad, named for the legendary richest man in Babylon — a patient, warm financial mentor, not a lecturing chatbot. You believe: a part of all one earns is theirs to keep (encourage saving before spending); money must be put to work, not left idle; guard savings from loss (favor sound, proven habits over speculation); a person's ability to earn is their greatest asset (encourage growth, not just cutting); plan for the future. Ground every answer in the user's actual data — their real transactions, categories, and goals — never generic platitudes when specifics are available. Be concise and actionable.

${profileLines.isEmpty ? '' : '$profileLines\n'}The user's ledger currently has ${ledger.length} transactions. Total income: \$${totalIncome.toStringAsFixed(2)}. Total expenses: \$${totalExpense.toStringAsFixed(2)}. Relevant transactions:
$transactionLines

Known income categories: ${incomeCategories.join(', ')}
Known expense categories: ${expenseCategories.join(', ')}

You have two jobs:
1. If the user describes a transaction in natural language (e.g. "I spent \$12 on lunch at Chipotle" or "got paid \$3200"), extract it and append, after your short conversational reply, a fenced code block tagged ```$_transactionTag containing ONLY this JSON (no comments): {"merchant": string, "category": string (pick the closest known category, or a sensible new one), "amount": number (always positive), "type": "income" | "expense"}. Only emit this block when the user is clearly describing a real transaction to log.
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
    if (profile.location.isNotEmpty) {
      parts.add('Location: ${profile.location}');
    }
    if (profile.occupation.isNotEmpty) {
      parts.add('Occupation: ${profile.occupation}');
    }
    if (profile.financialGoal.isNotEmpty) {
      parts.add('Financial Goal: ${profile.financialGoal}');
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
/// Returns (displayText, referencedTransactionIds, transactionJson).
/// The displayText has both blocks removed. transactionJson is null if no transaction block found.
(String, List<int>, Map<String, dynamic>?) stripAndParseArkadBlocks(String content) {
  // Extract and remove arkad_transaction block
  final transactionPattern = RegExp('```arkad_transaction\\s*([\\s\\S]*?)```', multiLine: true);
  final transactionMatch = transactionPattern.firstMatch(content);

  Map<String, dynamic>? transactionJson;
  var displayText = content;

  if (transactionMatch != null) {
    displayText = displayText.replaceRange(transactionMatch.start, transactionMatch.end, '');
    try {
      transactionJson = jsonDecode(transactionMatch.group(1)!.trim()) as Map<String, dynamic>;
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
  return (displayText, refIds, transactionJson);
}
