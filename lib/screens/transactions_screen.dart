import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/category_manager.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/transaction_row.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.appState, this.highlightId = -1});

  final AppState appState;
  final int highlightId;

  @override
  Widget build(BuildContext context) {
    final transactions = appState.recentTransactions;
    return ColoredBox(
      color: AppColors.cream,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transactions', style: AppTextStyles.pageHeading()),
              ElevatedButton.icon(
                onPressed: () => showTransactionFormSheet(context, appState: appState),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No transactions yet. Add one to get started.', style: AppTextStyles.body()),
            )
          else
            ...transactions.map(
              (t) => TransactionRow(
                transaction: t,
                highlighted: t.id == highlightId,
                onTap: () => showTransactionFormSheet(context, appState: appState, existing: t),
              ),
            ),
          const SizedBox(height: 28),
          CategoryManager(appState: appState),
        ],
      ),
    );
  }
}
