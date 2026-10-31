import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../screens/spending_style_quiz_screen.dart';
import 'app_card.dart';

class SpendingStyleCard extends StatelessWidget {
  const SpendingStyleCard({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final complete = appState.profile.spendingStyle.isComplete;
    return AppCard(
      color: complete ? AppColors.sageTint : AppColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.pastelYellow,
                borderRadius: BorderRadius.circular(AppRadii.iconTile),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.darkGreen),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                complete
                    ? 'Your spending style'
                    : 'What kind of spender are you?',
                style: AppTextStyles.cardHeading(),
              ),
              const SizedBox(height: 6),
              Text(
                complete
                    ? 'See the preferences guiding Arkad’s advice.'
                    : 'A short quiz to make Arkad’s guidance feel more personal.',
                style: AppTextStyles.metadata(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SpendingStyleQuizScreen(
                  appState: appState,
                  showResultInitially: complete,
                ),
              ),
            ),
            child: Text(complete ? 'View results' : 'Answer quiz'),
          ),
        ],
      ),
    );
  }
}
