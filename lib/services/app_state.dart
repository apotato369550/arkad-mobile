import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart';
import '../models/analysis_period.dart';
import '../models/api_config.dart';
import '../models/category.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/profile.dart';
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'app_config.dart';
import 'formatters.dart';
import 'openrouter_service.dart';
import 'persistence_service.dart';

/// Thrown by [AppState.requestAnalysis] when a request is rejected before
/// any network call is made (cooldown not elapsed, or not enough recorded
/// activity in the period).
class AnalysisRequestException implements Exception {
  AnalysisRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Outcome of one of [AppState]'s four one-shot OpenRouter Q&A calls —
/// [status] is [AnalysisAnswerStatus.loaded] with [text] set on success, or
/// [AnalysisAnswerStatus.error] with [error] set on failure. Never
/// `AnalysisAnswerStatus.loading` — by the time a result exists, the call has
/// resolved one way or the other.
typedef _AnswerResult = ({String? text, AnalysisAnswerStatus status, String? error});

enum CashFlowRange { sevenDays, sixMonths, twelveMonths }

extension CashFlowRangeLabel on CashFlowRange {
  String get shortLabel => switch (this) {
        CashFlowRange.sevenDays => '7D',
        CashFlowRange.sixMonths => '6M',
        CashFlowRange.twelveMonths => '12M',
      };

  String get caption => switch (this) {
        CashFlowRange.sevenDays => 'Last 7 days',
        CashFlowRange.sixMonths => 'Last 6 months',
        CashFlowRange.twelveMonths => 'Last 12 months',
      };
}

enum StatsRange { day, week, month, year }

extension StatsRangeLabel on StatsRange {
  String get shortLabel => switch (this) {
        StatsRange.day => '1D',
        StatsRange.week => '1W',
        StatsRange.month => '1M',
        StatsRange.year => '1Y',
      };

  String get caption => switch (this) {
        StatsRange.day => 'Today',
        StatsRange.week => 'This week',
        StatsRange.month => 'This month',
        StatsRange.year => 'This year',
      };
}

/// Single source of truth for the app, created once at the root and handed
/// down to screens (mirrors the web app's single view-state + prop-drilling —
/// see IDEA.md § Stack). No provider/riverpod: callers listen via a single
/// ListenableBuilder at the shell root.
class AppState extends ChangeNotifier {
  AppState(this._persistence)
      : transactions = _persistence.loadTransactions(),
        profile = _persistence.loadProfile(),
        incomeCategories = _persistence.loadIncomeCategories(),
        expenseCategories = _persistence.loadExpenseCategories(),
        categoryIcons = _persistence.loadCategoryIcons(),
        apiConfig = _persistence.loadApiConfig(),
        conversations = _persistence.loadConversations(),
        activeConversationId = _determineActiveConversationId(_persistence.loadConversations()),
        savedAnalyses = _persistence.loadSavedAnalyses(),
        _analysisRequestLog = _persistence.loadAnalysisRequestLog() {
    setAppCurrency(profile.currencyCode);
  }

  final PersistenceService _persistence;
  final OpenRouterService _openRouter = OpenRouterService();

  List<LedgerTransaction> transactions;
  Profile profile;
  List<String> incomeCategories;
  List<String> expenseCategories;
  /// Icon keys for custom categories, by name — see [categoryIconKeyFor].
  Map<String, String> categoryIcons;
  ApiConfig apiConfig;
  List<Conversation> conversations;
  String? activeConversationId;
  List<SavedAnalysis> savedAnalyses;
  Map<AnalysisPeriod, DateTime> _analysisRequestLog;

  /// The OpenRouter key all calls should use: a debug-mode `.env` key takes
  /// priority (so development doesn't require configuring Settings), falling
  /// back to the user's own BYOK key.
  String get effectiveApiKey {
    if (AppConfig.isDebugMode && AppConfig.debugApiKey != null) {
      return AppConfig.debugApiKey!;
    }
    return apiConfig.apiKey ?? '';
  }

  /// Whether a call can be made right now — debug key in debug mode,
  /// otherwise the user's own BYOK key. The one place UI should check
  /// key-availability instead of reading [ApiConfig.hasKey] directly, which
  /// only reflects the user-entered key and knows nothing about debug mode.
  bool get hasApiKey => effectiveApiKey.trim().isNotEmpty;

