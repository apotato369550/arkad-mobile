import 'package:flutter/material.dart';
import '../models/analysis_period.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/saved_analysis_card.dart';
import 'analysis_detail_screen.dart';

class AnalysisListScreen extends StatefulWidget {
  const AnalysisListScreen({
    super.key,
    required this.appState,
    required this.period,
  });
  final AppState appState;
  final AnalysisPeriod period;

  @override
  State<AnalysisListScreen> createState() => _AnalysisListScreenState();
}

class _AnalysisListScreenState extends State<AnalysisListScreen> {
  bool _archivedOnly = false;

  @override
  void initState() {
    super.initState();
    widget.appState.pruneExpiredAnalyses(notify: false);
  }

  Future<void> _request() async {
    try {
      final id = await widget.appState.requestAnalysis(widget.period);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              AnalysisDetailScreen(appState: widget.appState, analysisId: id),
        ),
      );
    } on AnalysisRequestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.appState,
    builder: (context, _) {
      final state = widget.appState;
      final period = widget.period;
      final analyses =
          state.savedAnalyses
              .where(
                (a) => a.period == period && (!_archivedOnly || a.isArchived),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final busy = state.isRequestingAnalysis(period);
      final enoughData = state.meetsActivityThreshold(period);
      final next = state.nextAvailableAt(period);
      final enabled =
          state.hasApiKey && enoughData && state.canRequestAnalysis(period);
      final reason = busy
          ? 'Arkad is analyzing your finances…'
          : !state.hasApiKey
          ? 'Add an OpenRouter API key in Settings to generate an analysis.'
          : !enoughData
          ? 'Not enough data yet. Record transactions on at least half the days in this period.'
          : next != null
          ? 'Available again on ${formatMDY(next)}'
          : 'Create an in-depth snapshot of this period.';
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(title: Text('${period.historyLabel} Analyses')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text('Your financial story', style: AppTextStyles.pageHeading()),
            const SizedBox(height: 10),
            Text(
              period == AnalysisPeriod.sixMonths
                  ? 'A six-month view of your finances.'
                  : 'Saved snapshots and guidance, all in one place.',
              style: AppTextStyles.metadata(),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request a new analysis',
                    style: AppTextStyles.cardHeading(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reason,
                    style: AppTextStyles.body(color: AppColors.ink60),
                  ),
                  if (period == AnalysisPeriod.ytd) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${state.ytdRequestsRemaining} of 3 requests remaining this month · Resets on the 1st',
                      style: AppTextStyles.metadata(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: enabled ? _request : null,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      busy
                          ? 'Generating…'
                          : 'Request ${period.historyLabel} Analysis',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('All')),
                ButtonSegment(
                  value: true,
                  label: Text('Archived'),
                  icon: Icon(Icons.archive_outlined),
                ),
              ],
              selected: {_archivedOnly},
              onSelectionChanged: (value) =>
                  setState(() => _archivedOnly = value.single),
            ),
            const SizedBox(height: 20),
            if (analyses.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.insights_outlined,
                      size: 36,
                      color: AppColors.darkGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _archivedOnly
                          ? 'No archived analyses'
                          : 'No analyses yet',
                      style: AppTextStyles.cardHeading(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _archivedOnly
                          ? 'Archive an analysis to keep it indefinitely.'
                          : 'Your analyses will appear here when they are ready.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.ink60),
                    ),
                  ],
                ),
              ),
            for (final analysis in analyses) ...[
              SavedAnalysisCard(appState: state, analysis: analysis),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    },
  );
}
