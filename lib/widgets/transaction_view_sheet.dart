import 'package:flutter/material.dart';
import 'buttons.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'transaction_form_sheet.dart';

/// Read-only detail sheet opened when tapping a transaction. Editing is a
/// deliberate second step from here, not the default tap action — see
/// STYLE_GUIDE.md § Transaction modal.
Future<void> showTransactionViewSheet(
  BuildContext context, {
  required AppState appState,
  required LedgerTransaction transaction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionViewSheet(appState: appState, transaction: transaction),
  );
}

class TransactionViewSheet extends StatelessWidget {
  const TransactionViewSheet({super.key, required this.appState, required this.transaction});

  final AppState appState;
  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.darkGreen : AppColors.clay;

    return Container(
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
          const SizedBox(height: 20),
          Row(
            children: [
              IconTile(
                icon: iconForCategory(transaction.category),
                background: isIncome ? AppColors.sageTint : AppColors.clay.withValues(alpha: 0.14),
                foreground: amountColor,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: AppTextStyles.cardHeading(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.category} · ${formatDate(transaction.date)}',
                      style: AppTextStyles.metadata(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              formatSignedCurrency(transaction.amount, isIncome: isIncome),
              style: AppTextStyles.amount(color: amountColor, fontSize: 32),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              showTransactionFormSheet(context, appState: appState, existing: transaction);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit transaction'),
          ),
        ],
      ),
    );
  }
}