  static String? _determineActiveConversationId(List<Conversation> conversations) {
    if (conversations.isEmpty) return null;
    Conversation? mostRecent;
    for (final c in conversations) {
      if (mostRecent == null) {
        mostRecent = c;
      } else {
        final mostRecentTimestamp = mostRecent.messages.isNotEmpty
            ? mostRecent.messages.last.timestamp
            : mostRecent.createdAt;
        final currentTimestamp = c.messages.isNotEmpty ? c.messages.last.timestamp : c.createdAt;
        if (currentTimestamp.isAfter(mostRecentTimestamp)) {
          mostRecent = c;
        }
      }
    }
    return mostRecent?.id;
  }

  List<ChatMessage> get activeMessages {
    if (activeConversationId == null) return [];
    for (final c in conversations) {
      if (c.id == activeConversationId) {
        return c.messages;
      }
    }
    return [];
  }

  double get totalIncome => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  List<LedgerTransaction> get recentTransactions {
    final sorted = List<LedgerTransaction>.of(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  (double income, double expense) totalsForRange(StatsRange range) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final DateTime periodStart = switch (range) {
      StatsRange.day => todayStart,
      StatsRange.week => todayStart.subtract(Duration(days: todayStart.weekday - 1)),
      StatsRange.month => DateTime(now.year, now.month, 1),
      StatsRange.year => DateTime(now.year, 1, 1),
    };
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.date.isBefore(periodStart)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income, expense);
  }

  /// Income/expense totals bucketed for the given [range], oldest first.
  /// Day/week buckets are fixed-size; month buckets follow calendar months
  /// so each one reflects a true month regardless of length.
  List<(DateTime bucketStart, double income, double expense)> cashFlow(CashFlowRange range) {
    switch (range) {
      case CashFlowRange.sevenDays:
        return _bucketedByDays(rangeStart: _cashFlowStart(range), bucketSizeDays: 1, count: 7);
      case CashFlowRange.sixMonths:
        return _monthlyBuckets(start: _cashFlowStart(range), count: 6);
      case CashFlowRange.twelveMonths:
        return _monthlyBuckets(start: _cashFlowStart(range), count: 12);
    }
  }

  /// The start bound each [CashFlowRange] resolves to as of now — the single
  /// source of truth shared by [cashFlow]'s bucketing and
  /// [dateTimeRangeForCashFlow].
  DateTime _cashFlowStart(CashFlowRange range) {
    final now = DateTime.now();
    switch (range) {
      case CashFlowRange.sevenDays:
        final todayStart = DateTime(now.year, now.month, now.day);
        return todayStart.subtract(const Duration(days: 6));
      case CashFlowRange.sixMonths:
        return DateTime(now.year, now.month - 5, 1);
      case CashFlowRange.twelveMonths:
        return DateTime(now.year, now.month - 11, 1);
    }
  }

  /// The [DateTimeRange] a given [CashFlowRange] resolves to (e.g. for the
  /// Analysis screen's pie chart) — same bounds [cashFlow] buckets over.
  DateTimeRange dateTimeRangeForCashFlow(CashFlowRange range) {
    return DateTimeRange(start: _cashFlowStart(range), end: DateTime.now());
  }

