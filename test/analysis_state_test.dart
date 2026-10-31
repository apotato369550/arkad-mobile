import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:arkad_mobile/models/analysis_period.dart';
import 'package:arkad_mobile/models/saved_analysis.dart';
import 'package:arkad_mobile/services/app_state.dart';
import 'support/analysis_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retention deadlines clamp month ends and preserve time', () {
    expect(
      AnalysisPeriod.oneMonth.expiresAt(DateTime(2026, 1, 31, 12)),
      DateTime(2026, 4, 30, 12),
    );
    expect(
      AnalysisPeriod.threeMonths.expiresAt(DateTime(2024, 2, 29)),
      DateTime(2025, 2, 28),
    );
    expect(
      AnalysisPeriod.sixMonths.expiresAt(DateTime(2024, 2, 29)),
      DateTime(2026, 2, 28),
    );
    expect(
      AnalysisPeriod.oneYear.expiresAt(DateTime(2024, 2, 29)),
      DateTime(2028, 2, 29),
    );
    expect(AnalysisPeriod.ytd.expiresAt(DateTime(2020)), isNull);
  });

  test('expiry includes the deadline and archives never expire', () {
    final analysis = sampleAnalysis(createdAt: DateTime(2026, 1, 1));
    expect(analysis.isExpiredAt(DateTime(2026, 1, 21, 23, 59)), isFalse);
    expect(analysis.isExpiredAt(DateTime(2026, 1, 22)), isTrue);
    expect(
      analysis.copyWith(isArchived: true).isExpiredAt(DateTime(2030)),
      isFalse,
    );
    final oldJson = analysis.toJson()..remove('isArchived');
    expect(SavedAnalysis.fromJson(oldJson).isArchived, isFalse);
    expect(
      SavedAnalysis.fromJson(
        analysis.copyWith(isArchived: true).toJson(),
      ).isArchived,
      isTrue,
    );
  });

  test(
    'startup and explicit pruning retain archives and YTD, newest first',
    () async {
      final persistence = await testPersistence();
      await persistence.saveSavedAnalyses([
        sampleAnalysis(id: 'expired', createdAt: DateTime(2025)),
        sampleAnalysis(
          id: 'archive',
          createdAt: DateTime(2025),
          archived: true,
        ),
        sampleAnalysis(
          id: 'ytd',
          period: AnalysisPeriod.ytd,
          createdAt: DateTime(2024),
        ),
        sampleAnalysis(id: 'latest', createdAt: DateTime(2026, 1, 9)),
      ]);
      var now = DateTime(2026, 1, 10);
      final state = AppState(persistence, now: () => now);
      expect(state.savedAnalyses.map((a) => a.id), [
        'latest',
        'archive',
        'ytd',
      ]);
      now = DateTime(2026, 2, 1);
      state.pruneExpiredAnalyses();
      expect(persistence.loadSavedAnalyses().map((a) => a.id), [
        'archive',
        'ytd',
      ]);
      state.setAnalysisArchived('archive', false);
      expect(state.findAnalysis('archive'), isNull);
    },
  );

  test(
    'YTD quota survives deletion and restart and resets each calendar month',
    () async {
      var now = DateTime(2026, 1, 10);
      final state = await testState(now: () => now);
      for (var i = 0; i < 3; i++) {
        final id = await state.requestAnalysis(AnalysisPeriod.ytd);
        state.deleteSavedAnalysis(id);
      }
      expect(state.ytdRequestsRemaining, 0);
      expect(state.nextAvailableAt(AnalysisPeriod.ytd), DateTime(2026, 2, 1));
      await expectLater(
        state.requestAnalysis(AnalysisPeriod.ytd),
        throwsA(isA<AnalysisRequestException>()),
      );
      // Reload using the same underlying preference store.
      final persistence = await createExistingPersistence();
      final reloaded = AppState(persistence, now: () => now);
      expect(reloaded.ytdRequestsRemaining, 0);
      now = DateTime(2026, 2, 1);
      expect(reloaded.ytdRequestsRemaining, 3);
    },
  );

  test(
    'fully failed requests do not consume quota; partial success does',
    () async {
      var failuresOnly = true;
      var calls = 0;
      final state = await testState(
        handler: (_) async {
          calls++;
          return failuresOnly || calls % 4 == 1
              ? http.Response('{"error":{"message":"Invalid key"}}', 401)
              : completionResponse();
        },
      );
      await expectLater(
        state.requestAnalysis(AnalysisPeriod.ytd),
        throwsA(isA<AnalysisRequestException>()),
      );
      expect(state.ytdRequestsRemaining, 3);
      failuresOnly = false;
      await state.requestAnalysis(AnalysisPeriod.ytd);
      expect(state.ytdRequestsRemaining, 2);
      expect(
        state.savedAnalyses.single.goalProgressStatus,
        AnalysisAnswerStatus.error,
      );
    },
  );

  test('overlapping requests cannot bypass period quota or cooldown', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final state = await testState(
      handler: (_) async {
        if (!started.isCompleted) started.complete();
        await release.future;
        return completionResponse();
      },
    );
    final first = state.requestAnalysis(AnalysisPeriod.ytd);
    await started.future;
    expect(state.isRequestingAnalysis(AnalysisPeriod.ytd), isTrue);
    await expectLater(
      state.requestAnalysis(AnalysisPeriod.ytd),
      throwsA(isA<AnalysisRequestException>()),
    );
    release.complete();
    await first;
    expect(state.ytdRequestsRemaining, 2);
    expect(state.isRequestingAnalysis(AnalysisPeriod.ytd), isFalse);
  });

  test('automatic analyses exclude YTD and retain weekly cooldown', () async {
    final state = await testState();
    await state.runAutomaticAnalysisChecks();
    expect(state.savedAnalyses.map((a) => a.period), [
      AnalysisPeriod.sevenDays,
    ]);
    expect(state.ytdRequestsRemaining, 3);
    expect(state.canRequestAnalysis(AnalysisPeriod.sevenDays), isFalse);
  });

  test(
    'backup usage merges by maximum and old snapshots still restore',
    () async {
      final persistence = await testPersistence();
      await persistence.saveYtdUsage({'2026-01': 3});
      final snapshot = await persistence.buildBackupSnapshot();
      snapshot['ytdUsage'] = {'2026-01': 1, '2026-02': 2};
      await persistence.restoreBackupSnapshot(snapshot);
      expect(persistence.loadYtdUsage(), {'2026-01': 3, '2026-02': 2});
      snapshot.remove('ytdUsage');
      await persistence.restoreBackupSnapshot(snapshot);
      expect(persistence.loadYtdUsage()['2026-01'], 3);
    },
  );

  test(
    'legacy YTD records seed usage before expired analyses are pruned',
    () async {
      final persistence = await testPersistence();
      await persistence.saveSavedAnalyses([
        sampleAnalysis(id: 'one', period: AnalysisPeriod.ytd),
        sampleAnalysis(id: 'two', period: AnalysisPeriod.ytd),
      ]);
      await persistence.saveAnalysisRequestLog({
        AnalysisPeriod.ytd: DateTime(2026, 1, 10),
      });
      final state = AppState(persistence, now: () => DateTime(2026, 1, 10));
      expect(state.ytdRequestsRemaining, 1);
    },
  );
}
