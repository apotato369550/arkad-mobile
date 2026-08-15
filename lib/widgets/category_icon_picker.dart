import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Grid picker for a category's icon, opened from the "new category" row
/// in [CategoryManager]. Icons are pre-tinted to the active type's color
/// (see [categoryIconAsset]) so the picker previews exactly what the
/// category will look like. Returns the chosen icon key, or null if
/// dismissed without a selection.
Future<String?> showCategoryIconPickerSheet(
  BuildContext context, {
  required bool isIncome,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryIconPickerSheet(isIncome: isIncome, selected: selected),
  );
}

class _CategoryIconPickerSheet extends StatelessWidget {
  const _CategoryIconPickerSheet({required this.isIncome, required this.selected});

  final bool isIncome;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.darkGreen : AppColors.clay;
    final tint = isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      child: SafeArea(
        top: false,
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
            Text('Choose an icon', style: AppTextStyles.cardHeading()),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: categoryIconKeys.length,
                itemBuilder: (context, i) {
                  final key = categoryIconKeys[i];
                  final isSelected = key == selected;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(key),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.18) : tint,
                        borderRadius: BorderRadius.circular(AppRadii.iconTile),
                        border: isSelected ? Border.all(color: color, width: 2) : null,
                      ),
                      child: Image.asset(categoryIconAsset(key, isIncome: isIncome)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
