import 'spending_style_profile.dart';

/// "What do you plan to achieve with Arkad" choices offered in onboarding
/// and the Profile tab. Selecting the last option reveals a free-text field
/// captured in [Profile.goalOther].
const goalOptions = [
  'To Save More',
  'To Spend Less',
  'To Track my Income/Expenses',
  'Other',
];

class Profile {
  Profile({
    this.displayName = '',
    this.email = '',
    this.countryCode = '',
    this.currencyCode = 'USD',
    this.jobTitle = '',
    this.occupationField = '',
    this.goalType = '',
    this.goalOther = '',
    this.longTermGoal = '',
    this.typicalMonthlyIncome,
    this.savingsGoalAmount,
    this.spendingStyle = const SpendingStyleProfile(),
    this.onboardingComplete = false,
  });

  final String displayName;
  final String email;
  final String countryCode;
  final String currencyCode;
  final String jobTitle;
  final String occupationField;
  final String goalType;
  final String goalOther;
  final String longTermGoal;
  final double? typicalMonthlyIncome;
  final double? savingsGoalAmount;
  final SpendingStyleProfile spendingStyle;
  final bool onboardingComplete;

  /// The goal text worth surfacing to the user: the custom "Other" entry when
  /// given, otherwise the selected goal type, otherwise the freeform detail.
  String get goalSummary {
    if (goalType == 'Other' && goalOther.trim().isNotEmpty) {
      return goalOther.trim();
    }
    if (goalType.isNotEmpty) return goalType;
    return longTermGoal;
  }

  Profile copyWith({
    String? displayName,
    String? email,
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
    SpendingStyleProfile? spendingStyle,
    bool? onboardingComplete,
  }) {
    return Profile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      currencyCode: currencyCode ?? this.currencyCode,
      jobTitle: jobTitle ?? this.jobTitle,
      occupationField: occupationField ?? this.occupationField,
      goalType: goalType ?? this.goalType,
      goalOther: goalOther ?? this.goalOther,
      longTermGoal: longTermGoal ?? this.longTermGoal,
      typicalMonthlyIncome: clearTypicalMonthlyIncome
          ? null
          : (typicalMonthlyIncome ?? this.typicalMonthlyIncome),
      savingsGoalAmount: clearSavingsGoalAmount
          ? null
          : (savingsGoalAmount ?? this.savingsGoalAmount),
      spendingStyle: spendingStyle ?? this.spendingStyle,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      currencyCode: json['currencyCode'] as String? ?? 'USD',
      jobTitle: json['jobTitle'] as String? ?? '',
      occupationField: json['occupationField'] as String? ?? '',
      goalType: json['goalType'] as String? ?? '',
      goalOther: json['goalOther'] as String? ?? '',
      longTermGoal: json['longTermGoal'] as String? ?? '',
      typicalMonthlyIncome: (json['typicalMonthlyIncome'] as num?)?.toDouble(),
      savingsGoalAmount: (json['savingsGoalAmount'] as num?)?.toDouble(),
      spendingStyle: SpendingStyleProfile.fromJson(
        json['spendingStyle'] as Map<String, dynamic>?,
      ),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'email': email,
    'countryCode': countryCode,
    'currencyCode': currencyCode,
    'jobTitle': jobTitle,
    'occupationField': occupationField,
    'goalType': goalType,
    'goalOther': goalOther,
    'longTermGoal': longTermGoal,
    'typicalMonthlyIncome': typicalMonthlyIncome,
    'savingsGoalAmount': savingsGoalAmount,
    'spendingStyle': spendingStyle.toJson(),
    'onboardingComplete': onboardingComplete,
  };
}
