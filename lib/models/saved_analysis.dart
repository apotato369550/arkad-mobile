import '../services/formatters.dart';
import 'analysis_period.dart';

/// One bucket of [AppState.cashFlowForRange], frozen at analysis-request
/// time so a saved analysis's chart doesn't shift if the live ledger changes
/// later. Dart records don't round-trip through JSON on their own, hence
/// this tiny wrapper class.
class CashFlowBucket {
  CashFlowBucket({required this.start, required this.income, required this.expense});

  final DateTime start;
  final double income;
  final double expense;

  factory CashFlowBucket.fromJson(Map<String, dynamic> json) {
    return CashFlowBucket(
      start: DateTime.parse(json['start'] as String),
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'income': income,
        'expense': expense,
      };
}

enum AnalysisAnswerStatus { loading, loaded, error }

/// A saved, point-in-time Arkad analysis for a given [AnalysisPeriod]. Holds
/// a snapshot of the numbers at request time (so the detail screen renders
/// consistently even as the live ledger keeps changing) plus four
/// independently-loading Q&A slots — goal progress, cost-cutting, an
/// overall assessment, and actionable steps — each fetched separately so
/// one slow/failed call doesn't block the others.
class SavedAnalysis {
  SavedAnalysis({
    required this.id,
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.createdAt,
    required this.totalIncome,
    required this.totalExpense,
    required this.previousPeriodExpense,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.cashFlowBuckets,
    this.goalProgressText,
    this.goalProgressStatus = AnalysisAnswerStatus.loading,
    this.goalProgressError,
    this.costCuttingText,
    this.costCuttingStatus = AnalysisAnswerStatus.loading,
    this.costCuttingError,
    this.overallText,
    this.overallStatus = AnalysisAnswerStatus.loading,
    this.overallError,
    this.actionableStepsText,
    this.actionableStepsStatus = AnalysisAnswerStatus.loading,
    this.actionableStepsError,
  });

  final String id;
  final AnalysisPeriod period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime createdAt;
  final double totalIncome;
  final double totalExpense;
  final double previousPeriodExpense;
  final Map<String, double> expenseByCategory;
  final Map<String, double> incomeByCategory;
  final List<CashFlowBucket> cashFlowBuckets;

  final String? goalProgressText;
  final AnalysisAnswerStatus goalProgressStatus;
  final String? goalProgressError;

  final String? costCuttingText;
  final AnalysisAnswerStatus costCuttingStatus;
  final String? costCuttingError;

  final String? overallText;
  final AnalysisAnswerStatus overallStatus;
  final String? overallError;

  final String? actionableStepsText;
  final AnalysisAnswerStatus actionableStepsStatus;
  final String? actionableStepsError;

  String get title => '${period.noun} ${formatMDY(rangeStart)} to ${formatMDY(rangeEnd)}';

  SavedAnalysis copyWith({
    String? goalProgressText,
    bool clearGoalProgressText = false,
    AnalysisAnswerStatus? goalProgressStatus,
    String? goalProgressError,
    bool clearGoalProgressError = false,
    String? costCuttingText,
    bool clearCostCuttingText = false,
    AnalysisAnswerStatus? costCuttingStatus,
    String? costCuttingError,
    bool clearCostCuttingError = false,
    String? overallText,
    bool clearOverallText = false,
    AnalysisAnswerStatus? overallStatus,
    String? overallError,
    bool clearOverallError = false,
    String? actionableStepsText,
    bool clearActionableStepsText = false,
    AnalysisAnswerStatus? actionableStepsStatus,
    String? actionableStepsError,
    bool clearActionableStepsError = false,
  }) {
    return SavedAnalysis(
      id: id,
      period: period,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      createdAt: createdAt,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      previousPeriodExpense: previousPeriodExpense,
      expenseByCategory: expenseByCategory,
      incomeByCategory: incomeByCategory,
      cashFlowBuckets: cashFlowBuckets,
      goalProgressText:
          clearGoalProgressText ? null : (goalProgressText ?? this.goalProgressText),
      goalProgressStatus: goalProgressStatus ?? this.goalProgressStatus,
      goalProgressError:
          clearGoalProgressError ? null : (goalProgressError ?? this.goalProgressError),
      costCuttingText:
          clearCostCuttingText ? null : (costCuttingText ?? this.costCuttingText),
      costCuttingStatus: costCuttingStatus ?? this.costCuttingStatus,
      costCuttingError:
          clearCostCuttingError ? null : (costCuttingError ?? this.costCuttingError),
      overallText: clearOverallText ? null : (overallText ?? this.overallText),
      overallStatus: overallStatus ?? this.overallStatus,
      overallError: clearOverallError ? null : (overallError ?? this.overallError),
      actionableStepsText:
          clearActionableStepsText ? null : (actionableStepsText ?? this.actionableStepsText),
      actionableStepsStatus: actionableStepsStatus ?? this.actionableStepsStatus,
      actionableStepsError:
          clearActionableStepsError ? null : (actionableStepsError ?? this.actionableStepsError),
    );
  }

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) {
    return SavedAnalysis(
      id: json['id'] as String,
      period: AnalysisPeriod.values.byName(json['period'] as String),
      rangeStart: DateTime.parse(json['rangeStart'] as String),
      rangeEnd: DateTime.parse(json['rangeEnd'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpense: (json['totalExpense'] as num).toDouble(),
      previousPeriodExpense: (json['previousPeriodExpense'] as num?)?.toDouble() ?? 0.0,
      expenseByCategory: (json['expenseByCategory'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      incomeByCategory: (json['incomeByCategory'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      cashFlowBuckets: (json['cashFlowBuckets'] as List<dynamic>)
          .map((e) => CashFlowBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      goalProgressText: json['goalProgressText'] as String?,
      goalProgressStatus:
          AnalysisAnswerStatus.values.byName(json['goalProgressStatus'] as String? ?? 'loaded'),
      goalProgressError: json['goalProgressError'] as String?,
      costCuttingText: json['costCuttingText'] as String?,
      costCuttingStatus:
          AnalysisAnswerStatus.values.byName(json['costCuttingStatus'] as String? ?? 'loaded'),
      costCuttingError: json['costCuttingError'] as String?,
      overallText: json['overallText'] as String?,
      overallStatus:
          AnalysisAnswerStatus.values.byName(json['overallStatus'] as String? ?? 'loaded'),
      overallError: json['overallError'] as String?,
      actionableStepsText: json['actionableStepsText'] as String?,
      actionableStepsStatus: AnalysisAnswerStatus.values
          .byName(json['actionableStepsStatus'] as String? ?? 'loaded'),
      actionableStepsError: json['actionableStepsError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period.name,
        'rangeStart': rangeStart.toIso8601String(),
        'rangeEnd': rangeEnd.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'previousPeriodExpense': previousPeriodExpense,
        'expenseByCategory': expenseByCategory,
        'incomeByCategory': incomeByCategory,
        'cashFlowBuckets': cashFlowBuckets.map((b) => b.toJson()).toList(),
        'goalProgressText': goalProgressText,
        'goalProgressStatus': goalProgressStatus.name,
        'goalProgressError': goalProgressError,
        'costCuttingText': costCuttingText,
        'costCuttingStatus': costCuttingStatus.name,
        'costCuttingError': costCuttingError,
        'overallText': overallText,
        'overallStatus': overallStatus.name,
        'overallError': overallError,
        'actionableStepsText': actionableStepsText,
        'actionableStepsStatus': actionableStepsStatus.name,
        'actionableStepsError': actionableStepsError,
      };
}
