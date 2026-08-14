/// "What do you plan to achieve with Arkad" choices offered in onboarding
/// and the Profile tab. Selecting the last option reveals a free-text field
/// captured in [Profile.goalOther].
const goalOptions = [
  'To Save More',
  'To Spend Less',
  'To  track my Income/Expenses',
  'Other',
];

class Profile {
  Profile({
    this.displayName = '',
    this.countryCode = '',
    this.currencyCode = 'USD',
    this.jobTitle = '',
    this.occupationField = '',
    this.goalType = '',
    this.goalOther = '',
    this.longTermGoal = '',
    this.typicalMonthlyIncome,
    this.savingsGoalAmount,
    this.onboardingComplete = false,
  });

  final String displayName;
  final String countryCode;
  final String currencyCode;
  final String jobTitle;
  final String occupationField;
  final String goalType;
  final String goalOther;
  final String longTermGoal;
  final double? typicalMonthlyIncome;
  final double? savingsGoalAmount;
  final bool onboardingComplete;

  /// The goal text worth surfacing to the user: the custom "Other" entry when
  /// given, otherwise the selected goal type, otherwise the freeform detail.
  String get goalSummary {
    if (goalType == 'Other' && goalOther.trim().isNotEmpty) return goalOther.trim();
    if (goalType.isNotEmpty) return goalType;
    return longTermGoal;
  }

  Profile copyWith({
    String? displayName,
    String? countryCode,
    String? currencyCode,
    String? jobTitle,
    String? occupationField,
    String? goalType,
    String? goalOther,
    String? longTermGoal,
    double? typicalMonthlyIncome,
    bool clearTypicalMonthlyIncome = false,
    double? savingsGoalAmount,
    bool clearSavingsGoalAmount = false,
    bool? onboardingComplete,
  }) {
    return Profile(
      displayName: displayName ?? this.displayName,
      countryCode: countryCode ?? this.countryCode,
      currencyCode: currencyCode ?? this.currencyCode,
      jobTitle: jobTitle ?? this.jobTitle,
      occupationField: occupationField ?? this.occupationField,
      goalType: goalType ?? this.goalType,
      goalOther: goalOther ?? this.goalOther,
      longTermGoal: longTermGoal ?? this.longTermGoal,
      typicalMonthlyIncome:
          clearTypicalMonthlyIncome ? null : (typicalMonthlyIncome ?? this.typicalMonthlyIncome),
      savingsGoalAmount:
          clearSavingsGoalAmount ? null : (savingsGoalAmount ?? this.savingsGoalAmount),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['displayName'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      jobTitle: json['jobTitle'] as String? ?? '',
      occupationField: json['occupationField'] as String? ?? '',
      goalType: json['goalType'] as String? ?? '',
      goalOther: json['goalOther'] as String? ?? '',
      longTermGoal: json['longTermGoal'] as String? ?? '',
      typicalMonthlyIncome: (json['typicalMonthlyIncome'] as num?)?.toDouble(),
      savingsGoalAmount: (json['savingsGoalAmount'] as num?)?.toDouble(),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'jobTitle': jobTitle,
        'occupationField': occupationField,
        'goalType': goalType,
        'goalOther': goalOther,
        'longTermGoal': longTermGoal,
        'typicalMonthlyIncome': typicalMonthlyIncome,
        'savingsGoalAmount': savingsGoalAmount,
        'onboardingComplete': onboardingComplete,
      };
}
