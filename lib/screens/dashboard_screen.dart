import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/balance_blob.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/transaction_row.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.appState, required this.onTransactionTap});

  final AppState appState;
  final ValueChanged<int> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final income = appState.totalIncome;
    final expense = appState.totalExpense;
    final savingsRate = income == 0 ? 0.0 : ((income - expense) / income) * 100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        BalanceBlob(balance: appState.balance, savingsRate: savingsRate.clamp(-100, 100)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Income',
                amount: income,
                icon: Icons.arrow_downward,
                isIncome: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StatCard(
                label: 'Expenses',
                amount: expense,
                icon: Icons.arrow_upward,
                isIncome: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CashFlowChart(appState: appState),
        const SizedBox(height: 24),
        _RecentActivity(appState: appState, onTransactionTap: onTransactionTap),
      ],
    );
  }
}

/// Last 12 transactions, paginated 12-per-page. Owns its own page index so
/// paging doesn't force the whole dashboard (chart, balance blob) to rebuild.
class _RecentActivity extends StatefulWidget {
  const _RecentActivity({required this.appState, required this.onTransactionTap});

  final AppState appState;
  final ValueChanged<int> onTransactionTap;

  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  static const _pageSize = 12;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final all = widget.appState.recentTransactions;
    final pageCount = all.isEmpty ? 1 : (all.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    final pageItems = all.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: AppTextStyles.cardHeading()),
        const SizedBox(height: 12),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No transactions yet.', style: AppTextStyles.body()),
          )
        else ...[
          ...pageItems.map(
            (t) => TransactionRow(transaction: t, onTap: () => widget.onTransactionTap(t.id)),
          ),
          if (pageCount > 1) ...[
            const SizedBox(height: 8),
            _PaginationRow(
              page: page,
              pageCount: pageCount,
              onPrev: page > 0 ? () => setState(() => _page = page - 1) : null,
              onNext: page < pageCount - 1 ? () => setState(() => _page = page + 1) : null,
            ),
          ],
        ],
      ],
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({required this.page, required this.pageCount, this.onPrev, this.onNext});

  final int page;
  final int pageCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageButton(icon: Icons.chevron_left, onTap: onPrev),
        const SizedBox(width: 16),
        Text('Page ${page + 1} of $pageCount', style: AppTextStyles.metadata()),
        const SizedBox(width: 16),
        _PageButton(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.sageTint : AppColors.ink10,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: enabled ? AppColors.darkGreen : AppColors.ink40),
        ),
      ),
    );
  }
}
