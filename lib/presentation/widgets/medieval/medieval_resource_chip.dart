import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';

/// Coin or hint chip with an optional green + action.
class MedievalResourceChip extends StatelessWidget {
  const MedievalResourceChip({
    super.key,
    required this.icon,
    required this.label,
    this.onAdd,
    this.onTap,
    this.glowColor,
    this.scale = 1.0,
  });

  final IconData icon;
  final String label;

  /// Action for the small green + stud.
  final VoidCallback? onAdd;

  /// Action for pressing the chip body.
  final VoidCallback? onTap;

  final Color? glowColor;

  /// Multiplier on every dimension, for HUDs that need a bigger touch target.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final height = 34.0 * scale;

    final chip = Container(
      height: height,
      padding: EdgeInsets.only(
        left: 4 * scale,
        right: (onAdd == null ? 10 : 2) * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MedievalColors.bronzeMid, MedievalColors.bronzeDark],
        ),
        border: Border.all(
          color: MedievalColors.bronzeLight.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26 * scale,
            height: 26 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (glowColor ?? MedievalColors.bronzeHighlight).withValues(
                    alpha: 0.9,
                  ),
                  MedievalColors.bronzeDark,
                ],
              ),
              border: Border.all(color: MedievalColors.bronzeLight, width: 1.2),
            ),
            child: Icon(
              icon,
              size: 14 * scale,
              color: MedievalColors.textCream,
            ),
          ),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: MedievalTextStyles.cinzel(
              size: 12 * scale,
              weight: FontWeight.w700,
              color: MedievalColors.textCream,
            ),
          ),
          SizedBox(width: 4 * scale),
          if (onAdd != null)
            MedievalPressable(
              onPressed: onAdd,
              child: Container(
                width: 22 * scale,
                height: 22 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MedievalColors.greenPlus,
                  border: Border.all(
                    color: MedievalColors.bronzeLight,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MedievalColors.greenPlus.withValues(alpha: 0.45),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(Icons.add, size: 14 * scale, color: Colors.white),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return MedievalPressable(onPressed: onTap, child: chip);
  }
}
