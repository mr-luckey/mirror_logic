import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';

/// Coin or hint chip with optional green + action.
class MedievalResourceChip extends StatelessWidget {
  const MedievalResourceChip({
    super.key,
    required this.icon,
    required this.label,
    this.onAdd,
    this.glowColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onAdd;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 4, right: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MedievalColors.bronzeMid,
            MedievalColors.bronzeDark,
          ],
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (glowColor ?? MedievalColors.bronzeHighlight)
                      .withValues(alpha: 0.9),
                  MedievalColors.bronzeDark,
                ],
              ),
              border: Border.all(
                color: MedievalColors.bronzeLight,
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 14, color: MedievalColors.textCream),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: MedievalTextStyles.cinzel(
              size: 12,
              weight: FontWeight.w700,
              color: MedievalColors.textCream,
            ),
          ),
          const SizedBox(width: 4),
          if (onAdd != null)
            MedievalPressable(
              onPressed: onAdd,
              child: Container(
                width: 22,
                height: 22,
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
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
