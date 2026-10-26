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
    this.icon,
    this.iconAsset,
    required this.isIncome,
    this.onTap,
  }) : assert(
         icon != null || iconAsset != null,
         'StatCard requires either icon or iconAsset',
       );

  final String label;
  final double amount;
  final IconData? icon;
  final String? iconAsset;
  final bool isIncome;

  /// When non-null, the whole card becomes tappable (e.g. to open a detail
  /// sheet).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = isIncome
        ? AppColors.sageTint
        : AppColors.clay.withValues(alpha: 0.14);
    final fg = isIncome ? AppColors.darkGreen : AppColors.clay;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: icon,
                imageAsset: iconAsset,
                background: tint,
                foreground: fg,
                size: 40,
              ),
              const Spacer(),
              if (onTap != null)
                IconButton(
                  tooltip: 'About $label',
                  onPressed: onTap,
                  icon: Icon(
                    Icons.info_outline,
                    size: 19,
                    color: AppColors.ink60,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCurrency(amount),
              style: AppTextStyles.amount(fontSize: 20),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
