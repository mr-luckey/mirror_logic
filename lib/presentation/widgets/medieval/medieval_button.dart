import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';

enum MedievalButtonStyle {
  /// The one thing the screen wants you to do. Forged bronze, gold rim, glow.
  primary,

  /// Everything else. Dark wood with a bronze outline.
  secondary,
}

/// The standard wide action button, matching the gameplay pause menu.
class MedievalButton extends StatelessWidget {
  const MedievalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = MedievalButtonStyle.secondary,
    this.icon,
    this.expand = true,
    this.shimmer = false,
    this.sfx = Sfx.tap,
  });

  final String label;
  final VoidCallback? onPressed;
  final MedievalButtonStyle style;
  final IconData? icon;
  final bool expand;
  final Sfx? sfx;

  /// Sweeps a highlight across the face to pull the eye to the main CTA.
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final primary = style == MedievalButtonStyle.primary;
    final enabled = onPressed != null;
    final scale = Responsive.scaleOf(context);

    Widget face = Container(
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: primary ? 22 * scale : 18 * scale,
        vertical: (primary ? 15 : 12) * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: primary ? MedievalColors.bronzeMetal : null,
        color: primary ? null : MedievalColors.woodDeep.withValues(alpha: 0.62),
        border: Border.all(
          color: primary
              ? MedievalColors.bronzeHighlight.withValues(alpha: 0.9)
              : MedievalColors.bronze.withValues(alpha: 0.8),
          width: primary ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: primary ? 0.5 : 0.35),
            blurRadius: primary ? 14 : 8,
            offset: Offset(0, primary ? 6 : 3),
          ),
          if (primary)
            BoxShadow(
              color: MedievalColors.bronzeLight.withValues(alpha: 0.3),
              blurRadius: 18,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: Responsive.sp(context, primary ? 19 : 17),
              color: primary
                  ? MedievalColors.woodDeep
                  : MedievalColors.textGold,
            ),
            SizedBox(width: 9 * scale),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MedievalTextStyles.cinzel(
                size: Responsive.sp(context, primary ? 16 : 14),
                weight: FontWeight.w700,
                letterSpacing: primary ? 1.4 : 0.8,
                // Dark ink on the bright bronze face reads as stamped metal.
                color: primary
                    ? MedievalColors.woodDeep
                    : MedievalColors.textCream,
              ),
            ),
          ),
        ],
      ),
    );

    if (shimmer && enabled) {
      // Boundaried because the sweep never stops, and its shader would
      // otherwise repaint whatever screen is hosting the button.
      face = RepaintBoundary(
        child: face
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 2600.ms,
              delay: 900.ms,
              color: MedievalColors.bronzeHighlight.withValues(alpha: 0.55),
            ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MedievalPressable(
        onPressed: onPressed,
        enabled: enabled,
        sfx: sfx,
        child: face,
      ),
    );
  }
}
