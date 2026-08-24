import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/analysis_period.dart';
import '../models/category.dart';
import '../models/saved_analysis.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/analysis_stat_tiles.dart';
import '../widgets/app_card.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/stat_card.dart';

/// Detail view for a single [SavedAnalysis]. By the time a [SavedAnalysis]
/// exists, AppState has already awaited all four Q&A slots (goal progress /
/// cost cutting / overall / actionable steps), so each is `loaded` or
/// `error` — never `loading` — for analyses created after that change. The
/// ListenableBuilder here still tracks AppState so edits (e.g. deletion)
/// while this screen is open are reflected without polling.
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
              : _AnalysisBody(analysis: analysis, appState: appState, labelForBucket: _labelForBucketCount),
        );
      },
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.analysis, required this.appState, required this.labelForBucket});

  final SavedAnalysis analysis;
  final AppState appState;
  final String Function(DateTime, int) labelForBucket;

  @override
  Widget build(BuildContext context) {
    final net = analysis.totalIncome - analysis.totalExpense;
    final buckets = [
      for (final b in analysis.cashFlowBuckets) (b.start, b.income, b.expense),
    ];

    final spanDays = analysis.rangeEnd.difference(analysis.rangeStart).inDays + 1;
    final avgDailyExpense = spanDays > 0 ? analysis.totalExpense / spanDays : 0.0;
    final prevExpense = analysis.previousPeriodExpense;
    final expenseDelta = prevExpense > 0
        ? (analysis.totalExpense - prevExpense) / prevExpense
        : 0.0;

    final periodCaption =
        '${analysis.period.label} · ${formatDate(analysis.rangeStart)} – ${formatDate(analysis.rangeEnd)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Period header
        Text(periodCaption, style: AppTextStyles.metadata()),
        const SizedBox(height: 20),

        // Income/Expenses row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: 'Income',
                  amount: analysis.totalIncome,
                  iconAsset: categoryIconAsset('income', isIncome: true),
                  isIncome: true,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Income',
                    amount: analysis.totalIncome,
                    isIncome: true,
                    periodCaption: periodCaption,
                    explanation: 'Money that came in during this period — your paychecks, side '
                        'income, and anything else you earned or received.',
                    breakdown: analysis.incomeByCategory,
                    breakdownEmptyLabel: 'No income in this period',
                    categoryIcons: appState.categoryIcons,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Expenses',
                  amount: analysis.totalExpense,
                  iconAsset: categoryIconAsset('bills_up', isIncome: false),
                  isIncome: false,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Expenses',
                    amount: analysis.totalExpense,
                    isIncome: false,
                    periodCaption: periodCaption,
                    explanation: 'Money that went out during this period — everything you '
                        'spent, paid, or gave away.',
                    breakdown: analysis.expenseByCategory,
                    breakdownEmptyLabel: 'No expenses in this period',
                    categoryIcons: appState.categoryIcons,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Net / Daily average / vs. prior row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: NetStatTile(amount: net)),
              const SizedBox(width: 12),
              Expanded(child: AverageStatTile(amount: avgDailyExpense)),
              const SizedBox(width: 12),
              Expanded(child: DeltaStatTile(delta: expenseDelta)),
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
          categoryIcons: appState.categoryIcons,
          isIncome: false,
          emptyLabel: 'No expenses in this period',
        ),
        const SizedBox(height: 28),
        CategoryPieChart(
          title: 'Income by category',
          data: analysis.incomeByCategory,
          categoryIcons: appState.categoryIcons,
          isIncome: true,
          emptyLabel: 'No income in this period',
        ),
        const SizedBox(height: 28),

        // Arkad's take — four independently-loading Q&A slots
        _AnswerCard(
          heading: 'How purposeful was your spending?',
          status: analysis.goalProgressStatus,
          text: analysis.goalProgressText,
          error: analysis.goalProgressError,
        ),
        const SizedBox(height: 16),
        _AnswerCard(
          heading: 'What could have been saved better?',
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
