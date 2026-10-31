import 'package:flutter/material.dart';
import '../screens/app_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Sidebar-as-drawer navigation. See STYLE_GUIDE.md § Navigation and
/// § Mobile shell ("Sidebar becomes a slide-in drawer").
class NavDrawer extends StatelessWidget {
  const NavDrawer({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onOpenChat,
  });

  final AppView current;
  final ValueChanged<AppView> onSelect;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Image.asset(
                'assets/icon/arkad-logo.png',
                height: 32,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final view in AppView.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _NavPill(
                        view: view,
                        active: view == current,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(view);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: AppColors.sageTint,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenChat();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.darkGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ask Arkad',
                                style: AppTextStyles.manrope(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chat about your spending',
                                style: AppTextStyles.metadata(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.view,
    required this.active,
    required this.onTap,
  });

  final AppView view;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.darkGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(
                view.icon,
                size: 18,
                color: active ? AppColors.paper : AppColors.ink60,
              ),
              const SizedBox(width: 14),
              Text(
                view.label,
                style: AppTextStyles.manrope(
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.paper : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
