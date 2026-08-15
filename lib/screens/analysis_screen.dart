import 'package:flutter/material.dart';
import '../models/analysis_period.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/analysis_stat_tiles.dart' show showStatDetailSheet;
import '../widgets/app_card.dart';
import '../widgets/income_expense_bar_chart.dart';
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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: 'Income',
                  amount: totalIncome,
                  icon: Icons.trending_up_outlined,
                  isIncome: true,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Income',
                    amount: totalIncome,
                    isIncome: true,
                    periodCaption: _range.caption,
                    explanation: 'Money that came in during this period — your paychecks, side '
                        'income, and anything else you earned or received.',
                    breakdown: widget.appState.incomeByCategory(dateRange),
                    breakdownEmptyLabel: 'No income in this period',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Expenses',
                  amount: totalExpense,
                  icon: Icons.trending_down_outlined,
                  isIncome: false,
                  onTap: () => showStatDetailSheet(
                    context,
                    title: 'Expenses',
                    amount: totalExpense,
                    isIncome: false,
                    periodCaption: _range.caption,
                    explanation: 'Money that went out during this period — everything you '
                        'spent, paid, or gave away.',
                    breakdown: widget.appState.expenseByCategory(dateRange),
                    breakdownEmptyLabel: 'No expenses in this period',
                  ),
                ),
              ),
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
              if (_requesting) ...[
                const SizedBox(height: 12),
                Text(
                  'Arkad is analyzing your finances — this can take up to a minute…',
                  style: AppTextStyles.metadata(),
                ),
              ],
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
