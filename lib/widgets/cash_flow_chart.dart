import 'package:flutter/material.dart';
import 'app_card.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';

/// Income-vs-expense bar chart with a 7D/30D/3M/12M range selector. No
/// charting package — plain rows of rounded-top bars, sized responsively so
/// any bucket count (7 daily bars up to 30) fits without overflow.
/// See STYLE_GUIDE.md § Cash flow chart.
class CashFlowChart extends StatefulWidget {
  const CashFlowChart({super.key, required this.appState});

  final AppState appState;

  @override
  State<CashFlowChart> createState() => _CashFlowChartState();
}

class _CashFlowChartState extends State<CashFlowChart> {
  CashFlowRange _range = CashFlowRange.sevenDays;

  @override
  Widget build(BuildContext context) {
    final days = widget.appState.cashFlow(_range);
    final maxValue = days.fold<double>(
      1,
      (m, d) => [m, d.$2, d.$3].reduce((a, b) => a > b ? a : b),
    );
    const chartHeight = 120.0;
    final labelStep = switch (_range) {
      CashFlowRange.sevenDays => 1,
      CashFlowRange.thirtyDays => 5,
      CashFlowRange.threeMonths => 2,
      CashFlowRange.twelveMonths => 1,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash flow', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 4),
          Text(_range.caption, style: AppTextStyles.metadata()),
          const SizedBox(height: 14),
          _RangeSelector(selected: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / days.length;
              final barWidth = (slotWidth * 0.28).clamp(2.0, 10.0);
              final barGap = (slotWidth * 0.08).clamp(1.0, 3.0);
              return SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Bar(
                              height: chartHeight * (d.$2 / maxValue),
                              width: barWidth,
                              color: AppColors.darkGreen,
                            ),
                            SizedBox(width: barGap),
                            _Bar(
                              height: chartHeight * (d.$3 / maxValue),
                              width: barWidth,
                              color: AppColors.pastelYellow,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      i % labelStep == 0 ? _labelFor(days[i].$1) : '',
                      style: AppTextStyles.dmMono(fontSize: 9, color: AppColors.ink50),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Legend(color: AppColors.darkGreen, label: 'Income'),
              const SizedBox(width: 20),
              _Legend(color: AppColors.pastelYellow, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  String _labelFor(DateTime date) => switch (_range) {
        CashFlowRange.sevenDays => formatDayLabel(date),
        CashFlowRange.thirtyDays => formatDayNumber(date),
        CashFlowRange.threeMonths => formatMonthDay(date),
        CashFlowRange.twelveMonths => formatMonthLabel(date),
      };
}

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

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.width, required this.color});
  final double height;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height.clamp(3, double.infinity),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.vertical(top: Radius.circular(width / 2)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.metadata()),
      ],
    );
  }
}
