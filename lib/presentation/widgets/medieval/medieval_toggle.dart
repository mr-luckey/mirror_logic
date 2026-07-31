import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/press_feedback.dart';

/// A bronze stud sliding in a carved channel, standing in for Material's
/// Switch so the settings screen keeps the same metal vocabulary.
class MedievalToggle extends StatelessWidget {
  const MedievalToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 48,
    this.height = 26,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () {
              PressFeedback.fire(context, Sfx.tap);
              onChanged!(!value);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: value
              ? MedievalColors.bronzeDark
              : Colors.black.withValues(alpha: 0.55),
          border: Border.all(
            color: value
                ? MedievalColors.bronzeLight.withValues(alpha: 0.9)
                : MedievalColors.bronzeDark.withValues(alpha: 0.8),
            width: 1.4,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: MedievalColors.bronzeHighlight.withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: value
                  ? MedievalColors.bronzeMetal
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        MedievalColors.stoneLight,
                        MedievalColors.stoneDark,
                      ],
                    ),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
