import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Paper surface, soft border, quiet shadow. See STYLE_GUIDE.md § Cards and surfaces.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = AppColors.paper,
    this.radius = AppRadii.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.ink10),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.035),
            blurRadius: 30,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
