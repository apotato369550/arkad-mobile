import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_period.dart';
import '../models/api_config.dart';
import '../models/backup_settings.dart';
import '../models/category.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/profile.dart';
import '../models/saved_analysis.dart';
import '../models/transaction.dart';
import 'app_config.dart';

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
  static const _categoryIconsKey = 'arkad:category-icons:v1';
  static const _apiConfigKey = 'arkad:api-config:v1';
  static const _conversationsKey = 'arkad:conversations:v1';
  static const _chatHistoryKey = 'arkad:chat-history:v1';
  static const _savedAnalysesKey = 'arkad:saved-analyses:v1';
  static const _analysisRequestLogKey = 'arkad:analysis-request-log:v1';
  static const _backupSettingsKey = 'arkad:backup-settings:v1';
  static const _categoriesDefaultsMergedKey = 'arkad:categories-defaults-merged:v1';
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

    // One-time migration: existing installs saved a snapshot of the default
    // category lists on first run, so category names added to
    // defaultIncomeCategories/defaultExpenseCategories in later app updates
    // never reached already-installed users. Merge any missing defaults into
    // the saved lists once, preserving existing order, custom categories,
    // and any user deletions made since.
    if (prefs.getBool(_categoriesDefaultsMergedKey) != true) {
      final income = prefs.getStringList(_incomeCategoriesKey);
      if (income != null && income.isNotEmpty) {
        final missing = defaultIncomeCategories.where((c) => !income.contains(c));
        if (missing.isNotEmpty) {
          await prefs.setStringList(_incomeCategoriesKey, [...income, ...missing]);
        }
      }
      final expense = prefs.getStringList(_expenseCategoriesKey);
      if (expense != null && expense.isNotEmpty) {
        final missing = defaultExpenseCategories.where((c) => !expense.contains(c));
        if (missing.isNotEmpty) {
          await prefs.setStringList(_expenseCategoriesKey, [...expense, ...missing]);
        }
      }
      await prefs.setBool(_categoriesDefaultsMergedKey, true);
    }

    return PersistenceService._(prefs, secureStorage, apiKey);
  }

  /// Sample data is a debug-mode convenience only — release builds start
  /// from an empty ledger when there's nothing stored yet.
  List<LedgerTransaction> loadTransactions() {
    final raw = _prefs.getString(_transactionsKey);
    if (raw == null) return AppConfig.isDebugMode ? _seedTransactions() : [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return AppConfig.isDebugMode ? _seedTransactions() : [];
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

  /// Icon keys chosen for custom categories, by category name (see
  /// lib/models/category.dart § categoryIconKeyFor). Default categories
  /// aren't stored here — their icon comes from the built-in mapping.
  Map<String, String> loadCategoryIcons() {
    final raw = _prefs.getString(_categoryIconsKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCategoryIcons(Map<String, String> icons) {
    return _prefs.setString(_categoryIconsKey, jsonEncode(icons));
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

  List<Conversation> loadConversations() {
    final raw = _prefs.getString(_conversationsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }

    // Migration: if new key is empty but old key has data, migrate it.
    final legacyRaw = _prefs.getString(_chatHistoryKey);
    if (legacyRaw != null) {
      try {
        final legacyList = jsonDecode(legacyRaw) as List<dynamic>;
        final legacyMessages = legacyList
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        if (legacyMessages.isNotEmpty) {
          final conversation = Conversation(
            id: 'legacy',
            title: 'Previous conversation',
            createdAt: legacyMessages.first.timestamp,
            messages: legacyMessages,
          );
          saveConversations([conversation]);
          return [conversation];
        }
      } catch (_) {}
    }

    return [];
  }

  Future<void> saveConversations(List<Conversation> conversations) {
    return _prefs.setString(
      _conversationsKey,
      jsonEncode(conversations.map((c) => c.toJson()).toList()),
    );
  }

  List<SavedAnalysis> loadSavedAnalyses() {
    final raw = _prefs.getString(_savedAnalysesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SavedAnalysis.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavedAnalyses(List<SavedAnalysis> analyses) {
    return _prefs.setString(
      _savedAnalysesKey,
      jsonEncode(analyses.map((a) => a.toJson()).toList()),
    );
  }

  Map<AnalysisPeriod, DateTime> loadAnalysisRequestLog() {
    final raw = _prefs.getString(_analysisRequestLogKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map(
        (key, value) => MapEntry(AnalysisPeriod.values.byName(key), DateTime.parse(value as String)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAnalysisRequestLog(Map<AnalysisPeriod, DateTime> log) {
    return _prefs.setString(
      _analysisRequestLogKey,
      jsonEncode(log.map((period, date) => MapEntry(period.name, date.toIso8601String()))),
    );
  }

  BackupSettings loadBackupSettings() {
    final raw = _prefs.getString(_backupSettingsKey);
    if (raw == null) return BackupSettings();
    try {
      return BackupSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return BackupSettings();
    }
  }

  Future<void> saveBackupSettings(BackupSettings settings) {
    return _prefs.setString(_backupSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Snapshot version, bumped when [buildBackupSnapshot]'s shape changes so
  /// [restoreBackupSnapshot] can reject or migrate snapshots it doesn't
  /// understand instead of guessing.
  static const _backupSnapshotVersion = 1;

  /// Everything a cloud backup needs to fully reconstruct local state on a
  /// new device. Deliberately excludes the OpenRouter API key (secret,
  /// per-device by design — see [saveApiConfig]) and the analysis request
  /// log (a rate-limit cooldown, not user data).
  Map<String, dynamic> buildBackupSnapshot() {
    return {
      'version': _backupSnapshotVersion,
      'transactions': loadTransactions().map((t) => t.toJson()).toList(),
      'profile': loadProfile().toJson(),
      'incomeCategories': loadIncomeCategories(),
      'expenseCategories': loadExpenseCategories(),
      'categoryIcons': loadCategoryIcons(),
      'conversations': loadConversations().map((c) => c.toJson()).toList(),
      'savedAnalyses': loadSavedAnalyses().map((a) => a.toJson()).toList(),
    };
  }

  /// Overwrites local state with a snapshot previously produced by
  /// [buildBackupSnapshot] (e.g. fetched from Supabase on a new device).
  /// Tolerant of missing/malformed individual fields, matching the defensive
  /// style of the rest of this class — a partially-decodable snapshot
  /// restores what it can rather than failing closed.
  Future<void> restoreBackupSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['version'] != _backupSnapshotVersion) {
      throw const FormatException('Unsupported backup version.');
    }
    // Decode every required field before writing. A corrupt cloud payload must
    // never leave a mixture of old and newly-restored local state.
    final transactions = (snapshot['transactions'] as List<dynamic>)
        .map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final profile = Profile.fromJson(snapshot['profile'] as Map<String, dynamic>);
    final income = (snapshot['incomeCategories'] as List<dynamic>).cast<String>();
    final expense = (snapshot['expenseCategories'] as List<dynamic>).cast<String>();
    final icons = (snapshot['categoryIcons'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    final conversations = (snapshot['conversations'] as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
    final analyses = (snapshot['savedAnalyses'] as List<dynamic>)
        .map((e) => SavedAnalysis.fromJson(e as Map<String, dynamic>))
        .toList();

    await Future.wait([
      saveTransactions(transactions),
      saveProfile(profile),
      saveIncomeCategories(income),
      saveExpenseCategories(expense),
      saveCategoryIcons(icons),
      saveConversations(conversations),
      saveSavedAnalyses(analyses),
    ]);
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
      _prefs.remove(_categoryIconsKey),
      _prefs.remove(_apiConfigKey),
      _prefs.remove(_conversationsKey),
      _prefs.remove(_chatHistoryKey),
      _prefs.remove(_savedAnalysesKey),
      _prefs.remove(_analysisRequestLogKey),
      _prefs.remove(_backupSettingsKey),
    ]);
  }

  /// A year of recurring, realistic demo activity — biweekly salary (with a
  /// mid-year raise), a smaller biweekly allowance, occasional freelance
  /// wage and gift income, a December bonus, rent, utilities, subscriptions,
  /// groceries, dining, transport, entertainment, health, and occasional
  /// travel — so a fresh install has enough history to populate every cash
  /// flow chart range (7D/6M/12M) and several pages of recent activity. The
  /// most recent ~3 months get much denser day-to-day coverage (near-daily
  /// dining/transport) than the rest of the year, since the analysis
  /// feature requires at least half the days in a requested period to have
  /// activity. Seeded RNG for jitter only — dates and cadence are
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
    const utilityMerchant = 'Riverside Water Co.';
    const giftOccasions = ['Birthday gift', 'Holiday gift'];

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
      // The last ~3 months get much denser daily coverage.
      final isRecent = monthsAgo <= 2;

      // A modest raise kicks in for the more recent half of the year.
      final payrollBase = monthsAgo <= 5 ? 1750.0 : 1600.0;
      addIfPast(onDay(1), 'Employer Payroll', 'Salary', payrollBase + random.nextInt(120), TransactionType.income);
      addIfPast(onDay(15), 'Employer Payroll', 'Salary', payrollBase + random.nextInt(120), TransactionType.income);
      // Smaller recurring biweekly allowance, every month.
      addIfPast(onDay(8), 'Family Allowance', 'Allowance', 50.0 + random.nextInt(80), TransactionType.income);
      addIfPast(onDay(22), 'Family Allowance', 'Allowance', 50.0 + random.nextInt(80), TransactionType.income);
      addIfPast(onDay(1), 'Maple Court Apartments', 'Housing', 1450, TransactionType.expense);
      addIfPast(onDay(3), 'Metro Transit', 'Transport', 45, TransactionType.expense);
      addIfPast(onDay(10), utilityMerchant, 'Utilities', 25.0 + random.nextInt(35), TransactionType.expense);
      for (final sub in subscriptions) {
        addIfPast(onDay(5), sub.$1, 'Subscriptions', sub.$2, TransactionType.expense);
      }
      // Groceries: weekly all year.
      for (var day = 4; day <= daysInMonth; day += 7) {
        addIfPast(
          onDay(day),
          groceryMerchants[random.nextInt(groceryMerchants.length)],
          'Groceries',
          38.0 + random.nextInt(55),
          TransactionType.expense,
        );
      }
      // Dining: near-daily on weekdays for the recent stretch, every few days otherwise.
      if (isRecent) {
        for (var day = 1; day <= daysInMonth; day++) {
          final date = onDay(day);
          if (date.weekday > DateTime.friday) continue;
          if (random.nextDouble() >= 0.85) continue;
          addIfPast(
            date,
            diningMerchants[random.nextInt(diningMerchants.length)],
            'Dining',
            9.0 + random.nextInt(28),
            TransactionType.expense,
          );
        }
        // Weekend dining, less frequent.
        for (var day = 1; day <= daysInMonth; day++) {
          final date = onDay(day);
          if (date.weekday <= DateTime.friday) continue;
          if (random.nextDouble() >= 0.5) continue;
          addIfPast(
            date,
            diningMerchants[random.nextInt(diningMerchants.length)],
            'Dining',
            9.0 + random.nextInt(28),
            TransactionType.expense,
          );
        }
      } else {
        for (var day = 2; day <= daysInMonth; day += 4) {
          addIfPast(
            onDay(day),
            diningMerchants[random.nextInt(diningMerchants.length)],
            'Dining',
            9.0 + random.nextInt(28),
            TransactionType.expense,
          );
        }
      }
      // Transport: several times a week for the recent stretch, existing cadence otherwise.
      if (isRecent) {
        for (var day = 1; day <= daysInMonth; day++) {
          if (random.nextDouble() >= 0.45) continue;
          addIfPast(
            onDay(day),
            transportMerchants[random.nextInt(transportMerchants.length)],
            'Transport',
            12.0 + random.nextInt(18),
            TransactionType.expense,
          );
        }
      } else {
        for (var day = 10; day <= daysInMonth; day += 11) {
          addIfPast(
            onDay(day),
            transportMerchants[random.nextInt(transportMerchants.length)],
            'Transport',
            12.0 + random.nextInt(18),
            TransactionType.expense,
          );
        }
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
      // Freelance/hourly wage income: roughly a third of months.
      if (random.nextDouble() < 0.35) {
        addIfPast(onDay(20 + random.nextInt(8)), 'Freelance client', 'Wage', 150.0 + random.nextInt(500),
            TransactionType.income);
      }
      // Occasional gift income: a few times a year.
      if (random.nextDouble() < 0.15) {
        addIfPast(
          onDay(12 + random.nextInt(12)),
          giftOccasions[random.nextInt(giftOccasions.length)],
          'Gift',
          20.0 + random.nextInt(130),
          TransactionType.income,
        );
      }
      // Year-end bonus.
      if (monthNum == 12) {
        addIfPast(onDay(20), 'Employer Payroll', 'Bonus', 900.0 + random.nextInt(600), TransactionType.income);
      }
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}
