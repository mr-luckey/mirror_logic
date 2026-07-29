import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/core/utils/responsive.dart';

class GoldCtaButton extends StatelessWidget {
  const GoldCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = height ?? Responsive.sp(context, 54).clamp(48.0, 60.0);
    final fontSize = Responsive.sp(context, 15).clamp(13.0, 17.0);

    return SizedBox(
      width: width,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.accentButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.hotPink.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.accentBright.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: fontSize + 6),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.orbitron(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeonOutlineButton extends StatelessWidget {
  const NeonOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final narrow = Responsive.isNarrow(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.accent.withValues(alpha: 0.6),
            width: 1.2,
          ),
          foregroundColor: AppColors.textPrimary,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 10 : 14,
            vertical: narrow ? 12 : 14,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.panel.withValues(alpha: 0.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.accent, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                style: GoogleFonts.exo2(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  fontSize: Responsive.sp(context, 14),
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
