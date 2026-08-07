class Profile {
  Profile({
    this.displayName = '',
    this.financialGoal = '',
    this.typicalMonthlyIncome,
    this.onboardingComplete = false,
  });

  final String displayName;
  final String financialGoal;
  final double? typicalMonthlyIncome;
  final bool onboardingComplete;

  Profile copyWith({
    String? displayName,
    String? financialGoal,
    double? typicalMonthlyIncome,
    bool clearTypicalMonthlyIncome = false,
    bool? onboardingComplete,
  }) {
    return Profile(
      displayName: displayName ?? this.displayName,
      financialGoal: financialGoal ?? this.financialGoal,
      typicalMonthlyIncome:
          clearTypicalMonthlyIncome ? null : (typicalMonthlyIncome ?? this.typicalMonthlyIncome),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['displayName'] as String? ?? '',
      financialGoal: json['financialGoal'] as String? ?? '',
      typicalMonthlyIncome: (json['typicalMonthlyIncome'] as num?)?.toDouble(),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'financialGoal': financialGoal,
        'typicalMonthlyIncome': typicalMonthlyIncome,
        'onboardingComplete': onboardingComplete,
      };
}
