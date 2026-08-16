import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Full-pill destructive action. Clay text on a soft clay-tint surface —
/// never the loud red-alert treatment. See STYLE_GUIDE.md § Buttons.
class ClayButton extends StatelessWidget {
  const ClayButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.clay.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.clay),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppTextStyles.buttonLabel(color: AppColors.clay)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded icon tile used for category icons, avatars, stat-card glyphs.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    this.icon,
    this.imageAsset,
    this.background = AppColors.sageTint,
    this.foreground = AppColors.darkGreen,
    this.size = 44,
  }) : assert(icon != null || imageAsset != null, 'IconTile requires either icon or imageAsset');

  final IconData? icon;
  final String? imageAsset;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageAsset != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.20),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.iconTile)),
        child: Image.asset(imageAsset!, fit: BoxFit.contain),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.iconTile)),
      child: Icon(icon, color: foreground, size: size * 0.45),
    );
  }
}
