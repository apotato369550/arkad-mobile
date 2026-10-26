import 'package:flutter/material.dart' show DateTimeRange;

/// Selectable lookback windows for a requested Arkad analysis (see
/// AppState.requestAnalysis). Each period also gates how often it can be
/// re-requested — see [AnalysisPeriodX.nextAvailableAt].
enum AnalysisPeriod {
  sevenDays,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  ytd,
}

extension AnalysisPeriodX on AnalysisPeriod {
  String get label => switch (this) {
    AnalysisPeriod.sevenDays => '7 days',
    AnalysisPeriod.oneMonth => '1 month',
    AnalysisPeriod.threeMonths => '3 months',
    AnalysisPeriod.sixMonths => '6 months',
    AnalysisPeriod.oneYear => '1 year',
    AnalysisPeriod.ytd => 'YTD',
  };

  String get noun => switch (this) {
    AnalysisPeriod.sevenDays => 'Weekly Analysis',
    AnalysisPeriod.oneMonth => 'Monthly Analysis',
    AnalysisPeriod.threeMonths => 'Quarterly Analysis',
    AnalysisPeriod.sixMonths => 'Biyearly Analysis',
    AnalysisPeriod.oneYear => 'Yearly Analysis',
    AnalysisPeriod.ytd => 'Year-to-Date Analysis',
  };

  String get historyLabel => switch (this) {
    AnalysisPeriod.sevenDays => 'Weekly',
    AnalysisPeriod.oneMonth => 'Monthly',
    AnalysisPeriod.threeMonths => 'Quarterly',
    AnalysisPeriod.sixMonths => 'Biyearly',
    AnalysisPeriod.oneYear => 'Yearly',
    AnalysisPeriod.ytd => 'YTD',
  };

  DateTime? expiresAt(DateTime createdAt) => switch (this) {
    AnalysisPeriod.sevenDays => createdAt.add(const Duration(days: 21)),
    AnalysisPeriod.oneMonth => addCalendarMonths(createdAt, 3),
    AnalysisPeriod.threeMonths => addCalendarMonths(createdAt, 12),
    AnalysisPeriod.sixMonths => addCalendarMonths(createdAt, 24),
    AnalysisPeriod.oneYear => addCalendarMonths(createdAt, 48),
    AnalysisPeriod.ytd => null,
  };

  /// The resolved [DateTimeRange] for this period ending at [now]. Month/year
  /// spans use calendar arithmetic (`DateTime(y, m - n, d)`) so a "1 month"
  /// period is a true calendar month back, not a fixed 30-day window.
  DateTimeRange rangeFor(DateTime now) {
    final DateTime start = switch (this) {
      // Today + 6 prior calendar days = 7 days total once AppState's
      // inclusive day-bounds normalization is applied — matches
      // CashFlowRange.sevenDays elsewhere in the app (see
      // AppState._bucketedByDays). `now.subtract(Duration(days: 7))` would
      // normalize to an 8-day inclusive span instead.
      AnalysisPeriod.sevenDays => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      AnalysisPeriod.oneMonth => DateTime(now.year, now.month - 1, now.day),
      AnalysisPeriod.threeMonths => DateTime(now.year, now.month - 3, now.day),
      AnalysisPeriod.sixMonths => DateTime(now.year, now.month - 6, now.day),
      AnalysisPeriod.oneYear => DateTime(now.year - 1, now.month, now.day),
      AnalysisPeriod.ytd => DateTime(now.year, 1, 1),
    };
    return DateTimeRange(start: start, end: now);
  }

  /// The next moment this period may be requested again after having been
  /// requested at [lastRequested]. Uses the same calendar arithmetic as
  /// [rangeFor] — months/years aren't fixed-length, so this isn't a fixed
  /// [Duration]. YTD re-uses the monthly cadence (checking back in sooner
  /// than a full year makes more sense for a rolling year-to-date view).
  DateTime nextAvailableAt(DateTime lastRequested) {
    return switch (this) {
      AnalysisPeriod.sevenDays => lastRequested.add(const Duration(days: 7)),
      AnalysisPeriod.oneMonth => DateTime(
        lastRequested.year,
        lastRequested.month + 1,
        lastRequested.day,
      ),
      AnalysisPeriod.threeMonths => DateTime(
        lastRequested.year,
        lastRequested.month + 3,
        lastRequested.day,
      ),
      AnalysisPeriod.sixMonths => DateTime(
        lastRequested.year,
        lastRequested.month + 6,
        lastRequested.day,
      ),
      AnalysisPeriod.oneYear => DateTime(
        lastRequested.year + 1,
        lastRequested.month,
        lastRequested.day,
      ),
      AnalysisPeriod.ytd => DateTime(
        lastRequested.year,
        lastRequested.month + 1,
        lastRequested.day,
      ),
    };
  }
}

/// Calendar arithmetic that clamps Jan 31 + one month to the last day of February.
DateTime addCalendarMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
    first.year,
    first.month,
    date.day.clamp(1, lastDay),
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
