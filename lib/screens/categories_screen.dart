import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/category_manager.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text('Categories', style: AppTextStyles.pageHeading()),
          const SizedBox(height: 20),
          CategoryManager(appState: appState),
        ],
      ),
    );
  }
}
