import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'formatters.dart';
import 'pdf_markdown.dart';

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
  static const pastelYellow = PdfColor.fromInt(0xFFF5D66B);
  static const sage = PdfColor.fromInt(0xFFB4C6AC);
  static const plum = PdfColor.fromInt(0xFF6B5B7B);
  static const tan = PdfColor.fromInt(0xFFD4A574);
  static const teal = PdfColor.fromInt(0xFF7BA39E);

  /// Mirrors `CategoryPieChart._paletteColors` in lib/widgets so a
  /// category's slice color matches between the in-app chart and the PDF.
  static const categoryPalette = [darkGreen, clay, pastelYellow, sage, plum, tan, teal, pastelYellow];
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
    final net = a.totalIncome - a.totalExpense;
    final spanDays = a.rangeEnd.difference(a.rangeStart).inDays + 1;
    final avgDailyExpense = spanDays > 0 ? a.totalExpense / spanDays : 0.0;
    final prevExpense = a.previousPeriodExpense;
    final expenseDelta = prevExpense > 0 ? (a.totalExpense - prevExpense) / prevExpense : 0.0;
    final deltaIsUp = expenseDelta > 0;

    final cashFlowChart = _cashFlowChart(a.cashFlowBuckets);
    final expensePie = _categoryPieChart('Expenses by category', a.expenseByCategory);
    final incomePie = _categoryPieChart('Income by category', a.incomeByCategory);

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
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _miniStatTile('Net', formatCurrency(net), net >= 0 ? _PdfColors.darkGreen : _PdfColors.clay)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _miniStatTile('Daily avg', formatCurrency(avgDailyExpense), _PdfColors.ink)),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _miniStatTile(
                    'vs. prior',
                    '${deltaIsUp ? '+' : '-'}${(expenseDelta.abs() * 100).toStringAsFixed(0)}%',
                    deltaIsUp ? _PdfColors.clay : _PdfColors.darkGreen,
                  ),
                ),
              ],
            ),
            if (cashFlowChart != null) ...[pw.SizedBox(height: 14), cashFlowChart],
            if (expensePie != null) ...[pw.SizedBox(height: 14), expensePie],
            if (incomePie != null) ...[pw.SizedBox(height: 14), incomePie],
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

pw.Widget _miniStatTile(String label, String value, PdfColor valueColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(color: _PdfColors.paper, borderRadius: pw.BorderRadius.circular(8)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _PdfColors.inkMuted)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: valueColor)),
      ],
    ),
  );
}

/// Grouped income/expense bar chart across a saved analysis's cash-flow
/// buckets — the PDF equivalent of [IncomeExpenseBarChart] on the Analysis
/// screen. Returns null (renders nothing) when there are no buckets.
pw.Widget? _cashFlowChart(List<CashFlowBucket> buckets) {
  if (buckets.isEmpty) return null;

  final maxValue = buckets.fold<double>(
    1.0,
    (m, b) => [m, b.income, b.expense].reduce((x, y) => x > y ? x : y),
  );
  final labelFn = buckets.length <= 7 ? formatDayLabel : formatMonthLabel;
  final labelStep = _bucketLabelStep(buckets.length);
  final barWidth = (470 / buckets.length * 0.28).clamp(2.0, 10.0).toDouble();

  const tickCount = 4;
  final yTicks = [for (int i = 0; i <= tickCount; i++) maxValue * i / tickCount];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Income vs. expenses', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _PdfColors.darkGreen)),
      pw.SizedBox(height: 6),
      pw.SizedBox(
        height: 150,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis.fromStrings(
              [for (int i = 0; i < buckets.length; i++) i % labelStep == 0 ? labelFn(buckets[i].start) : ''],
              textStyle: const pw.TextStyle(fontSize: 6, color: _PdfColors.inkMuted),
            ),
            yAxis: pw.FixedAxis<double>(
              yTicks,
              format: (v) => formatCurrency(v.toDouble()),
              textStyle: const pw.TextStyle(fontSize: 6, color: _PdfColors.inkMuted),
              divisions: true,
              divisionsColor: _PdfColors.sageTint,
            ),
          ),
          datasets: [
            pw.BarDataSet(
              legend: 'Income',
              color: _PdfColors.darkGreen,
              width: barWidth,
              offset: -barWidth * 0.6,
              data: [for (int i = 0; i < buckets.length; i++) pw.PointChartValue(i.toDouble(), buckets[i].income)],
            ),
            pw.BarDataSet(
              legend: 'Expenses',
              color: _PdfColors.pastelYellow,
              width: barWidth,
              offset: barWidth * 0.6,
              data: [for (int i = 0; i < buckets.length; i++) pw.PointChartValue(i.toDouble(), buckets[i].expense)],
            ),
          ],
          bottom: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _chartLegendDot(_PdfColors.darkGreen, 'Income'),
                pw.SizedBox(width: 14),
                _chartLegendDot(_PdfColors.pastelYellow, 'Expenses'),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

int _bucketLabelStep(int bucketCount) {
  if (bucketCount <= 10) return 1;
  if (bucketCount <= 20) return 2;
  if (bucketCount <= 40) return 4;
  return (bucketCount / 10).ceil();
}

pw.Widget _chartLegendDot(PdfColor color, String label) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: _PdfColors.inkMuted)),
    ],
  );
}

