import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.panel.withValues(alpha: 0.7),
                AppColors.secondaryDark.withValues(alpha: 0.5),
              ],
            ),
            border: Border.all(
              color: glow
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.glassBorder,
            ),
            boxShadow: [
              if (glow)
                BoxShadow(
                  color: AppColors.accentBright.withValues(alpha: 0.2),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
