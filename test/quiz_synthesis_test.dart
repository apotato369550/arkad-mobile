import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:arkad_mobile/models/spending_style_profile.dart';
import 'package:arkad_mobile/models/analysis_period.dart';
import 'package:arkad_mobile/services/openrouter_service.dart';
import 'support/analysis_fixtures.dart';

SpendingStyleProfile answers() => SpendingStyleProfile(
  planningStyle: 'I use rough categories',
  guidancePreference: 'Concise next steps',
  completedAt: DateTime(2026, 1, 10),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both syntheses round-trip; legacy reflection stays separate', () {
    final base = answers();
    final style = base.copyWith(
      assessment: 'A flexible planner.', assessmentSource: base.answersKey,
      guidance: 'Use short check-ins.', guidanceSource: base.answersKey,
      reflection: 'Legacy reflection',
    );
    final restored = SpendingStyleProfile.fromJson(jsonDecode(jsonEncode(style.toJson())) as Map<String, dynamic>);
    expect(restored.isCurrent(SpendingStyleSection.assessment), isTrue);
    expect(restored.isCurrent(SpendingStyleSection.guidance), isTrue);
    expect(restored.toPromptBlock(), contains('A flexible planner.'));
    expect(restored.toPromptBlock(), contains('Use short check-ins.'));
    expect(restored.toPromptBlock(), isNot(contains('Legacy reflection')));
    final changed = restored.copyWith(planningStyle: 'Detailed budget');
    expect(changed.toPromptBlock(), isNot(contains('A flexible planner.')));
    expect(SpendingStyleProfile.fromJson({'reflection': 'Old'}).assessment, isEmpty);
  });

  test('each section uses its own asset system prompt and answer-only user context', () async {
    final requests = <Map<String, dynamic>>[];
    final state = await testState(handler: (request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return completionResponse('A useful synthesis.');
    });
    state.updateSpendingStyle(answers());
    for (final section in SpendingStyleSection.values) {
      await state.generateSpendingStyleSection(section);
    }
    expect(requests.length, 2);
    final assessmentMessages = requests.first['messages'] as List<dynamic>;
    final guidanceMessages = requests.last['messages'] as List<dynamic>;
    expect(assessmentMessages.first['content'], contains('spending-style profile'));
    expect(guidanceMessages.first['content'], contains('concrete adaptations'));
    expect(assessmentMessages.first['role'], 'system');
    expect(assessmentMessages.last['role'], 'user');
    expect(guidanceMessages.last['content'], isNot(contains('A useful synthesis.')));
    for (final section in SpendingStyleSection.values) {
      await state.generateSpendingStyleSection(section);
    }
    expect(requests.length, 2, reason: 'Current sections must be cached.');
  });

  test('one section can fail and retry without repeating the successful section', () async {
    var calls = 0;
    final state = await testState(handler: (_) async {
      calls++;
      return calls == 2 ? http.Response('{"error":{"message":"Invalid key"}}', 401) : completionResponse();
    });
    state.updateSpendingStyle(answers());
    await state.generateSpendingStyleSection(SpendingStyleSection.assessment);
    await state.generateSpendingStyleSection(SpendingStyleSection.guidance);
    expect(state.profile.spendingStyle.isCurrent(SpendingStyleSection.assessment), isTrue);
    expect(state.spendingStyleErrors[SpendingStyleSection.guidance], isNotNull);
    await state.generateSpendingStyleSection(SpendingStyleSection.guidance);
    expect(calls, 3);
    expect(state.spendingStyleErrors, isEmpty);
  });

  test('editing answers while a request runs discards its outdated result', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final state = await testState(handler: (_) async {
      started.complete();
      await release.future;
      return completionResponse('Old assessment');
    });
    state.updateSpendingStyle(answers());
    final generating = state.generateSpendingStyleSection(SpendingStyleSection.assessment);
    await started.future;
    state.updateSpendingStyle(answers().copyWith(planningStyle: 'A new plan'));
    release.complete();
    await generating;
    expect(state.profile.spendingStyle.assessment, isEmpty);
    expect(state.profile.spendingStyle.isCurrent(SpendingStyleSection.assessment), isFalse);
  });

  test('chat and all analysis prompts include both current syntheses', () async {
    final requests = <Map<String, dynamic>>[];
    final state = await testState(handler: (request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return completionResponse();
    });
    final base = answers();
    state.updateSpendingStyle(base);
    // Simulate independently generated, persisted output.
    state.updateSpendingStyle(base.copyWith(
      assessment: 'ASSESSMENT_CONTEXT', assessmentSource: base.answersKey,
      guidance: 'GUIDANCE_CONTEXT', guidanceSource: base.answersKey,
    ));
    await state.requestAnalysis(AnalysisPeriod.sevenDays);
    final profile = state.profile;
    final service = OpenRouterService(client: MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return completionResponse();
    }));
    await service.sendMessage(
      apiKey: 'key', modelSlug: 'model', userMessage: 'Help me plan',
      history: const [], ledger: const [], incomeCategories: const [],
      expenseCategories: const [], profile: profile,
    );
    await service.analyzeFinances(
      apiKey: 'key', modelSlug: 'model', profile: profile,
      range: DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 10)),
      totalIncome: 100, totalExpense: 20, expenseByCategory: const {},
    );
    expect(requests.length, 6);
    for (final request in requests) {
      final prompt = (request['messages'] as List<dynamic>).first['content'] as String;
      expect(prompt, contains('ASSESSMENT_CONTEXT'));
      expect(prompt, contains('GUIDANCE_CONTEXT'));
    }
  });
}
