import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'app_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';
import '../models/category.dart';

/// Pie chart breaking down a category→amount map (expenses OR income) for a
/// given [title]. Automatically folds small categories into "Other" if there
/// are more than ~6 slices to keep the chart legible. Self-wraps in AppCard
/// with a detailed legend showing icon, color, amount, and percentage for
/// each category. Shared by the "Expenses by category" and "Income by
/// category" cards — same shape, different data/title.
class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({
    super.key,
    required this.title,
    required this.data,
    required this.categoryIcons,
    required this.isIncome,
    this.emptyLabel = 'No activity in this range',
  });

  /// Card heading, e.g. "Expenses by category" or "Income by category".
  final String title;

  /// Map of category name to total amount.
  final Map<String, double> data;

  /// Map of category name to icon key for custom categories.
  final Map<String, String> categoryIcons;

  /// Whether this chart is showing income (green icon tint) or expense (red
  /// icon tint) categories.
  final bool isIncome;

  /// Shown in place of the chart when [data] is empty.
  final String emptyLabel;

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  String? _selectedCategory;

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
    final data = widget.data;
    final title = widget.title;
    final emptyLabel = widget.emptyLabel;
    final isIncome = widget.isIncome;
    final categoryIcons = widget.categoryIcons;
    // Early return for empty state.
    if (data.isEmpty || data.values.every((value) => value <= 0)) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.cardHeading()),
            const SizedBox(height: 40),
            Center(
              child: Image.asset(
                categoryIconAsset('analysis', isIncome: isIncome),
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(emptyLabel, style: AppTextStyles.metadata())),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Sort categories by value descending.
    final sortedEntries =
        data.entries.where((entry) => entry.value > 0).toList()
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
          Text(title, style: AppTextStyles.cardHeading()),
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
                      radius:
                          processedData.keys.elementAt(i) == _selectedCategory
                          ? 70
                          : 60,
                      titlePositionPercentageOffset: 0.6,
                      title:
                          processedData.keys.elementAt(i) == _selectedCategory
                          ? '${(processedData.values.elementAt(i) / total * 100).toStringAsFixed(1)}%'
                          : '',
                      titleStyle: AppTextStyles.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.paper,
                      ),
                    ),
                ],
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent && event is! FlPointerHoverEvent) {
                      return;
                    }
                    final index =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                    setState(
                      () => _selectedCategory =
                          index >= 0 && index < processedData.length
                          ? processedData.keys.elementAt(index)
                          : null,
                    );
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              processedData.containsKey(_selectedCategory)
                  ? '$_selectedCategory · ${formatCurrency(processedData[_selectedCategory]!)} · ${(processedData[_selectedCategory]! / total * 100).toStringAsFixed(1)}%'
                  : 'Tap a slice or category to explore',
              style: AppTextStyles.metadata(),
            ),
          ),
          const SizedBox(height: 16),
          // Legend: one row per category with icon, color, name, amount, percentage.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < processedData.length; i++)
                _LegendItem(
                  onTap: () => setState(
                    () => _selectedCategory = processedData.keys.elementAt(i),
                  ),
                  selected:
                      _selectedCategory == processedData.keys.elementAt(i),
                  category: processedData.keys.elementAt(i),
                  amount: processedData.values.elementAt(i),
                  total: total,
                  color: _paletteColors[i % _paletteColors.length],
                  categoryIcons: categoryIcons,
                  isIncome: isIncome,
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
    required this.categoryIcons,
    required this.isIncome,
    this.hasOther = false,
    required this.onTap,
    required this.selected,
  });

  final String category;
  final double amount;
  final double total;
  final Color color;
  final Map<String, String> categoryIcons;
  final bool isIncome;
  final bool hasOther;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    final percentageStr = '${percentage.toStringAsFixed(1)}%';

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: selected ? AppColors.sageTint : null,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // Icon (only for known categories, not "Other").
              if (!hasOther)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.asset(
                    categoryIconAsset(
                      categoryIconKeyFor(category, customIcons: categoryIcons),
                      isIncome: isIncome,
                    ),
                    width: 16,
                    height: 16,
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
                  style: AppTextStyles.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Amount.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    formatCurrency(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.dmMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              // Percentage.
              Text(percentageStr, style: AppTextStyles.metadata()),
            ],
          ),
        ),
      ),
    );
  }
}
