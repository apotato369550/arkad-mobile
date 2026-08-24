import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'category_pie_chart.dart';

/// Opens a plain-language explanation of a stat tile. Shared by every
/// info-icon affordance on the Analysis screens (see [StatCard], and the
/// tiles below) so the modal styling only needs to be defined once. Mirrors
/// the dialog style used by [AnalysisListScreen]'s delete confirmation.
void showStatInfoDialog(BuildContext context, {required String title, required String explanation}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
      title: Text(title, style: AppTextStyles.cardHeading()),
      content: Text(explanation, style: AppTextStyles.body()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Got it', style: AppTextStyles.manrope(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Opens a bottom sheet with a period's Income/Expenses breakdown by
/// category, in addition to the plain-language explanation. Backing tap
/// target for [StatCard] when the caller supplies category data — richer
/// than [showStatInfoDialog] since it shows the actual numbers behind the
/// total, not just what the term means.
Future<void> showStatDetailSheet(
  BuildContext context, {
  required String title,
  required double amount,
  required bool isIncome,
  required String periodCaption,
  required String explanation,
  required Map<String, double> breakdown,
  required String breakdownEmptyLabel,
  required Map<String, String> categoryIcons,
}) {
  final amountColor = isIncome ? AppColors.darkGreen : AppColors.clay;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: AppTextStyles.cardHeading()),
              const SizedBox(height: 4),
              Text(periodCaption, style: AppTextStyles.metadata()),
              const SizedBox(height: 12),
              Text(
                formatCurrency(amount),
                style: AppTextStyles.amount(fontSize: 28, color: amountColor),
              ),
              const SizedBox(height: 12),
              Text(explanation, style: AppTextStyles.body()),
              const SizedBox(height: 24),
              CategoryPieChart(
                title: '$title by category',
                data: breakdown,
                categoryIcons: categoryIcons,
                isIncome: isIncome,
                emptyLabel: breakdownEmptyLabel,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text('Got it', style: AppTextStyles.manrope(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Stat tile for net income/expense (no income/expense tint). Tapping opens
/// [showStatInfoDialog].
class NetStatTile extends StatelessWidget {
  const NetStatTile({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => showStatInfoDialog(
        context,
        title: 'Net',
        explanation: "What's left after subtracting what you spent from what you earned. "
            'A positive number means you kept money this period; a negative number means '
            'you spent more than you brought in.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            amount >= 0 ? Icons.check_circle_outline : Icons.warning_outlined,
            size: 40,
            color: amount >= 0 ? AppColors.darkGreen : AppColors.clay,
          ),
          const SizedBox(height: 16),
          Text('Net', style: AppTextStyles.metadata()),
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

/// Stat tile for average daily expense. Tapping opens [showStatInfoDialog].
class AverageStatTile extends StatelessWidget {
  const AverageStatTile({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => showStatInfoDialog(
        context,
        title: 'Daily average',
        explanation: 'Your typical spending per day, found by spreading your total expenses '
            'evenly across every day in this period.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: AppColors.sage,
          ),
          const SizedBox(height: 16),
          Text('Daily avg', style: AppTextStyles.metadata()),
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

/// Stat tile for expense delta vs previous period. Tapping opens
/// [showStatInfoDialog].
class DeltaStatTile extends StatelessWidget {
  const DeltaStatTile({super.key, required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final percent = (delta.abs() * 100).toStringAsFixed(0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      onTap: () => showStatInfoDialog(
        context,
        title: 'vs. prior',
        explanation: 'How your spending this period compares to the same-length period right '
            'before it. An up arrow means you spent more than before; a down arrow means you '
            'spent less.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            categoryIconAsset('trend', isIncome: !isUp),
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 16),
          Text('vs. prior', style: AppTextStyles.metadata()),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${isUp ? '▲' : '▼'} $percent%',
              style: AppTextStyles.amount(
                fontSize: 20,
                color: isUp ? AppColors.clay : AppColors.darkGreen,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
