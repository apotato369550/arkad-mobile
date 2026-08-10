/// Risk-tolerance choices offered in onboarding and the Profile tab. Mirrors
/// the empty-string-means-unset convention used by [Profile.riskTolerance].
const riskToleranceOptions = ['Conservative', 'Balanced', 'Aggressive'];

class Profile {
  Profile({
    this.displayName = '',
    this.financialGoal = '',
    this.typicalMonthlyIncome,
    this.currencyCode = 'USD',
    this.location = '',
    this.occupation = '',
    this.savingsGoalAmount,
    this.onboardingComplete = false,
    this.goalTargetDate,
    this.riskTolerance = '',
    this.monthlyFixedObligations,
    this.dependents,
  });

  final String displayName;
  final String financialGoal;
  final double? typicalMonthlyIncome;
  final String currencyCode;
  final String location;
  final String occupation;
  final double? savingsGoalAmount;
  final bool onboardingComplete;
  final DateTime? goalTargetDate;
  final String riskTolerance;
  final double? monthlyFixedObligations;
  final int? dependents;

  Profile copyWith({
    String? displayName,
    String? financialGoal,
    double? typicalMonthlyIncome,
    bool clearTypicalMonthlyIncome = false,
    String? currencyCode,
    String? location,
    String? occupation,
    double? savingsGoalAmount,
    bool clearSavingsGoalAmount = false,
    bool? onboardingComplete,
    DateTime? goalTargetDate,
    bool clearGoalTargetDate = false,
    String? riskTolerance,
    double? monthlyFixedObligations,
    bool clearMonthlyFixedObligations = false,
    int? dependents,
    bool clearDependents = false,
  }) {
    return Profile(
      displayName: displayName ?? this.displayName,
      financialGoal: financialGoal ?? this.financialGoal,
      typicalMonthlyIncome:
          clearTypicalMonthlyIncome ? null : (typicalMonthlyIncome ?? this.typicalMonthlyIncome),
      currencyCode: currencyCode ?? this.currencyCode,
      location: location ?? this.location,
      occupation: occupation ?? this.occupation,
      savingsGoalAmount:
          clearSavingsGoalAmount ? null : (savingsGoalAmount ?? this.savingsGoalAmount),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      goalTargetDate: clearGoalTargetDate ? null : (goalTargetDate ?? this.goalTargetDate),
      riskTolerance: riskTolerance ?? this.riskTolerance,
      monthlyFixedObligations: clearMonthlyFixedObligations
          ? null
          : (monthlyFixedObligations ?? this.monthlyFixedObligations),
      dependents: clearDependents ? null : (dependents ?? this.dependents),
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['displayName'] as String? ?? '',
      financialGoal: json['financialGoal'] as String? ?? '',
      typicalMonthlyIncome: (json['typicalMonthlyIncome'] as num?)?.toDouble(),
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      location: json['location'] as String? ?? '',
      occupation: json['occupation'] as String? ?? '',
      savingsGoalAmount: (json['savingsGoalAmount'] as num?)?.toDouble(),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      goalTargetDate: json['goalTargetDate'] == null
          ? null
          : DateTime.parse(json['goalTargetDate'] as String),
      riskTolerance: json['riskTolerance'] as String? ?? '',
      monthlyFixedObligations: (json['monthlyFixedObligations'] as num?)?.toDouble(),
      dependents: (json['dependents'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'financialGoal': financialGoal,
        'typicalMonthlyIncome': typicalMonthlyIncome,
        'currencyCode': currencyCode,
        'location': location,
        'occupation': occupation,
        'savingsGoalAmount': savingsGoalAmount,
        'onboardingComplete': onboardingComplete,
        'goalTargetDate': goalTargetDate?.toIso8601String(),
        'riskTolerance': riskTolerance,
        'monthlyFixedObligations': monthlyFixedObligations,
        'dependents': dependents,
      };
}
