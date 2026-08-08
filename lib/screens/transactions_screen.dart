import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/day_grouped_transactions.dart';
import '../widgets/transaction_form_sheet.dart';
import 'transaction_search_screen.dart';

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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search transactions',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TransactionSearchScreen(appState: appState)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showTransactionFormSheet(context, appState: appState),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          DayGroupedTransactions(
            transactions: transactions,
            initialDayCount: 5,
            highlightId: highlightId,
            emptyLabel: 'No transactions yet. Add one to get started.',
            onTransactionTap: (t) => showTransactionFormSheet(context, appState: appState, existing: t),
          ),
        ],
      ),
    );
  }
}
