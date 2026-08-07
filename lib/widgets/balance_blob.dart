import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/formatters.dart';

/// The dashboard hero: a dark-green organic blob with a slow, subtle
/// border-radius morph. See STYLE_GUIDE.md § Organic balance blob.
class BalanceBlob extends StatefulWidget {
  const BalanceBlob({super.key, required this.balance, required this.savingsRate});

  final double balance;
  final double savingsRate;

  @override
  State<BalanceBlob> createState() => _BalanceBlobState();
}

class _BalanceBlobState extends State<BalanceBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _begin = [36.0, 64.0, 54.0, 46.0]; // topLeft, topRight, bottomRight, bottomLeft (%)
  static const _end = [57.0, 43.0, 38.0, 62.0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.savingsRate >= 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth.clamp(0, 520) / 2;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            double corner(int i) => lerpDouble(_begin[i], _end[i], t)! / 100 * scale;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(corner(0)),
                  topRight: Radius.circular(corner(1)),
                  bottomRight: Radius.circular(corner(2)),
                  bottomLeft: Radius.circular(corner(3)),
                ),
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL BALANCE', style: AppTextStyles.eyebrow(color: AppColors.sageTint)),
              const SizedBox(height: 14),
              Text(formatCurrency(widget.balance), style: AppTextStyles.balance()),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: AppColors.pastelYellow,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${isPositive ? '+' : ''}${widget.savingsRate.toStringAsFixed(1)}% saved',
                    style: AppTextStyles.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.pastelYellow,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "You're on track — spending is steady this week.",
                style: AppTextStyles.manrope(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
