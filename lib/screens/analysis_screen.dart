import 'package:flutter/material.dart';
import '../models/analysis_period.dart';
import '../models/category.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/analysis_stat_tiles.dart' show showStatDetailSheet;
import '../widgets/app_card.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/saved_analysis_card.dart';
import 'analysis_list_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  CashFlowRange _range = CashFlowRange.sevenDays;
  String _labelForBucket(DateTime date) => switch (_range) {
    CashFlowRange.sevenDays => formatDayLabel(date),
    CashFlowRange.sevenWeeks => formatMonthDay(date),
    CashFlowRange.sevenMonths => formatMonthLabel(date),
  };

  @override
  void initState() {
    super.initState();
    widget.appState.pruneExpiredAnalyses(notify: false);
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = widget.appState.dateTimeRangeForCashFlow(_range);
    final (totalIncome, totalExpense) = widget.appState.totalsForDateRange(
      dateRange,
    );
    final buckets = widget.appState.cashFlow(_range);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Page heading
        Text('Analysis', style: AppTextStyles.pageHeading()),
        const SizedBox(height: 28),

        // Range selector
        _RangeSelector(
          selected: _range,
          onChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: 28),

        // Summary stats row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: 'Income',
                  amount: totalIncome,
                  iconAsset: categoryIconAsset('income', isIncome: true),
                  isIncome: true,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Income',
                    amount: totalIncome,
                    isIncome: true,
                    periodCaption: _range.caption,
                    explanation:
                        'Money that came in during this period — your paychecks, side '
                        'income, and anything else you earned or received.',
                    breakdown: widget.appState.incomeByCategory(dateRange),
                    breakdownEmptyLabel: 'No income in this period',
                    categoryIcons: widget.appState.categoryIcons,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Expenses',
                  amount: totalExpense,
                  iconAsset: categoryIconAsset('bills_up', isIncome: false),
                  isIncome: false,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Expenses',
                    amount: totalExpense,
                    isIncome: false,
                    periodCaption: _range.caption,
                    explanation:
                        'Money that went out during this period — everything you '
                        'spent, paid, or gave away.',
                    breakdown: widget.appState.expenseByCategory(dateRange),
                    breakdownEmptyLabel: 'No expenses in this period',
                    categoryIcons: widget.appState.categoryIcons,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Income/expense bar chart
        IncomeExpenseBarChart(buckets: buckets, labelBuilder: _labelForBucket),
        const SizedBox(height: 28),

        Text('Latest Analysis', style: AppTextStyles.cardHeading()),
        const SizedBox(height: 14),
        if (widget.appState.savedAnalyses.isNotEmpty)
          SavedAnalysisCard(
            appState: widget.appState,
            analysis: widget.appState.savedAnalyses.first,
          )
        else
          AppCard(
            child: Text(
              'Your latest analysis will appear here. Choose a period below to get started.',
              style: AppTextStyles.body(color: AppColors.ink60),
            ),
          ),
        const SizedBox(height: 28),
        Text('Explore your analyses', style: AppTextStyles.cardHeading()),
        const SizedBox(height: 8),
        Text(
          'Browse by period. Archive a snapshot to keep it.',
          style: AppTextStyles.metadata(),
        ),
        const SizedBox(height: 16),
        for (final period in AnalysisPeriod.values) _historyButton(period),
      ],
    );
  }

  Widget _historyButton(AnalysisPeriod period) {
    final state = widget.appState;
    final hasHistory = state.savedAnalyses.any((a) => a.period == period);
    final available = hasHistory || state.meetsActivityThreshold(period);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: AppColors.paper,
        ),
        onPressed: !available
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AnalysisListScreen(appState: state, period: period),
                ),
              ),
        child: Row(
          children: [
            const Icon(Icons.insights_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View ${period.historyLabel} Analyses'),
                  if (!available || period == AnalysisPeriod.sixMonths)
                    Text(
                      !available ? 'Not enough data yet' : 'Every six months',
                      style: AppTextStyles.metadata(),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final CashFlowRange selected;
  final ValueChanged<CashFlowRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (final range in CashFlowRange.values)
            Expanded(child: _segment(range)),
        ],
      ),
    );
  }

  Widget _segment(CashFlowRange range) {
    final isSelected = range == selected;
    return GestureDetector(
      onTap: () => onChanged(range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          range.shortLabel,
          style: AppTextStyles.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}
