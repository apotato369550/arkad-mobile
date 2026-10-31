import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:arkad_mobile/models/analysis_period.dart';
import 'package:arkad_mobile/models/api_config.dart';
import 'package:arkad_mobile/models/saved_analysis.dart';
import 'package:arkad_mobile/models/transaction.dart';
import 'package:arkad_mobile/services/app_state.dart';
import 'package:arkad_mobile/services/openrouter_service.dart';
import 'package:arkad_mobile/services/persistence_service.dart';

SavedAnalysis sampleAnalysis({
  String id = 'sample',
  AnalysisPeriod period = AnalysisPeriod.sevenDays,
  DateTime? createdAt,
  bool archived = false,
}) {
  final date = createdAt ?? DateTime(2026, 1, 10);
  return SavedAnalysis(
    id: id,
    period: period,
    createdAt: date,
    rangeStart: date.subtract(const Duration(days: 6)),
    rangeEnd: date,
    isArchived: archived,
    totalIncome: 10000,
    totalExpense: 3000,
    previousPeriodExpense: 2500,
    expenseByCategory: {'Food': 3000},
    incomeByCategory: {'Salary': 10000},
    cashFlowBuckets: [],
    overallText: 'Assessment for $id',
    goalProgressStatus: AnalysisAnswerStatus.loaded,
    costCuttingStatus: AnalysisAnswerStatus.loaded,
    overallStatus: AnalysisAnswerStatus.loaded,
    actionableStepsStatus: AnalysisAnswerStatus.loaded,
  );
}

http.Response completionResponse([String text = 'Useful guidance.']) =>
    http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': text},
          },
        ],
      }),
      200,
    );

Future<PersistenceService> testPersistence() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  return PersistenceService.create();
}

Future<AppState> testState({
  DateTime Function()? now,
  Duration chatReplyTimeout = const Duration(seconds: 45),
  Future<http.Response> Function(http.Request)? handler,
}) async {
  final persistence = await testPersistence();
  final state = AppState(
    persistence,
    chatReplyTimeout: chatReplyTimeout,
    now: now ?? () => DateTime(2026, 1, 10),
    openRouter: OpenRouterService(
      client: MockClient(handler ?? (_) async => completionResponse()),
      delay: (_) async {},
    ),
  );
  state.apiConfig = ApiConfig(apiKey: 'test-key');
  state.transactions = [
    for (var day = 1; day <= 10; day++)
      LedgerTransaction(
        id: day,
        merchant: 'Market',
        category: 'Food',
        date: DateTime(2026, 1, day),
        amount: 100,
        type: TransactionType.expense,
      ),
  ];
  return state;
}

Future<PersistenceService> createExistingPersistence() =>
    PersistenceService.create();
