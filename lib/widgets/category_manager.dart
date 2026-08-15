import 'package:flutter/material.dart';
import 'app_card.dart';
import 'category_create_sheet.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Lightweight category CRUD, not an administrative settings page.
/// See STYLE_GUIDE.md § Category management.
class CategoryManager extends StatefulWidget {
  const CategoryManager({super.key, required this.appState});

  final AppState appState;

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  TransactionType _type = TransactionType.expense;

  bool get _isIncome => _type == TransactionType.income;

  Future<void> _confirmDelete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
        title: Text('Delete category?', style: AppTextStyles.cardHeading()),
        content: Text(
          'This removes "$name" from your category list. Existing transactions keep this label.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppTextStyles.manrope(color: AppColors.clay, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.appState.deleteCategory(isIncome: _isIncome, name: name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome ? widget.appState.incomeCategories : widget.appState.expenseCategories;
    final color = _isIncome ? AppColors.darkGreen : AppColors.clay;
    final tint = _isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categories', style: AppTextStyles.cardHeading()),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Row(
              children: [
                Expanded(child: _segment('Expense', TransactionType.expense)),
                Expanded(child: _segment('Income', TransactionType.income)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
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
              final name = categories[i];
              final iconKey = categoryIconKeyFor(name, customIcons: widget.appState.categoryIcons);
              return _CategoryGridTile(
                name: name,
                iconKey: iconKey,
                isIncome: _isIncome,
                color: color,
                tint: tint,
                onDelete: () => _confirmDelete(name),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showCreateCategorySheet(context, appState: widget.appState, isIncome: _isIncome),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create new category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, TransactionType value) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkGreen : Colors.transparent,
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

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    required this.name,
    required this.iconKey,
    required this.isIncome,
    required this.color,
    required this.tint,
    required this.onDelete,
  });

  final String name;
  final String iconKey;
  final bool isIncome;
  final Color color;
  final Color tint;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadii.iconTile)),
              child: Image.asset(categoryIconAsset(iconKey, isIncome: isIncome)),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        Positioned(
          top: -6,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: AppColors.paper, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.close, size: 13, color: AppColors.ink60),
            ),
          ),
        ),
      ],
    );
  }
}
