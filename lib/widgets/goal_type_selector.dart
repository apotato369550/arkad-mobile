import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Pill-button list for [Profile.goalType]. Deliberately styled unlike an
/// input/dropdown trigger (no border, fully rounded, filled) so it reads as
/// a set of buttons. Tapping "Other" opens a modal for [otherController]
/// instead of expanding inline, so this step never grows past one screen.
class GoalTypeSelector extends StatelessWidget {
  const GoalTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.otherController,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final TextEditingController otherController;

  Future<void> _openOtherModal(BuildContext context) async {
    final controller = TextEditingController(text: otherController.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What do you plan to achieve?', style: AppTextStyles.cardHeading()),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Tell us what you\'re aiming for'),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(controller.text.trim()),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      otherController.text = result;
      onChanged('Other');
    }
  }

  String _label(String option) {
    if (option == 'Other' && otherController.text.trim().isNotEmpty) {
      return otherController.text.trim();
    }
    return option;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in goalOptions) ...[
          _button(context, option),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _button(BuildContext context, String option) {
    final isSelected = option == selected;
    return GestureDetector(
      onTap: () => option == 'Other' ? _openOtherModal(context) : onChanged(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : AppColors.sageTint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          _label(option),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.manrope(
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