  List<(DateTime, double, double)> _bucketedByDays({
    required DateTime rangeStart,
    required int bucketSizeDays,
    required int count,
  }) {
    final income = List<double>.filled(count, 0.0);
    final expense = List<double>.filled(count, 0.0);
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day.isBefore(rangeStart)) continue;
      final idx = day.difference(rangeStart).inDays ~/ bucketSizeDays;
      if (idx < 0 || idx >= count) continue;
      if (t.type == TransactionType.income) {
        income[idx] += t.amount;
      } else {
        expense[idx] += t.amount;
      }
    }
    return [
      for (var i = 0; i < count; i++)
        (rangeStart.add(Duration(days: bucketSizeDays * i)), income[i], expense[i]),
    ];
  }

  List<(DateTime, double, double)> _monthlyBuckets({required DateTime start, required int count}) {
    final months = List.generate(count, (i) => DateTime(start.year, start.month + i, 1));
    final income = List<double>.filled(count, 0.0);
    final expense = List<double>.filled(count, 0.0);
    for (final t in transactions) {
      final idx = months.indexWhere((m) => m.year == t.date.year && m.month == t.date.month);
      if (idx == -1) continue;
      if (t.type == TransactionType.income) {
        income[idx] += t.amount;
      } else {
        expense[idx] += t.amount;
      }
    }
    return [for (var i = 0; i < count; i++) (months[i], income[i], expense[i])];
  }

  /// Normalizes an arbitrary [range] to whole-calendar-day bounds: the start
  /// of [range.start]'s day (inclusive) through the start of the day AFTER
  /// [range.end]'s day (exclusive), so any transaction dated on range.end's
  /// calendar day is included.
  (DateTime start, DateTime endExclusive) _normalizedBounds(DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);
    final endExclusive = endDay.add(const Duration(days: 1));
    return (start, endExclusive);
  }

  /// Income/expense totals for an arbitrary [range], inclusive of both
  /// endpoint calendar days.
  (double income, double expense) totalsForDateRange(DateTimeRange range) {
    final (start, endExclusive) = _normalizedBounds(range);
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income, expense);
  }

  /// Expense-only total per category within [range]. Categories with zero
  /// expense in the range are omitted from the result map.
  Map<String, double> expenseByCategory(DateTimeRange range) {
    final (start, endExclusive) = _normalizedBounds(range);
    final totals = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) continue;
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }

  /// Income-only total per category within [range]. Categories with zero
  /// income in the range are omitted from the result map.
  Map<String, double> incomeByCategory(DateTimeRange range) {
    final (start, endExclusive) = _normalizedBounds(range);
    final totals = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.income) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) continue;
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }

  /// Transactions dated within [range] (inclusive of both endpoint
  /// calendar days), oldest first — see [ExportDataCard].
  List<LedgerTransaction> transactionsInRange(DateTimeRange range) {
    final (start, endExclusive) = _normalizedBounds(range);
    return transactions.where((t) => !t.date.isBefore(start) && t.date.isBefore(endExclusive)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Saved analyses requested within [range] (inclusive of both endpoint
  /// calendar days) — see [ExportDataCard].
  List<SavedAnalysis> savedAnalysesInRange(DateTimeRange range) {
    final (start, endExclusive) = _normalizedBounds(range);
    return savedAnalyses.where((a) => !a.createdAt.isBefore(start) && a.createdAt.isBefore(endExclusive)).toList();
  }

  /// Bucketed income/expense series across [range], oldest first. Bucket
  /// granularity auto-selects for readability: daily for spans <= 31 days,
  /// weekly (7-day buckets anchored at range.start) for spans <= 180 days,
  /// calendar-monthly beyond that.
  List<(DateTime bucketStart, double income, double expense)> cashFlowForRange(
    DateTimeRange range,
  ) {
    final (start, endExclusive) = _normalizedBounds(range);
    final spanDays = endExclusive.difference(start).inDays;
    if (spanDays <= 31) {
      return _dailyBucketsForRange(start, endExclusive);
    } else if (spanDays <= 180) {
      return _weeklyBucketsForRange(start, endExclusive);
    } else {
      return _monthlyBucketsForRange(start, endExclusive);
    }
  }

  List<(DateTime, double, double)> _dailyBucketsForRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    final count = endExclusive.difference(start).inDays;
    final income = List<double>.filled(count, 0.0);
    final expense = List<double>.filled(count, 0.0);
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;
      final idx = day.difference(start).inDays;
      if (idx < 0 || idx >= count) continue;
      if (t.type == TransactionType.income) {
        income[idx] += t.amount;
      } else {
        expense[idx] += t.amount;
      }
    }
    return [
      for (var i = 0; i < count; i++) (start.add(Duration(days: i)), income[i], expense[i]),
    ];
  }

  List<(DateTime, double, double)> _weeklyBucketsForRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    final totalDays = endExclusive.difference(start).inDays;
    final count = (totalDays / 7).ceil();
    final income = List<double>.filled(count, 0.0);
    final expense = List<double>.filled(count, 0.0);
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;
      final idx = day.difference(start).inDays ~/ 7;
      if (idx < 0 || idx >= count) continue;
      if (t.type == TransactionType.income) {
        income[idx] += t.amount;
      } else {
        expense[idx] += t.amount;
      }
    }
    return [
      for (var i = 0; i < count; i++) (start.add(Duration(days: 7 * i)), income[i], expense[i]),
    ];
  }

  List<(DateTime, double, double)> _monthlyBucketsForRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    final lastInclusiveDay = endExclusive.subtract(const Duration(days: 1));
    final count =
        (lastInclusiveDay.year - start.year) * 12 + (lastInclusiveDay.month - start.month) + 1;
    final months = List.generate(count, (i) => DateTime(start.year, start.month + i, 1));
    final income = List<double>.filled(count, 0.0);
    final expense = List<double>.filled(count, 0.0);
    for (final t in transactions) {
      if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) continue;
      final idx = months.indexWhere((m) => m.year == t.date.year && m.month == t.date.month);
      if (idx == -1) continue;
      if (t.type == TransactionType.income) {
        income[idx] += t.amount;
      } else {
        expense[idx] += t.amount;
      }
    }
    return [for (var i = 0; i < count; i++) (months[i], income[i], expense[i])];
  }

  void addTransaction(LedgerTransaction transaction) {
    transactions = [transaction, ...transactions];
    _persistence.saveTransactions(transactions);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void updateTransaction(LedgerTransaction transaction) {
    transactions = [
      for (final t in transactions)
        if (t.id == transaction.id) transaction else t,
    ];
    _persistence.saveTransactions(transactions);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void deleteTransaction(int id) {
    transactions = transactions.where((t) => t.id != id).toList();
    _persistence.saveTransactions(transactions);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void updateProfile(Profile profile) {
    this.profile = profile;
    setAppCurrency(profile.currencyCode);
    _persistence.saveProfile(profile);
    notifyListeners();
  }

  void addCategory({required bool isIncome, required String name, required String iconKey}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (isIncome) {
      if (incomeCategories.contains(trimmed)) return;
      incomeCategories = [...incomeCategories, trimmed];
      _persistence.saveIncomeCategories(incomeCategories);
    } else {
      if (expenseCategories.contains(trimmed)) return;
      expenseCategories = [...expenseCategories, trimmed];
      _persistence.saveExpenseCategories(expenseCategories);
    }
    categoryIcons = {...categoryIcons, trimmed: iconKey};
    _persistence.saveCategoryIcons(categoryIcons);
    notifyListeners();
  }

  void deleteCategory({required bool isIncome, required String name}) {
    if (isIncome) {
      incomeCategories = incomeCategories.where((c) => c != name).toList();
      _persistence.saveIncomeCategories(incomeCategories);
    } else {
      expenseCategories = expenseCategories.where((c) => c != name).toList();
      _persistence.saveExpenseCategories(expenseCategories);
    }
    if (categoryIcons.containsKey(name)) {
      categoryIcons = {...categoryIcons}..remove(name);
      _persistence.saveCategoryIcons(categoryIcons);
    }
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void updateApiConfig(ApiConfig config) {
    apiConfig = config;
    _persistence.saveApiConfig(config);
    notifyListeners();
  }

  void addChatMessage(ChatMessage message) {
    // Lazily create a new conversation if none is active.
    if (activeConversationId == null) {
      // Derive title from message content (first ~40 chars).
      String deriveTitle(String content) {
        final trimmed = content.trim();
        if (trimmed.length <= 40) {
          return trimmed;
        }
        return '${trimmed.substring(0, 40)}…';
      }

      final newConversation = Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: deriveTitle(message.content),
        createdAt: DateTime.now(),
        messages: [message],
      );
      conversations = [newConversation, ...conversations];
      activeConversationId = newConversation.id;
    } else {
      // Append message to active conversation.
      conversations = [
        for (final c in conversations)
          if (c.id == activeConversationId)
            c.copyWith(messages: [...c.messages, message])
          else
            c,
      ];
    }
    _persistence.saveConversations(conversations);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void startNewConversation() {
    activeConversationId = null;
    notifyListeners();
  }

  void openConversation(String id) {
    activeConversationId = id;
    notifyListeners();
  }

  void deleteConversation(String id) {
    conversations = conversations.where((c) => c.id != id).toList();
    if (activeConversationId == id) {
      activeConversationId = null;
    }
    _persistence.saveConversations(conversations);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Whether [period] can be requested right now — either it's never been
  /// requested, or its calendar-arithmetic cooldown (see
  /// [AnalysisPeriodX.nextAvailableAt]) has elapsed.
  bool canRequestAnalysis(AnalysisPeriod period) {
    final last = _analysisRequestLog[period];
    if (last == null) return true;
    return !DateTime.now().isBefore(period.nextAvailableAt(last));
  }

  /// The next moment [period] becomes requestable again, or null if it's
  /// never been requested or is already available now.
  DateTime? nextAvailableAt(AnalysisPeriod period) {
    final last = _analysisRequestLog[period];
    if (last == null) return null;
    final next = period.nextAvailableAt(last);
    return DateTime.now().isBefore(next) ? next : null;
  }

  /// Whether at least half the calendar days in [period]'s current range
  /// (rounded up) have at least one transaction — the bar for a request to
  /// produce a meaningful analysis rather than mostly empty commentary.
  bool meetsActivityThreshold(AnalysisPeriod period) {
    final range = period.rangeFor(DateTime.now());
    final (start, endExclusive) = _normalizedBounds(range);
    final totalDays = endExclusive.difference(start).inDays;
    final activeDays = <DateTime>{};
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;
      activeDays.add(day);
    }
    return activeDays.length >= (totalDays / 2).ceil();
  }

  /// The equal-length range immediately preceding [range] — same pattern
  /// already used ad hoc by AnalysisScreen's `_DeltaTile` (prior-period
  /// expense delta), centralized here as the one source of truth for the
  /// AI-context computation in [requestAnalysis]. UI screens keep their own
  /// local copies for now; this isn't a general-purpose refactor.
  DateTimeRange _precedingRange(DateTimeRange range) {
    final spanDays = range.end.difference(range.start).inDays + 1;
    return DateTimeRange(
      start: range.start.subtract(Duration(days: spanDays)),
      end: range.start.subtract(const Duration(days: 1)),
    );
  }

  bool _autoAnalysisChecked = false;

  /// Silently requests an analysis for any [AnalysisPeriod] whose cooldown has
  /// elapsed and that has enough recorded activity — the automatic
  /// counterpart to the user-triggered "Request analysis" flow. Reuses the
  /// exact same [canRequestAnalysis]/[meetsActivityThreshold] gates as a
  /// manual request, so automatic and manual requests can never double up or
  /// bypass the cooldown. Call once per app session.
  Future<void> runAutomaticAnalysisChecks() async {
    if (_autoAnalysisChecked || !hasApiKey) return;
    _autoAnalysisChecked = true;
    for (final period in AnalysisPeriod.values) {
      if (!canRequestAnalysis(period) || !meetsActivityThreshold(period)) continue;
      try {
        await requestAnalysis(period);
      } catch (_) {
        // Best-effort background check — failures are only surfaced for
        // user-initiated requests.
      }
    }
  }

  /// Requests a new [SavedAnalysis] for [period]: validates the cooldown and
  /// activity threshold, snapshots the current numbers, derives the richer
  /// context (savings rate, prior-period comparison, top expense category,
  /// income-vs-typical, and the last same-period-type analysis for
  /// continuity), then awaits all four independent OpenRouter Q&A calls
  /// before doing anything else. Only once every call has resolved (success
  /// or failure) is the analysis saved and the cooldown consumed — if all
  /// four fail, nothing is saved and [AnalysisRequestException] is thrown so
  /// the request can be retried without waiting out a cooldown it never
  /// used. Returns the new analysis's id.
  Future<String> requestAnalysis(AnalysisPeriod period) async {
    if (!hasApiKey) {
      throw AnalysisRequestException(
        'Add an OpenRouter API key in Settings before requesting an analysis.',
      );
    }
    if (!canRequestAnalysis(period)) {
      final next = nextAvailableAt(period)!;
      throw AnalysisRequestException(
        'You can request another ${period.label} analysis on ${formatMDY(next)}.',
      );
    }
    if (!meetsActivityThreshold(period)) {
      throw AnalysisRequestException(
        'Not enough recorded activity in this period yet — add a few more transactions first.',
      );
    }

    final now = DateTime.now();
    final range = period.rangeFor(now);
    final (totalIncome, totalExpense) = totalsForDateRange(range);
    final expenseCats = expenseByCategory(range);
    final incomeCats = incomeByCategory(range);
    final buckets = [
      for (final (bucketStart, income, expense) in cashFlowForRange(range))
        CashFlowBucket(start: bucketStart, income: income, expense: expense),
    ];

    // Derived context fed to the AI prompts, computed once here so each
    // prompt-builder gets plain numbers instead of re-deriving them.
    final savingsRate = totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : null;

    final (prevIncome, prevExpense) = totalsForDateRange(_precedingRange(range));

    String? topCategoryName;
    double? topCategoryAmount;
    double? topCategoryPercent;
    if (expenseCats.isNotEmpty && totalExpense > 0) {
      final sorted = expenseCats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topCategoryName = sorted.first.key;
      topCategoryAmount = sorted.first.value;
      topCategoryPercent = sorted.first.value / totalExpense;
    }

    double? typicalIncomeForPeriod;
    if (profile.typicalMonthlyIncome != null && profile.typicalMonthlyIncome! > 0) {
      final spanDays = range.end.difference(range.start).inDays + 1;
      typicalIncomeForPeriod = profile.typicalMonthlyIncome! / 30 * spanDays;
    }

    // Most recent same-period-type analysis with a loaded overall
    // assessment, for continuity — must be looked up before the new
    // analysis is inserted, since savedAnalyses is newest-first.
    SavedAnalysis? previousAnalysis;
    for (final a in savedAnalyses) {
      if (a.period == period && a.overallStatus == AnalysisAnswerStatus.loaded) {
        previousAnalysis = a;
        break;
      }
    }

    final id = now.millisecondsSinceEpoch.toString();

    final results = await Future.wait([
      _fetchGoalProgress(
        range,
        totalIncome,
        totalExpense,
        savingsRate,
        typicalIncomeForPeriod,
        previousAnalysis,
      ),
      _fetchCostCutting(
        range,
        expenseCats,
        topCategoryName,
        topCategoryAmount,
        topCategoryPercent,
        prevExpense,
      ),
      _fetchOverallAssessment(
        range,
        totalIncome,
        totalExpense,
        expenseCats,
        incomeCats,
        savingsRate,
        prevIncome,
        prevExpense,
        topCategoryName,
        topCategoryAmount,
        topCategoryPercent,
        typicalIncomeForPeriod,
        previousAnalysis,
      ),
      _fetchActionableSteps(
        range,
        totalIncome,
        totalExpense,
        expenseCats,
        incomeCats,
        savingsRate,
        topCategoryName,
        topCategoryAmount,
        topCategoryPercent,
        previousAnalysis,
      ),
    ]);

    if (results.every((r) => r.status == AnalysisAnswerStatus.error)) {
      throw AnalysisRequestException(
        'Arkad could not reach OpenRouter for this analysis — check your connection or API '
        'key in Settings and try again.',
      );
    }

    final analysis = SavedAnalysis(
      id: id,
      period: period,
      rangeStart: range.start,
      rangeEnd: range.end,
      createdAt: now,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      previousPeriodExpense: prevExpense,
      expenseByCategory: expenseCats,
      incomeByCategory: incomeCats,
      cashFlowBuckets: buckets,
      goalProgressText: results[0].text,
      goalProgressStatus: results[0].status,
      goalProgressError: results[0].error,
      costCuttingText: results[1].text,
      costCuttingStatus: results[1].status,
      costCuttingError: results[1].error,
      overallText: results[2].text,
      overallStatus: results[2].status,
      overallError: results[2].error,
      actionableStepsText: results[3].text,
      actionableStepsStatus: results[3].status,
      actionableStepsError: results[3].error,
    );

    savedAnalyses = [analysis, ...savedAnalyses];
    _persistence.saveSavedAnalyses(savedAnalyses);
    _analysisRequestLog = {..._analysisRequestLog, period: now};
    _persistence.saveAnalysisRequestLog(_analysisRequestLog);
    notifyListeners();

    return id;
  }

  Future<_AnswerResult> _fetchGoalProgress(
    DateTimeRange range,
    double totalIncome,
    double totalExpense,
    double? savingsRate,
    double? typicalIncomeForPeriod,
    SavedAnalysis? previousAnalysis,
  ) async {
    try {
      final text = await _openRouter.analyzeGoalProgress(
        apiKey: effectiveApiKey,
        modelSlug: apiConfig.modelSlug,
        profile: profile,
        range: range,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        savingsRate: savingsRate,
        typicalMonthlyIncomeForPeriod: typicalIncomeForPeriod,
        previousAnalysis: previousAnalysis,
      );
      return (text: text, status: AnalysisAnswerStatus.loaded, error: null);
    } catch (e) {
      final message = e is OpenRouterException ? e.message : 'Could not load this section.';
      return (text: null, status: AnalysisAnswerStatus.error, error: message);
    }
  }

  Future<_AnswerResult> _fetchCostCutting(
    DateTimeRange range,
    Map<String, double> expenseCats,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    double prevExpense,
  ) async {
    try {
      final text = await _openRouter.analyzeCostCutting(
        apiKey: effectiveApiKey,
        modelSlug: apiConfig.modelSlug,
        profile: profile,
        range: range,
        expenseByCategory: expenseCats,
        topCategoryName: topCategoryName,
        topCategoryAmount: topCategoryAmount,
        topCategoryPercent: topCategoryPercent,
        previousPeriodExpense: prevExpense,
      );
      return (text: text, status: AnalysisAnswerStatus.loaded, error: null);
    } catch (e) {
      final message = e is OpenRouterException ? e.message : 'Could not load this section.';
      return (text: null, status: AnalysisAnswerStatus.error, error: message);
    }
  }

  Future<_AnswerResult> _fetchOverallAssessment(
    DateTimeRange range,
    double totalIncome,
    double totalExpense,
    Map<String, double> expenseCats,
    Map<String, double> incomeCats,
    double? savingsRate,
    double prevIncome,
    double prevExpense,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    double? typicalIncomeForPeriod,
    SavedAnalysis? previousAnalysis,
  ) async {
    try {
      final text = await _openRouter.analyzeOverallAssessment(
        apiKey: effectiveApiKey,
        modelSlug: apiConfig.modelSlug,
        profile: profile,
        range: range,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        expenseByCategory: expenseCats,
        incomeByCategory: incomeCats,
        savingsRate: savingsRate,
        previousPeriodIncome: prevIncome,
        previousPeriodExpense: prevExpense,
        topCategoryName: topCategoryName,
        topCategoryAmount: topCategoryAmount,
        topCategoryPercent: topCategoryPercent,
        typicalMonthlyIncomeForPeriod: typicalIncomeForPeriod,
        previousAnalysis: previousAnalysis,
      );
      return (text: text, status: AnalysisAnswerStatus.loaded, error: null);
    } catch (e) {
      final message = e is OpenRouterException ? e.message : 'Could not load this section.';
      return (text: null, status: AnalysisAnswerStatus.error, error: message);
    }
  }

  Future<_AnswerResult> _fetchActionableSteps(
    DateTimeRange range,
    double totalIncome,
    double totalExpense,
    Map<String, double> expenseCats,
    Map<String, double> incomeCats,
    double? savingsRate,
    String? topCategoryName,
    double? topCategoryAmount,
    double? topCategoryPercent,
    SavedAnalysis? previousAnalysis,
  ) async {
    try {
      final text = await _openRouter.analyzeActionableSteps(
        apiKey: effectiveApiKey,
        modelSlug: apiConfig.modelSlug,
        profile: profile,
        range: range,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        expenseByCategory: expenseCats,
        incomeByCategory: incomeCats,
        savingsRate: savingsRate,
        topCategoryName: topCategoryName,
        topCategoryAmount: topCategoryAmount,
        topCategoryPercent: topCategoryPercent,
        previousAnalysis: previousAnalysis,
      );
      return (text: text, status: AnalysisAnswerStatus.loaded, error: null);
    } catch (e) {
      final message = e is OpenRouterException ? e.message : 'Could not load this section.';
      return (text: null, status: AnalysisAnswerStatus.error, error: message);
    }
  }

  SavedAnalysis? findAnalysis(String id) {
    for (final a in savedAnalyses) {
      if (a.id == id) return a;
    }
    return null;
  }

  void deleteSavedAnalysis(String id) {
    savedAnalyses = savedAnalyses.where((a) => a.id != id).toList();
    _persistence.saveSavedAnalyses(savedAnalyses);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _persistence.clearAll();
    transactions = _persistence.loadTransactions();
    profile = Profile();
    incomeCategories = _persistence.loadIncomeCategories();
    expenseCategories = _persistence.loadExpenseCategories();
    categoryIcons = _persistence.loadCategoryIcons();
    apiConfig = ApiConfig();
    conversations = [];
    activeConversationId = null;
    savedAnalyses = [];
    _analysisRequestLog = {};
    notifyListeners();
  }
}
