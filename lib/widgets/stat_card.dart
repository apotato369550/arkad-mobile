import 'package:flutter/material.dart';
import 'app_card.dart';
import 'buttons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';

/// See STYLE_GUIDE.md § Dashboard components — stat cards.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.isIncome,
  });

  final String label;
  final double amount;
  final IconData icon;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final tint = isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14);
    final fg = isIncome ? AppColors.darkGreen : AppColors.clay;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, background: tint, foreground: fg, size: 40),
          const SizedBox(height: 16),
          Text(label, style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          Text(formatCurrency(amount), style: AppTextStyles.amount(fontSize: 20)),
        ],
      ),
    );
  }
}
