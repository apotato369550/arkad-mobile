import 'package:flutter/material.dart';
import '../models/analysis_period.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/stat_card.dart';
import 'analysis_detail_screen.dart';
import 'analysis_list_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  CashFlowRange _range = CashFlowRange.sevenDays;
  AnalysisPeriod _selectedPeriod = AnalysisPeriod.sevenDays;
  bool _requesting = false;

  String _labelForBucket(DateTime date) =>
      _range == CashFlowRange.sevenDays ? formatDayLabel(date) : formatMonthLabel(date);

  Future<void> _requestAnalysis() async {
    setState(() => _requesting = true);
    try {
      final id = await widget.appState.requestAnalysis(_selectedPeriod);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisDetailScreen(appState: widget.appState, analysisId: id),
        ),
      );
    } on AnalysisRequestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = widget.appState.dateTimeRangeForCashFlow(_range);
    final (totalIncome, totalExpense) = widget.appState.totalsForDateRange(dateRange);
    final buckets = widget.appState.cashFlow(_range);
    final expenseByCategory = widget.appState.expenseByCategory(dateRange);
    final incomeByCategory = widget.appState.incomeByCategory(dateRange);

    final spanDays = dateRange.end.difference(dateRange.start).inDays + 1;

    // Net: income - expense
    final net = totalIncome - totalExpense;

    // Average daily expense
    final avgDailyExpense = spanDays > 0 ? totalExpense / spanDays : 0.0;

    // Previous period delta
    final prevRange = DateTimeRange(
      start: dateRange.start.subtract(Duration(days: spanDays)),
      end: dateRange.start.subtract(const Duration(days: 1)),
    );
    final (_, prevExpense) = widget.appState.totalsForDateRange(prevRange);
    final expenseDelta = prevExpense > 0 ? (totalExpense - prevExpense) / prevExpense : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Page heading
        Text('Analysis', style: AppTextStyles.pageHeading()),
        const SizedBox(height: 28),

        // Range selector
        _RangeSelector(selected: _range, onChanged: (r) => setState(() => _range = r)),
        const SizedBox(height: 28),

        // Summary stats row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              StatCard(
                label: 'Income',
                amount: totalIncome,
                icon: Icons.trending_up_outlined,
                isIncome: true,
              ),
              const SizedBox(width: 12),
              StatCard(
                label: 'Expenses',
                amount: totalExpense,
                icon: Icons.trending_down_outlined,
                isIncome: false,
              ),
              const SizedBox(width: 12),
              _NetTile(amount: net),
              const SizedBox(width: 12),
              _AverageTile(amount: avgDailyExpense),
              const SizedBox(width: 12),
              _DeltaTile(delta: expenseDelta),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Income/expense bar chart
        IncomeExpenseBarChart(
          buckets: buckets,
          labelBuilder: _labelForBucket,
        ),
        const SizedBox(height: 28),

        // Expense by category pie chart
        CategoryPieChart(
          title: 'Expenses by category',
          data: expenseByCategory,
          emptyLabel: 'No expenses in this range',
        ),
        const SizedBox(height: 28),

        // Income by category pie chart
        CategoryPieChart(
          title: 'Income by category',
          data: incomeByCategory,
          emptyLabel: 'No income in this range',
        ),
        const SizedBox(height: 28),

        // Ask Arkad for an in-depth, saved analysis of a chosen period.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ask Arkad for an analysis', style: AppTextStyles.cardHeading()),
              const SizedBox(height: 6),
              Text(
                'Get an in-depth, saved write-up for a specific period.',
                style: AppTextStyles.metadata(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final period in AnalysisPeriod.values)
                    _PeriodPill(
                      period: period,
                      selected: period == _selectedPeriod,
                      onTap: () => setState(() => _selectedPeriod = period),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _AnalysisRequestAction(
                appState: widget.appState,
                period: _selectedPeriod,
                requesting: _requesting,
                onRequest: _requestAnalysis,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AnalysisListScreen(appState: widget.appState)),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: Text('Past analyses (${widget.appState.savedAnalyses.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selectable pill for a single [AnalysisPeriod], used in the "Ask Arkad for
/// an analysis" section. Visually mirrors [_RangeSelector]'s selected state
/// but pills are independent (not a segmented group) since there are six of
/// them and they wrap across lines on narrow screens.
class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.period, required this.selected, required this.onTap});

  final AnalysisPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          period.label,
          style: AppTextStyles.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}

/// The status/action area beneath the period pills — re-evaluated on every
/// build from live AppState so it reflects cooldowns/activity thresholds
/// immediately after a request completes.
class _AnalysisRequestAction extends StatelessWidget {
  const _AnalysisRequestAction({
    required this.appState,
    required this.period,
    required this.requesting,
    required this.onRequest,
  });

  final AppState appState;
  final AnalysisPeriod period;
  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    if (!appState.hasApiKey) {
      return const _StatusMessage(
        text: 'Add an OpenRouter API key in Settings to request an analysis.',
      );
    }

    if (!appState.canRequestAnalysis(period)) {
      final next = appState.nextAvailableAt(period);
      return _StatusMessage(
        text: next != null
            ? 'Available again on ${formatDate(next)}'
            : 'Not available yet',
      );
    }

    if (!appState.meetsActivityThreshold(period)) {
      return const _StatusMessage(
        text: 'Not enough recorded activity in this period yet — add a few more '
            'transactions first.',
      );
    }

    return ElevatedButton.icon(
      onPressed: requesting ? null : onRequest,
      icon: requesting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper),
            )
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text('Request ${period.label} analysis'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkGreen,
        foregroundColor: AppColors.paper,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
      ),
    );
  }
}

/// Disabled-looking inline status line shown when a period isn't requestable.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Text(text, style: AppTextStyles.metadata()),
    );
  }
}

/// Segmented 7D/6M/12M range selector, mirrors [CashFlowChart]'s selector.
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final CashFlowRange selected;
  final ValueChanged<CashFlowRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          for (final range in CashFlowRange.values) Expanded(child: _segment(range)),
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

/// Custom stat tile for net income/expense (no income/expense tint).
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
          Icon(
            amount >= 0 ? Icons.check_circle_outline : Icons.warning_outlined,
            size: 40,
            color: amount >= 0 ? AppColors.darkGreen : AppColors.clay,
          ),
          const SizedBox(height: 16),
          Text('Net', style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(
            formatCurrency(amount),
            style: AppTextStyles.amount(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// Custom stat tile for average daily expense.
class _AverageTile extends StatelessWidget {
  const _AverageTile({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: AppColors.sage,
          ),
          const SizedBox(height: 16),
          Text('Daily avg', style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(
            formatCurrency(amount),
            style: AppTextStyles.amount(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// Custom stat tile for expense delta vs previous period.
class _DeltaTile extends StatelessWidget {
  const _DeltaTile({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final percent = (delta.abs() * 100).toStringAsFixed(0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUp ? Icons.trending_up_outlined : Icons.trending_down_outlined,
            size: 40,
            color: isUp ? AppColors.clay : AppColors.darkGreen,
          ),
          const SizedBox(height: 16),
          Text('vs. prior', style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(
            '${isUp ? '▲' : '▼'} $percent%',
            style: AppTextStyles.amount(
              fontSize: 20,
              color: isUp ? AppColors.clay : AppColors.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}
