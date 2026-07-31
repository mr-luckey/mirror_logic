import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';

/// Earned stars as glowing gold, unearned as hollow bronze sockets.
class MedievalStarRow extends StatelessWidget {
  const MedievalStarRow({
    super.key,
    required this.filled,
    this.total = 3,
    this.size = 16,
    this.spacing = 2,
  });

  final int filled;
  final int total;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final lit = i < filled;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: lit
                  ? [
                      BoxShadow(
                        color: MedievalColors.bronzeHighlight.withValues(
                          alpha: 0.65,
                        ),
                        blurRadius: size * 0.55,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              lit ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: lit
                  ? MedievalColors.bronzeHighlight
                  : MedievalColors.bronzeDark.withValues(alpha: 0.9),
            ),
          ),
        );
      }),
    );
  }
}
