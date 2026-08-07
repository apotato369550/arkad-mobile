import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
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
  AgentReply({required this.text, this.transaction});
  final String text;
  final LedgerTransaction? transaction;
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
    required List<ChatMessage> history,
    required List<LedgerTransaction> ledger,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
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
    final pattern = RegExp('```$_transactionTag\\s*([\\s\\S]*?)```', multiLine: true);
    final match = pattern.firstMatch(content);
    if (match == null) {
      return AgentReply(text: content);
    }

    final displayText = content.replaceRange(match.start, match.end, '').trim();
    try {
      final json = jsonDecode(match.group(1)!.trim()) as Map<String, dynamic>;
      final type = (json['type'] as String).toLowerCase() == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final transaction = LedgerTransaction(
        id: DateTime.now().millisecondsSinceEpoch,
        merchant: json['merchant'] as String,
        category: json['category'] as String,
        date: DateTime.now(),
        amount: (json['amount'] as num).toDouble(),
        type: type,
      );
      final note = 'Added to your ledger: ${transaction.merchant} · '
          '${formatSignedCurrency(transaction.amount, isIncome: type == TransactionType.income)}';
      return AgentReply(
        text: displayText.isEmpty ? note : '$displayText\n\n$note',
        transaction: transaction,
      );
    } catch (_) {
      return AgentReply(text: displayText.isEmpty ? content : displayText);
    }
  }

  String _buildSystemPrompt({
    required List<LedgerTransaction> ledger,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
  }) {
    final totalIncome = ledger
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalExpense = ledger
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final recent = ledger.take(20).map((t) {
      final sign = t.type == TransactionType.income ? '+' : '-';
      return '- ${formatDate(t.date)} · ${t.merchant} · ${t.category} · $sign\$${t.amount.toStringAsFixed(2)}';
    }).join('\n');

    return '''
You are Arkad, a calm and precise personal finance assistant embedded in a finance-tracking app.

The user's ledger currently has ${ledger.length} transactions. Total income: \$${totalIncome.toStringAsFixed(2)}. Total expenses: \$${totalExpense.toStringAsFixed(2)}. Recent transactions:
$recent

Known income categories: ${incomeCategories.join(', ')}
Known expense categories: ${expenseCategories.join(', ')}

You have two jobs:
1. If the user describes a transaction in natural language (e.g. "I spent \$12 on lunch at Chipotle" or "got paid \$3200"), extract it and append, after your short conversational reply, a fenced code block tagged ```$_transactionTag containing ONLY this JSON (no comments): {"merchant": string, "category": string (pick the closest known category, or a sensible new one), "amount": number (always positive), "type": "income" | "expense"}. Only emit this block when the user is clearly describing a real transaction to log.
2. If the user asks an analysis or informational question about their spending, answer it directly and concisely using the ledger data above. Do not emit the transaction code block in this case.

Keep replies short, warm, and precise. Never fabricate transactions that weren't described.
''';
  }
}
