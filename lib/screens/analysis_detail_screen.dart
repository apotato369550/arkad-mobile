import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/analysis_period.dart';
import '../models/saved_analysis.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/stat_card.dart';

/// Detail view for a single [SavedAnalysis]. The four Q&A slots
/// (goal progress / cost cutting / overall / actionable steps) can each
/// still be `loading` when this screen opens — AppState fetches them in the
/// background and calls notifyListeners() as they resolve, so the
/// ListenableBuilder here picks up each transition without any polling.
class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({super.key, required this.appState, required this.analysisId});

  final AppState appState;
  final String analysisId;

  String _labelForBucketCount(DateTime date, int bucketCount) {
    return bucketCount <= 7 ? formatDayLabel(date) : formatMonthLabel(date);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final analysis = appState.findAnalysis(analysisId);

        return Scaffold(
          backgroundColor: AppColors.cream,
          appBar: AppBar(title: Text(analysis?.title ?? 'Analysis')),
          body: analysis == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'This analysis is no longer available.',
                      style: AppTextStyles.body(color: AppColors.ink60),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _AnalysisBody(analysis: analysis, labelForBucket: _labelForBucketCount),
        );
      },
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.analysis, required this.labelForBucket});

  final SavedAnalysis analysis;
  final String Function(DateTime, int) labelForBucket;

  @override
  Widget build(BuildContext context) {
    final net = analysis.totalIncome - analysis.totalExpense;
    final buckets = [
      for (final b in analysis.cashFlowBuckets) (b.start, b.income, b.expense),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Period header
        Text(
          '${analysis.period.label} · ${formatDate(analysis.rangeStart)} – ${formatDate(analysis.rangeEnd)}',
          style: AppTextStyles.metadata(),
        ),
        const SizedBox(height: 20),

        // Summary stats row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              StatCard(
                label: 'Income',
                amount: analysis.totalIncome,
                icon: Icons.trending_up_outlined,
                isIncome: true,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Expenses',
                amount: analysis.totalExpense,
                icon: Icons.trending_down_outlined,
                isIncome: false,
              ),
              const SizedBox(width: 12),
              _NetTile(amount: net),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Income/expense bar chart
        IncomeExpenseBarChart(
          buckets: buckets,
          labelBuilder: (date) => labelForBucket(date, buckets.length),
        ),
        const SizedBox(height: 28),

        // Category breakdowns
        CategoryPieChart(
          title: 'Expenses by category',
          data: analysis.expenseByCategory,
          emptyLabel: 'No expenses in this period',
        ),
        const SizedBox(height: 28),
        CategoryPieChart(
          title: 'Income by category',
          data: analysis.incomeByCategory,
          emptyLabel: 'No income in this period',
        ),
        const SizedBox(height: 28),

        // Arkad's take — four independently-loading Q&A slots
        _AnswerCard(
          heading: 'How close are we to your goal?',
          status: analysis.goalProgressStatus,
          text: analysis.goalProgressText,
          error: analysis.goalProgressError,
        ),
        const SizedBox(height: 16),
        _AnswerCard(
          heading: 'Where can we cut back?',
          status: analysis.costCuttingStatus,
          text: analysis.costCuttingText,
          error: analysis.costCuttingError,
        ),
        const SizedBox(height: 16),
        _AnswerCard(
          heading: 'Overall assessment',
          status: analysis.overallStatus,
          text: analysis.overallText,
          error: analysis.overallError,
        ),
        const SizedBox(height: 16),
        _AnswerCard(
          heading: 'Actionable steps',
          status: analysis.actionableStepsStatus,
          text: analysis.actionableStepsText,
          error: analysis.actionableStepsError,
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.heading,
    required this.status,
    required this.text,
    required this.error,
  });

  final String heading;
  final AnalysisAnswerStatus status;
  final String? text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: AppTextStyles.cardHeading()),
          const SizedBox(height: 16),
          switch (status) {
            AnalysisAnswerStatus.loading => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkGreen),
                      ),
                      const SizedBox(height: 16),
                      Text('Thinking…', style: AppTextStyles.metadata()),
                    ],
                  ),
                ),
              ),
            AnalysisAnswerStatus.loaded => MarkdownBody(
                data: text ?? '',
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body(color: AppColors.ink),
                  h1: AppTextStyles.cardHeading(color: AppColors.ink),
                  h2: AppTextStyles.cardHeading(color: AppColors.ink),
                  strong: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  a: const TextStyle(
                    color: AppColors.darkGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            AnalysisAnswerStatus.error => Text(
                error ?? 'Something went wrong.',
                style: AppTextStyles.body(color: AppColors.clay),
              ),
          },
        ],
      ),
    );
  }
}

class _NetTile extends StatelessWidget {
  const _NetTile({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net', style: AppTextStyles.metadata()),
          const SizedBox(height: 32),
          Text(formatCurrency(amount), style: AppTextStyles.amount(fontSize: 20)),
        ],
      ),
    );
  }
}
