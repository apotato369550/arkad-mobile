import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/saved_analysis.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'analysis_detail_screen.dart';

/// List of past saved analyses, mirroring ConversationListScreen's layout.
/// Unlike conversations, new analyses are only created via the "Request
/// Analysis" flow on AnalysisScreen, so there's no "new" action here.
class AnalysisListScreen extends StatelessWidget {
  const AnalysisListScreen({super.key, required this.appState});

  final AppState appState;

  void _confirmDeleteAnalysis(BuildContext context, SavedAnalysis analysis) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.modal)),
        title: Text('Delete analysis?', style: AppTextStyles.cardHeading()),
        content: Text(
          'This permanently deletes "${analysis.title}" from this device.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTextStyles.manrope()),
          ),
          TextButton(
            onPressed: () {
              appState.deleteSavedAnalysis(analysis.id);
              Navigator.of(context).pop();
            },
            child: Text(
              'Delete',
              style: AppTextStyles.manrope(color: AppColors.clay, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  bool _isGenerating(SavedAnalysis analysis) {
    return analysis.goalProgressStatus == AnalysisAnswerStatus.loading ||
        analysis.costCuttingStatus == AnalysisAnswerStatus.loading ||
        analysis.overallStatus == AnalysisAnswerStatus.loading ||
        analysis.actionableStepsStatus == AnalysisAnswerStatus.loading;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final analyses = appState.savedAnalyses;

        return Scaffold(
          backgroundColor: AppColors.cream,
          appBar: AppBar(title: const Text('Past Analyses')),
          body: analyses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          categoryIconAsset('analysis', isIncome: true),
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No analyses yet',
                          style: AppTextStyles.cardHeading(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Request an analysis from the Analysis page to see it here.',
                          style: AppTextStyles.body(color: AppColors.ink60),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: analyses.length,
                  itemBuilder: (context, i) {
                    final analysis = analyses[i];
                    final generating = _isGenerating(analysis);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AnalysisDetailScreen(
                                  appState: appState,
                                  analysisId: analysis.id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              analysis.title,
                                              style: AppTextStyles.manrope(
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (generating) ...[
                                            const SizedBox(width: 8),
                                            const _GeneratingChip(),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${formatCurrency(analysis.totalIncome)} in · '
                                        '${formatCurrency(analysis.totalExpense)} out',
                                        style: AppTextStyles.metadata(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatDayHeader(analysis.createdAt),
                                        style: AppTextStyles.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.ink60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _confirmDeleteAnalysis(context, analysis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _GeneratingChip extends StatelessWidget {
  const _GeneratingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'Generating…',
        style: AppTextStyles.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.darkGreen,
        ),
      ),
    );
  }
}
