import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';
import '../models/category.dart';
import '../models/chat_message.dart';
import '../models/profile.dart';
import '../models/transaction.dart';

/// Versioned local persistence, mirroring the web app's localStorage keys
/// (see STYLE_GUIDE.md § Persistence keys) so a future migration can bump
/// the `:vN` suffix without losing prior data.
///
/// The OpenRouter API key is the one secret this app holds, so it lives in
/// Keystore-backed secure storage rather than plaintext SharedPreferences.
/// It's cached in memory after [create] so the rest of the class can stay
/// synchronous like before.
class PersistenceService {
  PersistenceService._(this._prefs, this._secureStorage, this._cachedApiKey);

  static const _transactionsKey = 'arkad:transactions:v1';
  static const _profileKey = 'arkad:profile:v1';
  static const _incomeCategoriesKey = 'arkad:income-categories:v1';
  static const _expenseCategoriesKey = 'arkad:expense-categories:v1';
  static const _apiConfigKey = 'arkad:api-config:v1';
  static const _chatHistoryKey = 'arkad:chat-history:v1';
  static const _secureApiKeyKey = 'arkad_api_key';
  // Bounds every secure-storage call: Keystore/libsecret access can in
  // principle stall (platform prompts, a broken keyring service), and that
  // should never be able to hang app boot or a settings save.
  static const _secureOpTimeout = Duration(seconds: 3);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String? _cachedApiKey;

  static Future<PersistenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();

    String? apiKey;
    try {
      apiKey = await secureStorage.read(key: _secureApiKeyKey).timeout(_secureOpTimeout);
    } catch (_) {
      apiKey = null;
    }

