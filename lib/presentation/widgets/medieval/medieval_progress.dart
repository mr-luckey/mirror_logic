import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';

/// Progress shown as molten bronze filling a carved channel.
class MedievalProgressBar extends StatelessWidget {
  const MedievalProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
  });

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? MedievalColors.bronzeLight;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return Container(
      height: height + 4,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(
          color: MedievalColors.bronzeDark.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MedievalColors.bronzeHighlight,
                    fill,
                    MedievalColors.bronze,
                  ],
                ),
                boxShadow: clamped > 0
                    ? [
                        BoxShadow(
                          color: fill.withValues(alpha: 0.5),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(height: height),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading state: a slowly turning bronze ring over a caption.
class MedievalLoader extends StatelessWidget {
  const MedievalLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: MedievalColors.bronzeLight,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: MedievalTextStyles.cinzel(
                size: 12,
                letterSpacing: 1.4,
                color: MedievalColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
