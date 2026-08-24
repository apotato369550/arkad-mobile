import 'package:flutter/material.dart';
import 'buttons.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';

/// See STYLE_GUIDE.md § Dashboard components — transaction row.
class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.transaction, required this.categoryIcons, this.onTap, this.highlighted = false});

  final LedgerTransaction transaction;
  final Map<String, String> categoryIcons;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    return Material(
      color: highlighted ? AppColors.sageTint : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Row(
            children: [
              IconTile(
                imageAsset: categoryIconAsset(categoryIconKeyFor(transaction.category, customIcons: categoryIcons), isIncome: isIncome),
                background: isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14),
                foreground: isIncome ? AppColors.darkGreen : AppColors.clay,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: AppTextStyles.manrope(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${transaction.category} · ${formatDate(transaction.date)}',
                      style: AppTextStyles.metadata(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatSignedCurrency(transaction.amount, isIncome: isIncome),
                style: AppTextStyles.amount(color: isIncome ? AppColors.darkGreen : AppColors.clay),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
