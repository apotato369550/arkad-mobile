import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:arkad_mobile/models/chat_message.dart';
import 'package:arkad_mobile/models/profile.dart';
import 'package:arkad_mobile/models/spending_style_profile.dart';
import 'package:arkad_mobile/services/openrouter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profile retains spending-style answers through JSON', () {
    final profile = Profile(
      spendingStyle: SpendingStyleProfile(
        incomeRhythm: 'Somewhat variable',
        flexibleCategories: const ['Entertainment'],
        contextNote: 'Keep family obligations in mind.',
        completedAt: DateTime(2026, 9, 16),
        reflection: 'A saved reflection.',
        reflectionCurrent: true,
      ),
    );

    final restored = Profile.fromJson(
      jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
    );

    expect(restored.spendingStyle.isComplete, isTrue);
    expect(restored.spendingStyle.flexibleCategories, ['Entertainment']);
    expect(restored.spendingStyle.reflectionCurrent, isTrue);
  });

  test('old profiles load with an unanswered spending-style quiz', () {
    final profile = Profile.fromJson(const {'displayName': 'Ari'});
    expect(profile.spendingStyle.isComplete, isFalse);
    expect(profile.spendingStyle.toPromptBlock(), isEmpty);
  });

  test(
    'chat prompt includes completed preferences as self-reported context',
    () async {
      late Map<String, dynamic> request;
      final service = OpenRouterService(
        client: MockClient((http.Request raw) async {
          request = jsonDecode(raw.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Hello'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final profile = Profile(
        spendingStyle: SpendingStyleProfile(
          planningStyle: 'I use rough categories',
          completedAt: DateTime(2026, 9, 16),
        ),
      );

      await service.sendMessage(
        apiKey: 'key',
        modelSlug: 'model',
        userMessage: 'How am I doing?',
        history: const <ChatMessage>[],
        ledger: const [],
        incomeCategories: const [],
        expenseCategories: const [],
        profile: profile,
      );

      final messages = request['messages'] as List<dynamic>;
      final prompt =
          (messages.first as Map<String, dynamic>)['content'] as String;
      expect(
        prompt,
        contains('Self-reported spending preferences (not ledger facts):'),
      );
      expect(prompt, contains('Planning style: I use rough categories'));
    },
  );
}
