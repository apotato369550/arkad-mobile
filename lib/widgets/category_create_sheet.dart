import 'package:flutter/material.dart';
import 'category_icon_picker.dart';
import '../models/category.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Modal for creating a new category — name plus an icon chosen from
/// [showCategoryIconPickerSheet]. Opened from the single "Create new
/// category" action in [CategoryManager]. See STYLE_GUIDE.md § Category
/// management.
Future<void> showCreateCategorySheet(
  BuildContext context, {
  required AppState appState,
  required bool isIncome,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CategoryCreateSheet(appState: appState, isIncome: isIncome),
  );
}

class CategoryCreateSheet extends StatefulWidget {
  const CategoryCreateSheet({super.key, required this.appState, required this.isIncome});

  final AppState appState;
  final bool isIncome;

  @override
  State<CategoryCreateSheet> createState() => _CategoryCreateSheetState();
}

class _CategoryCreateSheetState extends State<CategoryCreateSheet> {
  final _controller = TextEditingController();
  String _iconKey = categoryIconFallbackKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final key = await showCategoryIconPickerSheet(context, isIncome: widget.isIncome, selected: _iconKey);
    if (key != null) setState(() => _iconKey = key);
  }

  void _create() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    widget.appState.addCategory(isIncome: widget.isIncome, name: name, iconKey: _iconKey);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isIncome ? AppColors.darkGreen : AppColors.clay;
    final tint = widget.isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.ink10, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New category', style: AppTextStyles.cardHeading()),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(
                    widget.isIncome ? 'Income' : 'Expense',
                    style: AppTextStyles.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadii.iconTile)),
                      child: Image.asset(categoryIconAsset(_iconKey, isIncome: widget.isIncome)),
                    ),
                    const SizedBox(height: 8),
                    Text('Tap to change icon', style: AppTextStyles.metadata()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Category name'),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _create,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Create category'),
            ),
          ],
        ),
      ),
    );
  }
}