/// Category breakdown pie chart with a side legend (name + share of total),
/// mirroring [CategoryPieChart] on the Analysis screen — including folding
/// categories past the 6th into "Other" so the chart stays legible. Returns
/// null (renders nothing) when [data] is empty.
pw.Widget? _categoryPieChart(String title, Map<String, double> data) {
  if (data.isEmpty) return null;

  final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  const foldThreshold = 6;
  final Map<String, double> processed;
  if (sorted.length <= foldThreshold) {
    processed = Map.fromEntries(sorted);
  } else {
    final kept = sorted.sublist(0, foldThreshold - 1);
    final folded = sorted.sublist(foldThreshold - 1);
    final otherTotal = folded.fold<double>(0, (sum, e) => sum + e.value);
    processed = Map.fromEntries(kept)..['Other'] = otherTotal;
  }
  final entries = processed.entries.toList();
  final total = processed.values.fold<double>(0, (sum, v) => sum + v);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _PdfColors.darkGreen)),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            height: 100,
            child: pw.Chart(
              grid: pw.PieGrid(),
              datasets: [
                for (int i = 0; i < entries.length; i++)
                  pw.PieDataSet(
                    value: entries[i].value,
                    color: _PdfColors.categoryPalette[i % _PdfColors.categoryPalette.length],
                    borderColor: _PdfColors.cream,
                    legendPosition: pw.PieLegendPosition.none,
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < entries.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 7,
                          height: 7,
                          decoration: pw.BoxDecoration(
                            color: _PdfColors.categoryPalette[i % _PdfColors.categoryPalette.length],
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          child: pw.Text(entries[i].key, style: const pw.TextStyle(fontSize: 7.5, color: _PdfColors.ink)),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(formatCurrency(entries[i].value), style: const pw.TextStyle(fontSize: 7.5, color: _PdfColors.ink)),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          '${total > 0 ? (entries[i].value / total * 100).toStringAsFixed(0) : '0'}%',
                          style: const pw.TextStyle(fontSize: 7.5, color: _PdfColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

List<pw.Widget> _qaSection(String label, AnalysisAnswerStatus status, String? text) {
  final trimmed = text?.trim() ?? '';
  if (status != AnalysisAnswerStatus.loaded || trimmed.isEmpty) return const [];
  return [
    pw.SizedBox(height: 8),
    pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _PdfColors.darkGreen)),
    pw.SizedBox(height: 4),
    ...buildMarkdownWidgets(
      trimmed,
      const PdfMarkdownTheme(
        baseStyle: pw.TextStyle(fontSize: 9, color: _PdfColors.ink),
        strongColor: _PdfColors.ink,
        headingColor: _PdfColors.darkGreen,
        linkColor: _PdfColors.darkGreen,
        mutedColor: _PdfColors.inkMuted,
        ruleColor: _PdfColors.sageTint,
      ),
    ),
  ];
}

String _pdfSignedAmount(double amount, {required bool isIncome}) {
  final sign = isIncome ? '+' : '-';
  return '$sign${formatCurrency(amount.abs())}';
}
