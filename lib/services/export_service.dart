import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'formatters.dart';

/// Noto Sans covers currency symbols outside Latin-1 (₹, ₩, ₫, ₱, ...) that
/// the `pdf` package's built-in base-14 fonts render as missing-glyph boxes.
/// Loaded once and reused for every export — it's a ~2MB variable font, so
/// only one static instance is used (no separate bold face), which is why
/// PDF headings lean on color/size for emphasis rather than font weight.
pw.Font? _notoSansCache;

Future<pw.Font> _notoSans() async {
  final cached = _notoSansCache;
  if (cached != null) return cached;
  final data = await rootBundle.load('assets/fonts/NotoSans-Variable.ttf');
  final font = pw.Font.ttf(data);
  _notoSansCache = font;
  return font;
}

/// PDF color tokens mirroring lib/theme/app_colors.dart (kept separate
/// since the `pdf` package has its own PdfColor type, not Flutter's Color).
class _PdfColors {
  _PdfColors._();

  static const cream = PdfColor.fromInt(0xFFF4F0E6);
  static const paper = PdfColor.fromInt(0xFFFCFBF7);
  static const ink = PdfColor.fromInt(0xFF24362D);
  static const inkMuted = PdfColor.fromInt(0xFF6B7A70);
  static const darkGreen = PdfColor.fromInt(0xFF244F3A);
  static const sageTint = PdfColor.fromInt(0xFFE3EBDF);
  static const clay = PdfColor.fromInt(0xFFC87865);
  static const clayTint = PdfColor.fromInt(0xFFF7E9E5);
}

/// Renders the "Email export" data (transactions + saved AI analyses for a
/// date range) as a formatted, tabular PDF.
Future<Uint8List> buildExportPdf({
  required DateTimeRange range,
  required List<LedgerTransaction> transactions,
  required List<SavedAnalysis> analyses,
  required double totalIncome,
  required double totalExpense,
}) async {
  final font = await _notoSans();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
  final rangeLabel = '${formatMDY(range.start)} - ${formatMDY(range.end)}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 36),
      header: (context) => _pageHeader(rangeLabel, context.pageNumber),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _PdfColors.inkMuted),
        ),
      ),
      build: (context) => [
        _titleBlock(rangeLabel),
        pw.SizedBox(height: 20),
        _summaryRow(totalIncome, totalExpense),
        pw.SizedBox(height: 24),
        _sectionHeading('Transactions (${transactions.length})'),
        pw.SizedBox(height: 8),
        _transactionsTable(transactions),
        pw.SizedBox(height: 28),
        _sectionHeading('Saved AI analyses (${analyses.length})'),
        pw.SizedBox(height: 8),
        ..._analysesBlocks(analyses),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pageHeader(String rangeLabel, int pageNumber) {
  if (pageNumber == 1) return pw.SizedBox();
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 6),
    margin: const pw.EdgeInsets.only(bottom: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _PdfColors.sageTint, width: 1)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Arkad export', style: const pw.TextStyle(fontSize: 9, color: _PdfColors.inkMuted)),
        pw.Text(rangeLabel, style: const pw.TextStyle(fontSize: 9, color: _PdfColors.inkMuted)),
      ],
    ),
  );
}

pw.Widget _titleBlock(String rangeLabel) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Arkad', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: _PdfColors.darkGreen)),
      pw.SizedBox(height: 2),
      pw.Text('Data export', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _PdfColors.ink)),
      pw.SizedBox(height: 6),
      pw.Text(rangeLabel, style: const pw.TextStyle(fontSize: 10, color: _PdfColors.inkMuted)),
      pw.Text('Generated ${formatMDY(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: _PdfColors.inkMuted)),
    ],
  );
}

pw.Widget _summaryRow(double totalIncome, double totalExpense) {
  return pw.Row(
    children: [
      pw.Expanded(child: _statTile('Income', totalIncome, _PdfColors.sageTint, _PdfColors.darkGreen)),
      pw.SizedBox(width: 10),
      pw.Expanded(child: _statTile('Expenses', totalExpense, _PdfColors.clayTint, _PdfColors.clay)),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: _statTile('Net', totalIncome - totalExpense, _PdfColors.cream, _PdfColors.ink),
      ),
    ],
  );
}

