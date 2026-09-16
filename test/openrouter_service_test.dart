import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:arkad_mobile/models/profile.dart';
import 'package:arkad_mobile/services/openrouter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stripAndParseArkadBlocks', () {
    test('parses a JSON array with 2+ transaction objects and strips the block', () {
      const content = '''
Got it, logged both of those for you.

```arkad_transaction
[
  {"merchant": "Chipotle", "category": "Dining", "amount": 12, "type": "expense"},
  {"merchant": "Shell", "category": "Transport", "amount": 40, "type": "expense"}
]
```
''';

      final (displayText, refIds, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, hasLength(2));
      expect(transactions[0]['merchant'], 'Chipotle');
      expect(transactions[0]['amount'], 12);
      expect(transactions[1]['merchant'], 'Shell');
      expect(transactions[1]['amount'], 40);
      expect(refIds, isEmpty);
      expect(displayText, isNot(contains('arkad_transaction')));
      expect(displayText, contains('Got it, logged both of those for you.'));
    });

    test('backward-compat: a bare single JSON object parses to a 1-element list', () {
      const content = '''
Logged it.

```arkad_transaction
{"merchant": "Chipotle", "category": "Dining", "amount": 12, "type": "expense"}
```
''';

      final (displayText, refIds, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, hasLength(1));
      expect(transactions.single['merchant'], 'Chipotle');
      expect(refIds, isEmpty);
      expect(displayText, isNot(contains('arkad_transaction')));
    });

    test('malformed JSON in the transaction block degrades to an empty list without throwing', () {
      const content = '''
Logged it.

```arkad_transaction
{not valid json at all,,,
```
''';

      expect(() => stripAndParseArkadBlocks(content), returnsNormally);

      final (displayText, refIds, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, isEmpty);
      expect(refIds, isEmpty);
      // The block is still stripped from the display text even though it
      // couldn't be parsed.
      expect(displayText, isNot(contains('arkad_transaction')));
    });

    test('a malformed entry within an otherwise-valid array is skipped, not the whole batch', () {
      const content = '''
```arkad_transaction
[
  {"merchant": "Chipotle", "category": "Dining", "amount": 12, "type": "expense"},
  "not a transaction object",
  {"merchant": "Shell", "category": "Transport", "amount": 40, "type": "expense"}
]
```
''';

      final (_, _, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, hasLength(2));
      expect(transactions[0]['merchant'], 'Chipotle');
      expect(transactions[1]['merchant'], 'Shell');
    });

    test('an arkad_refs block in the same message still parses correctly, unaffected', () {
      const content = '''
Here's what you spent on dining recently.

```arkad_transaction
[{"merchant": "Chipotle", "category": "Dining", "amount": 12, "type": "expense"}]
```

```arkad_refs
[101, 104, 110]
```
''';

      final (displayText, refIds, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, hasLength(1));
      expect(refIds, [101, 104, 110]);
      expect(displayText, isNot(contains('arkad_refs')));
      expect(displayText, isNot(contains('arkad_transaction')));
    });

    test('an arkad_refs block with no transaction block still parses correctly', () {
      const content = '''
You spent \$52 across those two purchases.

```arkad_refs
[201, 202]
```
''';

      final (displayText, refIds, transactions) = stripAndParseArkadBlocks(content);

      expect(transactions, isEmpty);
      expect(refIds, [201, 202]);
      expect(displayText, isNot(contains('arkad_refs')));
    });
  });

  group('OpenRouterService completion retries', () {
    Future<String> analyzeWith(OpenRouterService service) {
      return service.analyzeCostCutting(
        apiKey: 'valid-key',
        modelSlug: 'openrouter/free',
        profile: Profile(),
        range: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 7)),
        expenseByCategory: const {'Dining': 42},
      );
    }

    http.Response completion(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
          },
        ],
      }),
      200,
    );

    test('retries empty choices and returns the next valid completion', () async {
      var calls = 0;
      final delays = <Duration>[];
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('{"choices": []}', 200) : completion('Try a weekly dining cap.');
        }),
        delay: (duration) async => delays.add(duration),
      );

      expect(await analyzeWith(service), 'Try a weekly dining cap.');
      expect(calls, 2);
      expect(delays, [const Duration(milliseconds: 400)]);
    });

    test('retries blank message content', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? completion('  ') : completion('Reduce discretionary spending.');
        }),
        delay: (_) async {},
      );

      expect(await analyzeWith(service), 'Reduce discretionary spending.');
      expect(calls, 2);
    });

    test('retries a content-safety classification response', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? completion('User Safety: safe') : completion('Set a weekly dining budget.');
        }),
        delay: (_) async {},
      );

      expect(await analyzeWith(service), 'Set a weekly dining budget.');
      expect(calls, 2);
    });

    test('retries a content-safety classification with categories', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? completion('User Safety: unsafe\nSafety Categories: Violence and Criminal Activities')
              : completion('Review the largest expense category first.');
        }),
        delay: (_) async {},
      );

      expect(await analyzeWith(service), 'Review the largest expense category first.');
      expect(calls, 2);
    });

    test('retries rate limits and server failures', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return switch (calls) {
            1 => http.Response('{"error":{"message":"Too many requests"}}', 429),
            2 => http.Response('{"error":{"message":"Provider unavailable"}}', 503),
            _ => completion('Recovered response'),
          };
        }),
        delay: (_) async {},
      );

      expect(await analyzeWith(service), 'Recovered response');
      expect(calls, 3);
    });

    test('retries a network failure', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) {
            throw http.ClientException('Connection reset');
          }
          return completion('Recovered response');
        }),
        delay: (_) async {},
      );

      expect(await analyzeWith(service), 'Recovered response');
      expect(calls, 2);
    });

    test('reports an empty response after exhausting retries', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"choices": []}', 200);
        }),
        delay: (_) async {},
      );

      await expectLater(
        analyzeWith(service),
        throwsA(
          isA<OpenRouterException>()
              .having((error) => error.kind, 'kind', OpenRouterErrorKind.emptyResponse)
              .having((error) => error.message, 'message', 'OpenRouter returned an empty response.'),
        ),
      );
      expect(calls, 3);
    });

    test('reports an incompatible response after exhausting retries', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return completion('User Safety: unsafe\nSafety Categories: Violence and Criminal Activities');
        }),
        delay: (_) async {},
      );

      await expectLater(
        analyzeWith(service),
        throwsA(
          isA<OpenRouterException>()
              .having((error) => error.kind, 'kind', OpenRouterErrorKind.incompatibleResponse)
              .having(
                (error) => error.message,
                'message',
                'OpenRouter selected a model that returned a safety classification instead of an answer.',
              ),
        ),
      );
      expect(calls, 3);
    });

    test('does not retry an invalid API key', () async {
      var calls = 0;
      final service = OpenRouterService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":{"message":"Invalid API key"}}', 401);
        }),
        delay: (_) async {},
      );

      await expectLater(
        analyzeWith(service),
        throwsA(isA<OpenRouterException>().having((error) => error.kind, 'kind', OpenRouterErrorKind.invalidKey)),
      );
      expect(calls, 1);
    });
  });
}
