import 'package:flutter/material.dart' show DateTimeRange;
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'formatters.dart';

/// Caps how many transaction rows go into the export body — a `mailto:`
/// body is a URL, and very large exports risk hitting a mail client's or
/// OS's URL length limit. See [ExportDataCard].
const int maxExportTransactionRows = 300;

/// Builds the plain-text body for the "Email export" action in Settings:
/// transactions and saved AI analyses (quantitative totals plus whichever
/// qualitative Q&A text has loaded) within [range]. Callers pass in
/// [transactions]/[analyses] already filtered to the range (see
/// AppState.transactionsInRange, AppState.savedAnalysesInRange).
String buildExportEmailBody({
  required DateTimeRange range,
  required List<LedgerTransaction> transactions,
  required List<SavedAnalysis> analyses,
}) {
  final buffer = StringBuffer()
    ..writeln('Arkad data export')
    ..writeln('${formatMDY(range.start)} to ${formatMDY(range.end)}')
    ..writeln('Generated ${formatMDY(DateTime.now())}')
    ..writeln();

  _writeTransactions(buffer, transactions);
  buffer.writeln();
  _writeAnalyses(buffer, analyses);

  return buffer.toString();
}

void _writeTransactions(StringBuffer buffer, List<LedgerTransaction> transactions) {
  buffer.writeln('--- Transactions (${transactions.length}) ---');
  if (transactions.isEmpty) {
    buffer.writeln('No transactions in this range.');
    return;
  }
  buffer.writeln('Date, Type, Category, Merchant, Amount');
  for (final t in transactions.take(maxExportTransactionRows)) {
    final sign = t.type == TransactionType.income ? '+' : '-';
    buffer.writeln(
      '${formatMDY(t.date)}, ${t.type.name}, ${t.category}, ${t.merchant}, $sign${t.amount.toStringAsFixed(2)}',
    );
  }
  final hidden = transactions.length - maxExportTransactionRows;
  if (hidden > 0) {
    buffer.writeln('... $hidden more not shown (open Arkad for the full list).');
  }
}

void _writeAnalyses(StringBuffer buffer, List<SavedAnalysis> analyses) {
  buffer.writeln('--- Saved AI analyses (${analyses.length}) ---');
  if (analyses.isEmpty) {
    buffer.writeln('No saved analyses in this range.');
    return;
  }
  for (final a in analyses) {
    buffer
      ..writeln()
      ..writeln(a.title)
      ..writeln('Income: ${formatCurrency(a.totalIncome)}   Expense: ${formatCurrency(a.totalExpense)}');
    if (a.expenseByCategory.isNotEmpty) {
      final cats = a.expenseByCategory.entries.map((e) => '${e.key}: ${formatCurrency(e.value)}').join(', ');
      buffer.writeln('Expense by category: $cats');
    }
    _writeAnswer(buffer, 'Goal progress', a.goalProgressStatus, a.goalProgressText);
    _writeAnswer(buffer, 'Cost cutting', a.costCuttingStatus, a.costCuttingText);
    _writeAnswer(buffer, 'Overall assessment', a.overallStatus, a.overallText);
    _writeAnswer(buffer, 'Actionable steps', a.actionableStepsStatus, a.actionableStepsText);
  }
}

void _writeAnswer(StringBuffer buffer, String label, AnalysisAnswerStatus status, String? text) {
  if (status != AnalysisAnswerStatus.loaded) return;
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) return;
  buffer.writeln('$label: $trimmed');
}
