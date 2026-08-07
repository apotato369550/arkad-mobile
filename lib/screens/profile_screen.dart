import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.appState});

  final AppState appState;

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: appState.profile.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
        title: Text('Edit profile', style: AppTextStyles.cardHeading()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      appState.updateProfile(appState.profile.copyWith(displayName: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = appState.profile;
    final initials = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0].toUpperCase()).join();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: AppColors.darkGreen, borderRadius: BorderRadius.circular(28)),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppTextStyles.fraunces(fontSize: 30, fontWeight: FontWeight.w600, color: AppColors.pastelYellow),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.displayName.trim().isEmpty ? 'Add your name' : profile.displayName,
                style: AppTextStyles.pageHeading(),
              ),
              const SizedBox(height: 6),
              Text(
                profile.financialGoal.trim().isEmpty ? 'Building good money habits' : profile.financialGoal,
                style: AppTextStyles.body(color: AppColors.ink60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextButton(onPressed: () => _editName(context), child: const Text('Edit profile')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _StatMini(label: 'Lifetime income', value: appState.totalIncome, isIncome: true)),
            const SizedBox(width: 12),
            Expanded(child: _StatMini(label: 'Lifetime expenses', value: appState.totalExpense, isIncome: false)),
          ],
        ),
        const SizedBox(height: 12),
        _StatMini(label: 'Lifetime balance', value: appState.balance, isIncome: appState.balance >= 0, wide: true),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.value, required this.isIncome, this.wide = false});

  final String label;
  final double value;
  final bool isIncome;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(
            formatCurrency(value),
            style: AppTextStyles.amount(fontSize: 18, color: isIncome ? AppColors.darkGreen : AppColors.clay),
          ),
        ],
      ),
    );
  }
}
