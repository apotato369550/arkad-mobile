import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Example goals shown under the long-term-goal textarea, as plain read-only
/// text for the user to copy — not tappable, so this list can't grow the
/// step's height with selection state and never forces a scroll.
const List<String> goalIdeas = [
  'To have enough money leftover to invest',
  'To build a 6-month emergency fund',
  'To pay off my debt',
];

class GoalIdeaList extends StatelessWidget {
  const GoalIdeaList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final idea in goalIdeas)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('· $idea', style: AppTextStyles.metadata(color: AppColors.ink60)),
          ),
      ],
    );
  }
}