pw.Widget _statTile(String label, double amount, PdfColor background, PdfColor amountColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(color: background, borderRadius: pw.BorderRadius.circular(10)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _PdfColors.inkMuted)),
        pw.SizedBox(height: 4),
        pw.Text(
          formatCurrency(amount.abs()),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: amountColor),
        ),
      ],
    ),
  );
}

pw.Widget _sectionHeading(String text) {
  return pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _PdfColors.ink));
}

pw.Widget _transactionsTable(List<LedgerTransaction> transactions) {
  if (transactions.isEmpty) {
    return pw.Text('No transactions in this range.', style: const pw.TextStyle(fontSize: 10, color: _PdfColors.inkMuted));
  }
  return pw.TableHelper.fromTextArray(
    headers: const ['Date', 'Type', 'Category', 'Merchant', 'Amount'],
    data: [
      for (final t in transactions)
        [
          formatMDY(t.date),
          t.type == TransactionType.income ? 'Income' : 'Expense',
          t.category,
          t.merchant,
          _pdfSignedAmount(t.amount, isIncome: t.type == TransactionType.income),
        ],
    ],
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _PdfColors.paper),
    headerDecoration: const pw.BoxDecoration(color: _PdfColors.darkGreen),
    cellStyle: const pw.TextStyle(fontSize: 9, color: _PdfColors.ink),
    cellAlignments: const {4: pw.Alignment.centerRight},
    columnWidths: const {
      0: pw.FlexColumnWidth(1.6),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.8),
      3: pw.FlexColumnWidth(2.4),
      4: pw.FlexColumnWidth(1.4),
    },
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    oddRowDecoration: const pw.BoxDecoration(color: _PdfColors.cream),
    border: null,
  );
}

List<pw.Widget> _analysesBlocks(List<SavedAnalysis> analyses) {
  if (analyses.isEmpty) {
    return [pw.Text('No saved analyses in this range.', style: const pw.TextStyle(fontSize: 10, color: _PdfColors.inkMuted))];
  }

  final blocks = <pw.Widget>[];
  for (final a in analyses) {
    blocks.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _PdfColors.cream, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(a.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _PdfColors.ink)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Income: ${formatCurrency(a.totalIncome)}   Expense: ${formatCurrency(a.totalExpense)}',
              style: const pw.TextStyle(fontSize: 9, color: _PdfColors.inkMuted),
            ),
            if (a.expenseByCategory.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _categoryTable(a.expenseByCategory),
            ],
            ..._qaSection('Goal progress', a.goalProgressStatus, a.goalProgressText),
            ..._qaSection('Cost cutting', a.costCuttingStatus, a.costCuttingText),
            ..._qaSection('Overall assessment', a.overallStatus, a.overallText),
            ..._qaSection('Actionable steps', a.actionableStepsStatus, a.actionableStepsText),
          ],
        ),
      ),
    );
  }
  return blocks;
}

pw.Widget _categoryTable(Map<String, double> byCategory) {
  final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return pw.TableHelper.fromTextArray(
    headers: const ['Expense category', 'Amount'],
    data: [for (final e in sorted) [e.key, formatCurrency(e.value)]],
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _PdfColors.paper),
    headerDecoration: const pw.BoxDecoration(color: _PdfColors.clay),
    cellStyle: const pw.TextStyle(fontSize: 8, color: _PdfColors.ink),
    cellAlignments: const {1: pw.Alignment.centerRight},
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    border: null,
  );
}

List<pw.Widget> _qaSection(String label, AnalysisAnswerStatus status, String? text) {
  final trimmed = text?.trim() ?? '';
  if (status != AnalysisAnswerStatus.loaded || trimmed.isEmpty) return const [];
  return [
    pw.SizedBox(height: 8),
    pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _PdfColors.darkGreen)),
    pw.SizedBox(height: 2),
    pw.Text(trimmed, style: const pw.TextStyle(fontSize: 9, color: _PdfColors.ink)),
  ];
}

String _pdfSignedAmount(double amount, {required bool isIncome}) {
  final sign = isIncome ? '+' : '-';
  return '$sign${formatCurrency(amount.abs())}';
}
