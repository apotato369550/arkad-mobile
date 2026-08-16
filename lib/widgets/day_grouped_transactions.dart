import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';
import 'transaction_row.dart';

/// Groups transactions by calendar day with pagination via "Show more" button.
/// Reveals day-groups progressively rather than fixed-size pages. Owns pagination
/// state so paging doesn't rebuild parent screens.
class DayGroupedTransactions extends StatefulWidget {
  const DayGroupedTransactions({
    super.key,
    required this.transactions,
    required this.initialDayCount,
    this.dayIncrement,
    required this.onTransactionTap,
    this.highlightId = -1,
    this.emptyLabel = 'No transactions yet.',
  });

  final List<LedgerTransaction> transactions;
  final int initialDayCount;
  final int? dayIncrement;
  final void Function(LedgerTransaction) onTransactionTap;
  final int highlightId;
  final String emptyLabel;

  @override
  State<DayGroupedTransactions> createState() => _DayGroupedTransactionsState();
}

class _DayGroupedTransactionsState extends State<DayGroupedTransactions> {
  late int _visibleDayCount;

  List<_DayGroup> _buildDayGroups(List<LedgerTransaction> transactions) {
    final groups = <DateTime, List<LedgerTransaction>>{};
    final groupOrder = <DateTime>[];

    for (final transaction in transactions) {
      final dayKey = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (!groups.containsKey(dayKey)) {
        groupOrder.add(dayKey);
        groups[dayKey] = [];
      }
      groups[dayKey]!.add(transaction);
    }

    return groupOrder
        .map((date) => _DayGroup(date: date, transactions: groups[date]!))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _visibleDayCount = widget.initialDayCount;

    // If a transaction is highlighted, ensure its day-group is visible.
    if (widget.highlightId != -1) {
      final dayGroups = _buildDayGroups(widget.transactions);
      for (int i = 0; i < dayGroups.length; i++) {
        final group = dayGroups[i];
        if (group.transactions.any((t) => t.id == widget.highlightId)) {
          // Found the day-group; ensure it's visible.
          _visibleDayCount = i + 1;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              categoryIconAsset('transactions', isIncome: true),
              width: 36,
              height: 36,
            ),
            const SizedBox(height: 10),
            Text(widget.emptyLabel, style: AppTextStyles.body()),
          ],
        ),
      );
    }

    final dayGroups = _buildDayGroups(widget.transactions);
    final increment = widget.dayIncrement ?? widget.initialDayCount;
    final visibleGroups = dayGroups.take(_visibleDayCount).toList();
    final hasMore = _visibleDayCount < dayGroups.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleGroups.map(
          (group) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                child: Text(formatDayHeader(group.date), style: AppTextStyles.metadata()),
              ),
              ...group.transactions.map(
                (transaction) => TransactionRow(
                  transaction: transaction,
                  highlighted: transaction.id == widget.highlightId,
                  onTap: () => widget.onTransactionTap(transaction),
                ),
              ),
            ],
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                _visibleDayCount =
                    (_visibleDayCount + increment).clamp(0, dayGroups.length);
              }),
              child: Text(
                'Show more transactions',
                style: AppTextStyles.body(color: AppColors.darkGreen),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayGroup {
  final DateTime date;
  final List<LedgerTransaction> transactions;

  _DayGroup({required this.date, required this.transactions});
}
