import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';
import 'transaction_row.dart';

/// Groups transactions into rolling 7-day windows (this week, the week
/// before, ...), each broken down by calendar day. Pagination reveals one
/// more week at a time via "Show more". Owns pagination state so paging
/// doesn't rebuild the parent screen.
///
/// Pass a new [Key] (e.g. keyed on the active filter) when the transaction
/// list changes for a reason other than new data — e.g. a type filter
/// switching — so paging resets to the first week instead of carrying over
/// however many weeks were previously expanded.
class WeekPagedTransactions extends StatefulWidget {
  const WeekPagedTransactions({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
    this.highlightId = -1,
    this.emptyLabel = 'No transactions yet.',
  });

  final List<LedgerTransaction> transactions;
  final void Function(LedgerTransaction) onTransactionTap;
  final int highlightId;
  final String emptyLabel;

  @override
  State<WeekPagedTransactions> createState() => _WeekPagedTransactionsState();
}

class _WeekPagedTransactionsState extends State<WeekPagedTransactions> {
  static const int _weekLength = 7;

  late int _visibleWeekCount;

  List<_WeekGroup> _buildWeekGroups(List<LedgerTransaction> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final byWeek = <int, List<LedgerTransaction>>{};
    for (final transaction in transactions) {
      final day = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      final daysAgo = today.difference(day).inDays;
      final weekIndex = daysAgo < 0 ? 0 : daysAgo ~/ _weekLength;
      byWeek.putIfAbsent(weekIndex, () => []).add(transaction);
    }

    final weekIndices = byWeek.keys.toList()..sort();
    return weekIndices.map((weekIndex) {
      final end = today.subtract(Duration(days: weekIndex * _weekLength));
      final start = end.subtract(const Duration(days: _weekLength - 1));
      return _WeekGroup(start: start, end: end, transactions: byWeek[weekIndex]!);
    }).toList();
  }

  List<_DayGroup> _buildDayGroups(List<LedgerTransaction> transactions) {
    final groups = <DateTime, List<LedgerTransaction>>{};
    final groupOrder = <DateTime>[];

    for (final transaction in transactions) {
      final dayKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      if (!groups.containsKey(dayKey)) {
        groupOrder.add(dayKey);
        groups[dayKey] = [];
      }
      groups[dayKey]!.add(transaction);
    }

    return groupOrder.map((date) => _DayGroup(date: date, transactions: groups[date]!)).toList();
  }

  @override
  void initState() {
    super.initState();
    _visibleWeekCount = 1;

    // If a transaction is highlighted, ensure its week is visible.
    if (widget.highlightId != -1) {
      final weekGroups = _buildWeekGroups(widget.transactions);
      for (int i = 0; i < weekGroups.length; i++) {
        if (weekGroups[i].transactions.any((t) => t.id == widget.highlightId)) {
          _visibleWeekCount = i + 1;
          break;
        }
      }
    }
  }

  String _labelForWeek(int index, _WeekGroup group) {
    if (index == 0) return 'This week';
    if (index == 1) return 'Last week';
    return '${formatMonthDay(group.start)} – ${formatMonthDay(group.end)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(widget.emptyLabel, style: AppTextStyles.body()),
      );
    }

    final weekGroups = _buildWeekGroups(widget.transactions);
    final visibleGroups = weekGroups.take(_visibleWeekCount).toList();
    final hasMore = _visibleWeekCount < weekGroups.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < visibleGroups.length; i++) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(10, i == 0 ? 0 : 20, 10, 4),
            child: Text(
              _labelForWeek(i, visibleGroups[i]),
              style: AppTextStyles.manrope(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          for (final dayGroup in _buildDayGroups(visibleGroups[i].transactions)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Text(formatDayHeader(dayGroup.date), style: AppTextStyles.metadata()),
            ),
            for (final transaction in dayGroup.transactions)
              TransactionRow(
                transaction: transaction,
                highlighted: transaction.id == widget.highlightId,
                onTap: () => widget.onTransactionTap(transaction),
              ),
          ],
        ],
        if (hasMore) ...[
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                _visibleWeekCount = (_visibleWeekCount + 1).clamp(0, weekGroups.length);
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

class _WeekGroup {
  final DateTime start;
  final DateTime end;
  final List<LedgerTransaction> transactions;

  _WeekGroup({required this.start, required this.end, required this.transactions});
}

class _DayGroup {
  final DateTime date;
  final List<LedgerTransaction> transactions;

  _DayGroup({required this.date, required this.transactions});
}
