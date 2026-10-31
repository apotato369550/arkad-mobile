import 'package:flutter/material.dart';
import '../models/analysis_period.dart';
import '../models/saved_analysis.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../screens/analysis_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// Shared presentation for the latest analysis and period history.
class SavedAnalysisCard extends StatelessWidget {
  const SavedAnalysisCard({
    super.key,
    required this.appState,
    required this.analysis,
  });
  final AppState appState;
  final SavedAnalysis analysis;

  void _view(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          AnalysisDetailScreen(appState: appState, analysisId: analysis.id),
    ),
  );

  Future<void> _archive(BuildContext context) async {
    final expired =
        analysis.isArchived &&
        (analysis.period
                .expiresAt(analysis.createdAt)
                ?.isBefore(DateTime.now()) ??
            false);
    if (expired) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unarchive expired analysis?'),
          content: const Text(
            'Its original retention period has ended. Unarchiving will delete it immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unarchive and delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    appState.setAnalysisArchived(analysis.id, !analysis.isArchived);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete analysis?'),
        content: const Text(
          'This permanently removes this analysis from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.clay),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) appState.deleteSavedAnalysis(analysis.id);
  }

  @override
  Widget build(BuildContext context) {
    final expiry = analysis.expiresAt;
    return AppCard(
      onTap: () => _view(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  analysis.period.noun,
                  style: AppTextStyles.cardHeading(),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Analysis options',
                icon: const Icon(Icons.more_horiz),
                constraints: const BoxConstraints(minWidth: 180),
                onSelected: (action) {
                  if (action == 'archive') {
                    _archive(context);
                  } else if (action == 'delete') {
                    _delete(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        analysis.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      title: Text(
                        analysis.isArchived ? 'Unarchive' : 'Archive',
                      ),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.clay,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.clay),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatMDY(analysis.rangeStart)} – ${formatMDY(analysis.rangeEnd)}',
            style: AppTextStyles.metadata(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                'Income  ${formatCurrency(analysis.totalIncome)}',
                style: AppTextStyles.dmMono(
                  fontSize: 12,
                  color: AppColors.darkGreen,
                ),
              ),
              Text(
                'Expenses  ${formatCurrency(analysis.totalExpense)}',
                style: AppTextStyles.dmMono(
                  fontSize: 12,
                  color: AppColors.clay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            analysis.overallText?.trim().isNotEmpty == true
                ? analysis.overallText!
                : 'Your financial snapshot is ready to explore.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(),
          ),
          const SizedBox(height: 14),
          Text(
            analysis.isArchived
                ? 'Archived · Kept until you delete it'
                : expiry == null
                ? 'Kept until you delete it'
                : 'Expires ${formatMDY(expiry)}',
            style: AppTextStyles.metadata(),
          ),
        ],
      ),
    );
  }
}
