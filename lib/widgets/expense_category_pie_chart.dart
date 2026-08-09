import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';
import '../models/category.dart';

/// Pie chart breaking down expenses by category. Automatically folds small
/// categories into "Other" if there are more than ~6 slices to keep the chart
/// legible. Self-wraps in AppCard with a detailed legend showing icon, color,
/// amount, and percentage for each category.
class ExpenseCategoryPieChart extends StatelessWidget {
  const ExpenseCategoryPieChart({super.key, required this.data});

  /// Map of category name to total expense amount.
  final Map<String, double> data;

  // Fixed categorical color palette. Repeats after 8 hues.
  static const List<Color> _paletteColors = [
    AppColors.darkGreen,
    AppColors.clay,
    AppColors.pastelYellow,
    AppColors.sage,
    Color(0xFF6B5B7B), // Plum tint
    Color(0xFFD4A574), // Warm tan
    Color(0xFF7BA39E), // Muted teal
    Color(0xFFF5D66B), // Light yellow (pastel yellow variant)
  ];

  @override
  Widget build(BuildContext context) {
    // Early return for empty state.
    if (data.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expenses by category', style: AppTextStyles.cardHeading()),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'No expenses in this range',
                style: AppTextStyles.metadata(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Sort categories by value descending.
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Fold small categories into "Other" if more than ~6 categories.
    final foldThreshold = 6;
    final (processedData, hasOther) = _foldSmallCategories(
      sortedEntries,
      foldThreshold,
    );

    final total = processedData.values.fold<double>(0, (sum, v) => sum + v);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expenses by category', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  for (int i = 0; i < processedData.length; i++)
                    PieChartSectionData(
                      value: processedData.values.elementAt(i),
                      color: _paletteColors[i % _paletteColors.length],
                      radius: 60,
                      titlePositionPercentageOffset: 0.6,
                      title: '',
                    ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 50,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Legend: one row per category with icon, color, name, amount, percentage.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < processedData.length; i++)
                _LegendItem(
                  category: processedData.keys.elementAt(i),
                  amount: processedData.values.elementAt(i),
                  total: total,
                  color: _paletteColors[i % _paletteColors.length],
                  hasOther: hasOther && i == processedData.length - 1,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fold smallest categories into "Other" if count exceeds [threshold].
  /// Returns (processedData, hasOther).
  static (Map<String, double>, bool) _foldSmallCategories(
    List<MapEntry<String, double>> sorted,
    int threshold,
  ) {
    if (sorted.length <= threshold) {
      return (Map.fromEntries(sorted), false);
    }

    // Keep the top [threshold-1] categories, fold the rest into "Other".
    final kept = sorted.sublist(0, threshold - 1);
    final folded = sorted.sublist(threshold - 1);
    final otherTotal = folded.fold<double>(0, (sum, e) => sum + e.value);

    final result = Map<String, double>.fromEntries(kept);
    result['Other'] = otherTotal;

    return (result, true);
  }
}

/// Legend item showing category icon, color swatch, name, amount, and percentage.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.category,
    required this.amount,
    required this.total,
    required this.color,
    this.hasOther = false,
  });

  final String category;
  final double amount;
  final double total;
  final Color color;
  final bool hasOther;

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    final percentageStr = '${percentage.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Icon (only for known categories, not "Other").
          if (!hasOther)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                iconForCategory(category),
                size: 16,
                color: AppColors.ink60,
              ),
            )
          else
            const SizedBox(width: 24), // Spacer for alignment when no icon

          // Color swatch.
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),

          // Category name.
          Expanded(
            child: Text(
              category,
              style: AppTextStyles.manrope(fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Amount.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              formatCurrency(amount),
              style: AppTextStyles.dmMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),

          // Percentage.
          Text(
            percentageStr,
            style: AppTextStyles.metadata(),
          ),
        ],
      ),
    );
  }
}
