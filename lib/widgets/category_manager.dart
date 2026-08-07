import 'package:flutter/material.dart';
import 'app_card.dart';
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
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.appState.addCategory(isIncome: _type == TransactionType.income, name: name);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == TransactionType.income
        ? widget.appState.incomeCategories
        : widget.appState.expenseCategories;

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.sageTint, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(c, style: AppTextStyles.manrope(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'New category name'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Icon(Icons.add, size: 20),
              ),
            ],
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
