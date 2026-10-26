import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';

/// Grouped bar chart comparing income (green) and expense (yellow) across buckets
/// (daily, weekly, monthly, etc.). Self-wraps in AppCard with a bottom legend.
/// Handles variable bucket counts: skips labels when crowded to keep text readable.
class IncomeExpenseBarChart extends StatelessWidget {
  const IncomeExpenseBarChart({
    super.key,
    required this.buckets,
    required this.labelBuilder,
  });

  /// List of (bucketStart, income, expense) tuples.
  final List<(DateTime, double, double)> buckets;

  /// Formats the bucket's start DateTime into a readable axis label.
  final String Function(DateTime) labelBuilder;

  @override
  Widget build(BuildContext context) {
    // Compute the max value for axis scaling, seeded at 1 to guard against divide-by-zero.
    final maxValue = buckets.isEmpty
        ? 1.0
        : buckets.fold<double>(
            1.0,
            (m, b) => [m, b.$2, b.$3].reduce((a, v) => a > v ? a : v),
          );

    // Check for empty state: no buckets or all values are zero.
    final isEmpty =
        buckets.isEmpty || buckets.every((b) => b.$2 == 0 && b.$3 == 0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs. expenses', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 24),
          if (isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No activity in this range',
                  style: AppTextStyles.metadata(),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final rawInterval = maxValue / 4;
                final magnitude = math
                    .pow(10, (math.log(rawInterval) / math.ln10).floor())
                    .toDouble();
                final interval = [1.0, 2.0, 5.0, 10.0]
                    .map((step) => step * magnitude)
                    .firstWhere((step) => step >= rawInterval);
                final maxY = (maxValue / interval).ceil() * interval;
                final axisStyle = AppTextStyles.dmMono(
                  fontSize: 9,
                  color: AppColors.ink60,
                );
                final painter = TextPainter(
                  text: TextSpan(text: formatCurrency(maxY), style: axisStyle),
                  textDirection: TextDirection.ltr,
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final axisWidth = (painter.width + 12).clamp(
                  45.0,
                  constraints.maxWidth * 0.45,
                );
                final barChartWidth = constraints.maxWidth - axisWidth;
                return SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: [
                        for (int i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              // Income bar (green)
                              BarChartRodData(
                                toY: buckets[i].$2,
                                color: AppColors.darkGreen,
                                width: _barWidth(buckets.length, barChartWidth),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(
                                    _barWidth(buckets.length, barChartWidth) /
                                        2,
                                  ),
                                ),
                              ),
                              // Expense bar (yellow)
                              BarChartRodData(
                                toY: buckets[i].$3,
                                color: AppColors.pastelYellow,
                                width: _barWidth(buckets.length, barChartWidth),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(
                                    _barWidth(buckets.length, barChartWidth) /
                                        2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= buckets.length) {
                                return const SizedBox.shrink();
                              }

                              // Skip labels to avoid overlap: show ~8-10 labels max
                              final labelStep = _labelStep(buckets.length);
                              if (index % labelStep != 0) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labelBuilder(buckets[index].$1),
                                  style: AppTextStyles.dmMono(
                                    fontSize: 9,
                                    color: AppColors.ink50,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: axisWidth,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatCurrency(value),
                                  style: axisStyle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) =>
                              AppColors.ink.withValues(alpha: 0.9),
                          tooltipRoundedRadius: AppRadii.input,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label = rodIndex == 0 ? 'Income' : 'Expenses';
                            final value = formatCurrency(rod.toY);
                            return BarTooltipItem(
                              '$label\n$value',
                              AppTextStyles.manrope(
                                fontSize: 12,
                                color: AppColors.paper,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(color: AppColors.ink10, strokeWidth: 1);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                );
              },
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

  /// Compute adaptive bar width based on bucket count and available space.
  static double _barWidth(int bucketCount, double availableWidth) {
    final slotWidth = availableWidth / bucketCount;
    // Each group needs 2 bars, so allocate 28% for each bar
    final barWidth = (slotWidth * 0.14).clamp(3.0, 12.0);
    return barWidth;
  }

  /// Compute label skip step to show ~8-10 labels max across the range.
  static int _labelStep(int bucketCount) {
    if (bucketCount <= 10) return 1;
    if (bucketCount <= 20) return 2;
    if (bucketCount <= 40) return 4;
    return (bucketCount / 10).ceil();
  }
}

/// Small colored dot + label legend item.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.metadata()),
      ],
    );
  }
}
