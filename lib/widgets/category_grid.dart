import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Income/expense segmented toggle. Shared by [TransactionFormSheet] and
/// the proposed-transactions review sheet — see STYLE_GUIDE.md § Transaction
/// modal.
class TypeToggle extends StatelessWidget {
  const TypeToggle({super.key, required this.type, required this.onChanged});
  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          Expanded(child: _segment(context, 'Expense', TransactionType.expense)),
          Expanded(child: _segment(context, 'Income', TransactionType.income)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, TransactionType value) {
    final selected = type == value;
    final isIncome = value == TransactionType.income;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? (isIncome ? AppColors.darkGreen : AppColors.clay) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.manrope(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}

/// Single category tile in the category-selection grid. Shared by
/// [TransactionFormSheet] and the proposed-transactions review sheet.
class CategoryGridTile extends StatelessWidget {
  const CategoryGridTile({
    super.key,
    required this.label,
    required this.iconKey,
    required this.isIncome,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconKey;
  final bool isIncome;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.darkGreen : AppColors.clay;
    final tint = isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.18) : tint,
              borderRadius: BorderRadius.circular(AppRadii.iconTile),
              border: selected ? Border.all(color: color, width: 2) : null,
            ),
            child: Image.asset(categoryIconAsset(iconKey, isIncome: isIncome)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.ink60,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable grid of [CategoryGridTile]s for the given [categories]. Shared
/// convenience wrapper so callers don't have to repeat the
/// `GridView.builder` boilerplate.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.isIncome,
    required this.customIcons,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final bool isIncome;
  final Map<String, String> customIcons;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        final iconKey = categoryIconKeyFor(c, customIcons: customIcons);
        return CategoryGridTile(
          label: c,
          iconKey: iconKey,
          isIncome: isIncome,
          selected: c == selected,
          onTap: () => onSelected(c),
        );
      },
    );
  }
}
