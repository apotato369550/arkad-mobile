import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/transaction_view_sheet.dart';
import '../widgets/week_paged_transactions.dart';
import 'transaction_search_screen.dart';

enum _TransactionFilter { all, income, expense }

extension on _TransactionFilter {
  String get label => switch (this) {
        _TransactionFilter.all => 'All',
        _TransactionFilter.income => 'Income',
        _TransactionFilter.expense => 'Expenses',
      };

  bool matches(LedgerTransaction t) => switch (this) {
        _TransactionFilter.all => true,
        _TransactionFilter.income => t.type == TransactionType.income,
        _TransactionFilter.expense => t.type == TransactionType.expense,
      };
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.appState, this.highlightId = -1});

  final AppState appState;
  final int highlightId;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _TransactionFilter _filter = _TransactionFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.appState.recentTransactions.where(_filter.matches).toList();
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
                      MaterialPageRoute(builder: (_) => TransactionSearchScreen(appState: widget.appState)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showTransactionFormSheet(context, appState: widget.appState),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TransactionFilterSelector(selected: _filter, onChanged: (f) => setState(() => _filter = f)),
          const SizedBox(height: 20),
          WeekPagedTransactions(
            key: ValueKey(_filter),
            transactions: transactions,
            categoryIcons: widget.appState.categoryIcons,
            highlightId: widget.highlightId,
            emptyLabel: switch (_filter) {
              _TransactionFilter.all => 'No transactions yet. Add one to get started.',
              _TransactionFilter.income => 'No income transactions yet.',
              _TransactionFilter.expense => 'No expense transactions yet.',
            },
            onTransactionTap: (t) => showTransactionViewSheet(context, appState: widget.appState, transaction: t),
          ),
        ],
      ),
    );
  }
}

/// Segmented All/Income/Expenses filter, mirrors the range selector on the
/// Analysis screen (see [AnalysisScreen]'s `_RangeSelector`).
class _TransactionFilterSelector extends StatelessWidget {
  const _TransactionFilterSelector({required this.selected, required this.onChanged});

  final _TransactionFilter selected;
  final ValueChanged<_TransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        children: [
          for (final filter in _TransactionFilter.values) Expanded(child: _segment(filter)),
        ],
      ),
    );
  }

  Widget _segment(_TransactionFilter filter) {
    final isSelected = filter == selected;
    return GestureDetector(
      onTap: () => onChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          filter.label,
          style: AppTextStyles.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.paper : AppColors.ink60,
          ),
        ),
      ),
    );
  }
}
