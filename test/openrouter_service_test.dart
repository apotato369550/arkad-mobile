import 'package:flutter_test/flutter_test.dart';

import 'package:arkad_mobile/services/openrouter_service.dart';

void main() {
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
}
