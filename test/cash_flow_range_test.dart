import 'package:flutter_test/flutter_test.dart';
import 'package:arkad_mobile/services/app_state.dart';
import 'support/analysis_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chart ranges have seven daily, weekly, or monthly buckets', () async {
    final state = await testState(now: () => DateTime(2026, 10, 30, 12));
    final starts = {
      CashFlowRange.sevenDays: DateTime(2026, 10, 24),
      CashFlowRange.sevenWeeks: DateTime(2026, 9, 12),
      CashFlowRange.sevenMonths: DateTime(2026, 4, 1),
    };
    expect(CashFlowRange.values.map((r) => r.shortLabel), ['7D', '7W', '7M']);
    for (final range in CashFlowRange.values) {
      final buckets = state.cashFlow(range);
      expect(buckets, hasLength(7));
      expect(buckets.first.$1, starts[range]);
      expect(state.dateTimeRangeForCashFlow(range).start, starts[range]);
    }
    final weeks = state.cashFlow(CashFlowRange.sevenWeeks);
    expect(weeks.last.$1, DateTime(2026, 10, 24));
    expect(weeks[1].$1.difference(weeks[0].$1), const Duration(days: 7));
    expect(
      state.cashFlow(CashFlowRange.sevenMonths).last.$1,
      DateTime(2026, 10),
    );
  });
}
