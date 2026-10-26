import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/personal_basics_card.dart';
import 'spending_style_quiz_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final profile = appState.profile;
    final initials = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((s) => s[0].toUpperCase())
              .join();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.darkGreen,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppTextStyles.fraunces(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pastelYellow,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.displayName.trim().isEmpty
                    ? 'Add your name'
                    : profile.displayName,
                style: AppTextStyles.pageHeading(),
              ),
              const SizedBox(height: 6),
              Text(
                profile.goalSummary.trim().isEmpty
                    ? 'Building good money habits'
                    : profile.goalSummary,
                style: AppTextStyles.body(color: AppColors.ink60),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PersonalBasicsCard(appState: appState),
        const SizedBox(height: 20),
        if (profile.spendingStyle.isComplete) ...[
          SpendingStyleSummary(style: profile.spendingStyle),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpendingStyleQuizScreen(appState: appState, showResultInitially: profile.spendingStyle.isComplete),
                ),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('View results'),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpendingStyleQuizScreen(appState: appState, showResultInitially: profile.spendingStyle.isComplete),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Answer spending-style quiz'),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: _StatMini(
                label: 'Lifetime income',
                value: appState.totalIncome,
                isIncome: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatMini(
                label: 'Lifetime expenses',
                value: appState.totalExpense,
                isIncome: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatMini(
          label: 'Lifetime balance',
          value: appState.balance,
          isIncome: appState.balance >= 0,
          wide: true,
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    required this.isIncome,
    this.wide = false,
  });

  final String label;
  final double value;
  final bool isIncome;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(
            formatCurrency(value),
            style: AppTextStyles.amount(
              fontSize: 18,
              color: isIncome ? AppColors.darkGreen : AppColors.clay,
            ),
          ),
        ],
      ),
    );
  }
}