    // One-time migration: earlier builds stored the key in plaintext inside
    // the api-config prefs blob. Move it over and strip it from prefs.
    if (apiKey == null) {
      final raw = prefs.getString(_apiConfigKey);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final legacyKey = json['apiKey'] as String?;
          if (legacyKey != null && legacyKey.trim().isNotEmpty) {
            apiKey = legacyKey;
            try {
              await secureStorage
                  .write(key: _secureApiKeyKey, value: legacyKey)
                  .timeout(_secureOpTimeout);
            } catch (_) {}
            json.remove('apiKey');
            await prefs.setString(_apiConfigKey, jsonEncode(json));
          }
        } catch (_) {}
      }
    }

    return PersistenceService._(prefs, secureStorage, apiKey);
  }

  List<LedgerTransaction> loadTransactions() {
    final raw = _prefs.getString(_transactionsKey);
    if (raw == null) return _seedTransactions();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _seedTransactions();
    }
  }

  Future<void> saveTransactions(List<LedgerTransaction> transactions) {
    return _prefs.setString(
      _transactionsKey,
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );
  }

  Profile loadProfile() {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return Profile();
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Profile();
    }
  }

  Future<void> saveProfile(Profile profile) {
    return _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  List<String> loadIncomeCategories() {
    final raw = _prefs.getStringList(_incomeCategoriesKey);
    return (raw == null || raw.isEmpty) ? List.of(defaultIncomeCategories) : raw;
  }

  Future<void> saveIncomeCategories(List<String> categories) {
    return _prefs.setStringList(_incomeCategoriesKey, categories);
  }

  List<String> loadExpenseCategories() {
    final raw = _prefs.getStringList(_expenseCategoriesKey);
    return (raw == null || raw.isEmpty) ? List.of(defaultExpenseCategories) : raw;
  }

  Future<void> saveExpenseCategories(List<String> categories) {
    return _prefs.setStringList(_expenseCategoriesKey, categories);
  }

  ApiConfig loadApiConfig() {
    final raw = _prefs.getString(_apiConfigKey);
    if (raw == null) return ApiConfig(apiKey: _cachedApiKey);
    try {
      final config = ApiConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return config.copyWith(apiKey: _cachedApiKey, clearKey: _cachedApiKey == null);
    } catch (_) {
      return ApiConfig(apiKey: _cachedApiKey);
    }
  }

  Future<void> saveApiConfig(ApiConfig config) async {
    _cachedApiKey = config.apiKey;
    try {
      if (config.hasKey) {
        await _secureStorage
            .write(key: _secureApiKeyKey, value: config.apiKey)
            .timeout(_secureOpTimeout);
      } else {
        await _secureStorage.delete(key: _secureApiKeyKey).timeout(_secureOpTimeout);
      }
    } catch (_) {}
    // apiKey is intentionally omitted here — it lives only in secure storage.
    await _prefs.setString(
      _apiConfigKey,
      jsonEncode({'modelSlug': config.modelSlug}),
    );
  }

  List<ChatMessage> loadChatHistory() {
    final raw = _prefs.getString(_chatHistoryKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatHistory(List<ChatMessage> messages) {
    return _prefs.setString(_chatHistoryKey, jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  Future<void> clearAll() async {
    _cachedApiKey = null;
    try {
      await _secureStorage.delete(key: _secureApiKeyKey).timeout(_secureOpTimeout);
    } catch (_) {}
    await Future.wait([
      _prefs.remove(_transactionsKey),
      _prefs.remove(_profileKey),
      _prefs.remove(_incomeCategoriesKey),
      _prefs.remove(_expenseCategoriesKey),
      _prefs.remove(_apiConfigKey),
      _prefs.remove(_chatHistoryKey),
    ]);
  }

  /// A year of recurring, realistic demo activity — payroll (with a
  /// mid-year raise), rent, subscriptions, groceries, dining, transport,
  /// entertainment, health, occasional travel, freelance income, and a
  /// December bonus — so a fresh install has enough history to populate
  /// every cash flow chart range (7D/30D/3M/12M) and several pages of
  /// recent activity. Seeded RNG for jitter only — dates and cadence are
  /// deterministic.
  List<LedgerTransaction> _seedTransactions() {
    final random = Random(42);
    final now = DateTime.now();
    final entries = <LedgerTransaction>[];
    var id = 1;

    const groceryMerchants = ["Trader Joe's", 'Whole Foods', 'Safeway', 'Sprouts Market'];
    const diningMerchants = [
      'Chipotle',
      'Sweetgreen',
      'Corner Cafe',
      'Pizzeria Roma',
      'Thai Basil',
      'Blue Bottle Coffee',
      'Ramen House',
      'Bagel Corner',
    ];
    const generalMerchants = ['Amazon', 'Target', 'Home Depot', 'IKEA'];
    const transportMerchants = ['Uber', 'Lyft'];
    const entertainmentMerchants = ['AMC Theatres', 'Steam', 'PlayStation Store', 'Ticketmaster'];
    const healthMerchants = ['CVS Pharmacy', 'Walgreens', 'City Dental', 'Riverside Urgent Care'];
    const travelMerchants = ['Delta Airlines', 'Airbnb', 'Marriott Hotels'];
    const subscriptions = [('Spotify', 11.99), ('Netflix', 15.49), ('Iron Peak Gym', 42.0)];

    void addIfPast(DateTime date, String merchant, String category, double amount, TransactionType type) {
      if (date.isAfter(now)) return;
      entries.add(LedgerTransaction(
        id: id++,
        merchant: merchant,
        category: category,
        date: date,
        amount: amount,
        type: type,
      ));
    }

    for (var monthsAgo = 11; monthsAgo >= 0; monthsAgo--) {
      final monthYear = now.year;
      final monthNum = now.month - monthsAgo;
      final daysInMonth = DateTime(monthYear, monthNum + 1, 0).day;
      DateTime onDay(int day) => DateTime(monthYear, monthNum, day.clamp(1, daysInMonth));

      // A modest raise kicks in for the more recent half of the year.
      final payrollBase = monthsAgo <= 5 ? 1750.0 : 1600.0;
      addIfPast(onDay(1), 'Employer Payroll', 'Income', payrollBase + random.nextInt(120), TransactionType.income);
      addIfPast(onDay(15), 'Employer Payroll', 'Income', payrollBase + random.nextInt(120), TransactionType.income);
      addIfPast(onDay(1), 'Maple Court Apartments', 'Housing', 1450, TransactionType.expense);
      addIfPast(onDay(3), 'Metro Transit', 'Transport', 45, TransactionType.expense);
      for (final sub in subscriptions) {
        addIfPast(onDay(5), sub.$1, 'Subscriptions', sub.$2, TransactionType.expense);
      }
      for (var day = 4; day <= daysInMonth; day += 7) {
        addIfPast(
          onDay(day),
          groceryMerchants[random.nextInt(groceryMerchants.length)],
          'Groceries',
          38.0 + random.nextInt(55),
          TransactionType.expense,
        );
      }
      for (var day = 2; day <= daysInMonth; day += 4) {
        addIfPast(
          onDay(day),
          diningMerchants[random.nextInt(diningMerchants.length)],
          'Dining',
          9.0 + random.nextInt(28),
          TransactionType.expense,
        );
      }
      for (var day = 10; day <= daysInMonth; day += 11) {
        addIfPast(
          onDay(day),
          transportMerchants[random.nextInt(transportMerchants.length)],
          'Transport',
          12.0 + random.nextInt(18),
          TransactionType.expense,
        );
      }
      for (var day = 8; day <= daysInMonth; day += 13) {
        addIfPast(
          onDay(day),
          generalMerchants[random.nextInt(generalMerchants.length)],
          'General',
          18.0 + random.nextInt(120),
          TransactionType.expense,
        );
      }
      // Entertainment: most months.
      if (random.nextDouble() < 0.7) {
        addIfPast(
          onDay(14 + random.nextInt(10)),
          entertainmentMerchants[random.nextInt(entertainmentMerchants.length)],
          'Entertainment',
          15.0 + random.nextInt(55),
          TransactionType.expense,
        );
      }
      // Health: about every other month.
      if (random.nextDouble() < 0.5) {
        addIfPast(
          onDay(6 + random.nextInt(18)),
          healthMerchants[random.nextInt(healthMerchants.length)],
          'Health',
          20.0 + random.nextInt(130),
          TransactionType.expense,
        );
      }
      // Travel: a handful of trips across the year.
      if (random.nextDouble() < 0.2) {
        addIfPast(
          onDay(10 + random.nextInt(15)),
          travelMerchants[random.nextInt(travelMerchants.length)],
          'Travel',
          180.0 + random.nextInt(470),
          TransactionType.expense,
        );
      }
      // Freelance income: roughly a third of months.
      if (random.nextDouble() < 0.35) {
        addIfPast(onDay(20 + random.nextInt(8)), 'Freelance client', 'Income', 150.0 + random.nextInt(500),
            TransactionType.income);
      }
      // Year-end bonus.
      if (monthNum == 12) {
        addIfPast(onDay(20), 'Employer Payroll', 'Income', 900.0 + random.nextInt(600), TransactionType.income);
      }
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}
