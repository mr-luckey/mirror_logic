import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';

/// Circular bronze control with optional label underneath.
class MedievalBronzeButton extends StatelessWidget {
  const MedievalBronzeButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.size = 48,
    this.badge,
    this.sfx = Sfx.tap,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final double size;
  final String? badge;
  final Sfx? sfx;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return MedievalPressable(
      onPressed: onPressed,
      sfx: sfx,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        MedievalColors.bronzeHighlight,
                        MedievalColors.bronzeMid,
                        MedievalColors.bronzeDark,
                      ],
                    ),
                    border: Border.all(
                      color: MedievalColors.bronzeLight.withValues(alpha: 0.85),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: MedievalColors.bronzeHighlight.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          MedievalColors.bronze.withValues(alpha: 0.35),
                          MedievalColors.woodDeep.withValues(alpha: 0.9),
                        ],
                      ),
                      border: Border.all(
                        color: MedievalColors.bronzeDark,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: MedievalColors.textGold,
                      size: size * 0.42,
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MedievalColors.greenPlus,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MedievalColors.bronzeLight,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: MedievalTextStyles.cinzel(
                          size: 8,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: MedievalTextStyles.cinzel(
                size: 9,
                letterSpacing: 0.8,
                color: MedievalColors.textGold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
