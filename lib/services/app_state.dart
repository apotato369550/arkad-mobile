import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/api_config.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/profile.dart';
import '../models/transaction.dart';
import 'formatters.dart';
import 'persistence_service.dart';

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
        apiConfig = _persistence.loadApiConfig(),
        conversations = _persistence.loadConversations(),
        activeConversationId = _determineActiveConversationId(_persistence.loadConversations()) {
    setAppCurrency(profile.currencyCode);
  }

  final PersistenceService _persistence;

  List<LedgerTransaction> transactions;
  Profile profile;
  List<String> incomeCategories;
  List<String> expenseCategories;
  ApiConfig apiConfig;
  List<Conversation> conversations;
  String? activeConversationId;

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
        return _bucketedByDays(bucketSizeDays: 1, count: 7);
      case CashFlowRange.sixMonths:
        return _monthlyBuckets(6);
      case CashFlowRange.twelveMonths:
        return _monthlyBuckets(12);
    }
  }

  List<(DateTime, double, double)> _bucketedByDays({
    required int bucketSizeDays,
    required int count,
  }) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final rangeStart = todayStart.subtract(Duration(days: bucketSizeDays * count - 1));
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

  List<(DateTime, double, double)> _monthlyBuckets(int count) {
    final now = DateTime.now();
    final months = List.generate(count, (i) => DateTime(now.year, now.month - (count - 1 - i), 1));
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

  void addCategory({required bool isIncome, required String name}) {
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

  Future<void> clearAllData() async {
    await _persistence.clearAll();
    transactions = _persistence.loadTransactions();
    profile = Profile();
    incomeCategories = _persistence.loadIncomeCategories();
    expenseCategories = _persistence.loadExpenseCategories();
    apiConfig = ApiConfig();
    conversations = [];
    activeConversationId = null;
    notifyListeners();
  }
}
