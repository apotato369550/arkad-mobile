import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/app_state.dart';
import '../services/openrouter_service.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/expense_category_pie_chart.dart';
import '../widgets/stat_card.dart';

enum _AnalysisPreset { pastWeek, pastMonth, pastThreeMonths, pastYear, custom }

extension _AnalysisPresetLabel on _AnalysisPreset {
  String get label => switch (this) {
        _AnalysisPreset.pastWeek => '7 days',
        _AnalysisPreset.pastMonth => '30 days',
        _AnalysisPreset.pastThreeMonths => '90 days',
        _AnalysisPreset.pastYear => '1 year',
        _AnalysisPreset.custom => 'Custom',
      };
}

enum _RemarksStatus { idle, loading, loaded, error }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.appState,
    required this.onOpenSettings,
  });

  final AppState appState;
  final VoidCallback onOpenSettings;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late DateTimeRange _range;
  _AnalysisPreset _preset = _AnalysisPreset.pastMonth;
  _RemarksStatus _remarksStatus = _RemarksStatus.idle;
  String? _remarksMarkdown;
  String? _remarksError;
  OpenRouterErrorKind? _remarksErrorKind;

  @override
  void initState() {
    super.initState();
    _range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _loadRemarks();
  }

  void _setPreset(_AnalysisPreset preset) {
    final now = DateTime.now();
    late final DateTime start;
    switch (preset) {
      case _AnalysisPreset.pastWeek:
        start = now.subtract(const Duration(days: 7));
        break;
      case _AnalysisPreset.pastMonth:
        start = now.subtract(const Duration(days: 30));
        break;
      case _AnalysisPreset.pastThreeMonths:
        start = now.subtract(const Duration(days: 90));
        break;
      case _AnalysisPreset.pastYear:
        start = now.subtract(const Duration(days: 365));
        break;
      case _AnalysisPreset.custom:
        return; // Custom is handled separately
    }
    setState(() {
      _preset = preset;
      _range = DateTimeRange(start: start, end: now);
      _remarksStatus = _RemarksStatus.idle;
    });
    _loadRemarks();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked == null) return;

    // Validate: at least 7 days
    final spanDays = picked.end.difference(picked.start).inDays + 1;
    if (spanDays < 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a range of at least one week')),
        );
      }
      return;
    }

    setState(() {
      _preset = _AnalysisPreset.custom;
      _range = picked;
      _remarksStatus = _RemarksStatus.idle;
    });
    _loadRemarks();
  }

  Future<void> _loadRemarks() async {
    if (!widget.appState.apiConfig.hasKey) {
      setState(() {
        _remarksStatus = _RemarksStatus.error;
        _remarksErrorKind = OpenRouterErrorKind.invalidKey;
        _remarksError = null;
      });
      return;
    }

    setState(() => _remarksStatus = _RemarksStatus.loading);

    final (income, expense) = widget.appState.totalsForDateRange(_range);
    final byCategory = widget.appState.expenseByCategory(_range);
    final spanDays = _range.end.difference(_range.start).inDays + 1;

    // Previous period of equal length
    final prevRange = DateTimeRange(
      start: _range.start.subtract(Duration(days: spanDays)),
      end: _range.start.subtract(const Duration(days: 1)),
    );
    final (prevIncome, prevExpense) = widget.appState.totalsForDateRange(prevRange);

    try {
      final md = await OpenRouterService().analyzeFinances(
        apiKey: widget.appState.apiConfig.apiKey ?? '',
        modelSlug: widget.appState.apiConfig.modelSlug,
        profile: widget.appState.profile,
        range: _range,
        totalIncome: income,
        totalExpense: expense,
        expenseByCategory: byCategory,
        previousPeriodIncome: prevIncome,
        previousPeriodExpense: prevExpense,
      );
      if (!mounted) return;
      setState(() {
        _remarksMarkdown = md;
        _remarksStatus = _RemarksStatus.loaded;
      });
    } on OpenRouterException catch (e) {
      if (!mounted) return;
      setState(() {
        _remarksError = e.message;
        _remarksErrorKind = e.kind;
        _remarksStatus = _RemarksStatus.error;
      });
    }
  }

  String _labelForBucket(DateTime date) {
    final spanDays = _range.end.difference(_range.start).inDays + 1;
    if (spanDays <= 31) return formatDayLabel(date);
    if (spanDays <= 180) return formatMonthDay(date);
    return formatMonthLabel(date);
  }

  @override
  Widget build(BuildContext context) {
    final (totalIncome, totalExpense) = widget.appState.totalsForDateRange(_range);
    final buckets = widget.appState.cashFlowForRange(_range);
    final expenseByCategory = widget.appState.expenseByCategory(_range);

    final spanDays = _range.end.difference(_range.start).inDays + 1;

    // Net: income - expense
    final net = totalIncome - totalExpense;

    // Average daily expense
    final avgDailyExpense = spanDays > 0 ? totalExpense / spanDays : 0.0;

    // Previous period delta
    final prevRange = DateTimeRange(
      start: _range.start.subtract(Duration(days: spanDays)),
      end: _range.start.subtract(const Duration(days: 1)),
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
        _RangeSelector(
          preset: _preset,
          onSelectPreset: _setPreset,
          onCustom: _pickCustomRange,
        ),
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
        ExpenseCategoryPieChart(data: expenseByCategory),
        const SizedBox(height: 28),

        // Remarks panel
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arkad\'s take', style: AppTextStyles.cardHeading()),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    color: AppColors.ink60,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: _loadRemarks,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Body: loading, loaded, error, or idle
              if (_remarksStatus == _RemarksStatus.idle)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Ready when you are',
                      style: AppTextStyles.metadata(),
                    ),
                  ),
                )
              else if (_remarksStatus == _RemarksStatus.loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkGreen),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Reading your numbers…',
                          style: AppTextStyles.metadata(),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_remarksStatus == _RemarksStatus.loaded)
                MarkdownBody(
                  data: _remarksMarkdown ?? '',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.body(color: AppColors.ink),
                    h1: AppTextStyles.cardHeading(color: AppColors.ink),
                    h2: AppTextStyles.cardHeading(color: AppColors.ink),
                    strong: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    a: const TextStyle(
                      color: AppColors.darkGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else // error
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_remarksErrorKind == OpenRouterErrorKind.invalidKey)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add an OpenRouter key in Settings to get remarks from Arkad.',
                            style: AppTextStyles.body(),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: widget.onOpenSettings,
                            child: const Text('Open Settings'),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_remarksError != null)
                            Text(
                              _remarksError!,
                              style: AppTextStyles.body(color: AppColors.clay),
                            ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loadRemarks,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selector for preset ranges and custom option.
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.preset,
    required this.onSelectPreset,
    required this.onCustom,
  });

  final _AnalysisPreset preset;
  final ValueChanged<_AnalysisPreset> onSelectPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _AnalysisPreset.values.where((p) => p != _AnalysisPreset.custom))
          _Pill(
            label: p.label,
            isSelected: preset == p,
            onTap: () => onSelectPreset(p),
          ),
        _Pill(
          label: preset == _AnalysisPreset.custom && preset != _AnalysisPreset.pastMonth
              ? 'Custom'
              : 'Custom…',
          isSelected: preset == _AnalysisPreset.custom,
          onTap: onCustom,
        ),
      ],
    );
  }
}

/// Pill-style range button.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected ? AppColors.darkGreen : AppColors.ink10,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.paper : AppColors.ink,
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
