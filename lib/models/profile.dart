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
  });

  final String displayName;
  final String financialGoal;
  final double? typicalMonthlyIncome;
  final String currencyCode;
  final String location;
  final String occupation;
  final double? savingsGoalAmount;
  final bool onboardingComplete;

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
      };
}
