import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../widgets/balance_blob.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/day_grouped_transactions.dart';
import '../widgets/stat_card.dart';
import '../widgets/transaction_form_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.appState, required this.onTransactionTap});

  final AppState appState;
  final ValueChanged<int> onTransactionTap;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StatsRange _range = StatsRange.month;

  @override
  Widget build(BuildContext context) {
    final totals = widget.appState.totalsForRange(_range);
    final income = totals.$1;
    final expense = totals.$2;
    final savingsRate = income == 0 ? 0.0 : ((income - expense) / income) * 100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.sageTint, shape: BoxShape.circle),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: Image.asset('assets/extracted/arkad_face_transparent.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _greeting(widget.appState.profile.displayName),
                      style: AppTextStyles.fraunces(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Here's how things are looking.", style: AppTextStyles.body(color: AppColors.ink60)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.sageTint,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: DropdownButton<StatsRange>(
                underline: const SizedBox(),
                icon: const Icon(Icons.expand_more, size: 18),
                style: AppTextStyles.manrope(fontWeight: FontWeight.w600),
                value: _range,
                items: StatsRange.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.caption)))
                    .toList(),
                onChanged: (r) => setState(() => _range = r!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BalanceBlob(balance: income - expense, savingsRate: savingsRate.clamp(-100, 100)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Income',
                amount: income,
                iconAsset: categoryIconAsset('income', isIncome: true),
                isIncome: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StatCard(
                label: 'Expenses',
                amount: expense,
                iconAsset: categoryIconAsset('bills_up', isIncome: false),
                isIncome: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CashFlowChart(appState: widget.appState),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showTransactionFormSheet(context, appState: widget.appState),
            icon: const Icon(Icons.add),
            label: const Text('Add transaction'),
          ),
        ),
        const SizedBox(height: 24),
        _RecentActivity(appState: widget.appState, onTransactionTap: widget.onTransactionTap),
      ],
    );
  }
}

/// Recent activity: shows transactions grouped by day. Delegates reveal state to DayGroupedTransactions.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.appState, required this.onTransactionTap});

  final AppState appState;
  final ValueChanged<int> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: AppTextStyles.cardHeading()),
        const SizedBox(height: 12),
        DayGroupedTransactions(
          transactions: appState.recentTransactions,
          categoryIcons: appState.categoryIcons,
          initialDayCount: 3,
          onTransactionTap: (t) => onTransactionTap(t.id),
        ),
      ],
    );
  }
}

String _greeting(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return 'Welcome back';
  final firstName = trimmed.split(RegExp(r'\s+')).first;
  return 'Welcome back, $firstName';
}
