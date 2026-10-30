import 'package:flutter_test/flutter_test.dart';
import 'package:arkad_mobile/models/analysis_period.dart';
import 'package:arkad_mobile/models/transaction.dart';
import 'package:arkad_mobile/services/demo_transactions.dart';
import 'support/analysis_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final now in [
    DateTime(2026, 10, 30, 12),
    DateTime(2026, 1, 1),
    DateTime(2024, 2, 29),
    DateTime(2026, 3, 31),
  ]) {
    test('demo ledger supports all analysis periods at $now', () async {
      final state = await testState(now: () => now);
      addTearDown(state.dispose);
      state.transactions = generateDemoTransactions(now: now);
      for (final period in AnalysisPeriod.values) {
        expect(
          state.meetsActivityThreshold(period),
          isTrue,
          reason: period.name,
        );
        final range = period.rangeFor(now);
        final entries = state.transactions.where(
          (t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end),
        );
        expect(entries.any((t) => t.type == TransactionType.expense), isTrue);
      }
    });
  }

  test('demo ledger is reproducible, valid, varied and spans two years', () {
    final now = DateTime(2026, 10, 30, 12);
    final entries = generateDemoTransactions(now: now);
    expect(
      entries.map((t) => t.toJson()).toList(),
      generateDemoTransactions(now: now).map((t) => t.toJson()).toList(),
    );
    expect(entries.map((t) => t.id).toSet().length, entries.length);
    expect(entries.every((t) => t.amount > 0 && t.amount.isFinite), isTrue);
    expect(entries.every((t) => !t.date.isAfter(now)), isTrue);
    expect(entries.last.date, DateTime(2024, 11, 1));
    expect(entries.map((t) => t.category).toSet().length, greaterThan(10));
    expect(entries.where((t) => t.category == 'Bonus').length, 2);
    expect(
      entries.any((t) => t.merchant == 'Emergency appliance replacement'),
      isTrue,
    );
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].date.isAfter(entries[i - 1].date), isFalse);
    }
  });
}
