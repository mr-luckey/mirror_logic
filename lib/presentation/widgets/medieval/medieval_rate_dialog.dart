import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/app_info.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';

/// Invitation to rate the game, framed like the rest of the keep.
///
/// It deliberately asks nothing about how the player feels. Play's in-app review
/// guidance forbids putting a sentiment question in front of the review flow —
/// "enjoying the game?", or a star picker that only forwards happy players to
/// the store — because the ratings that come back are filtered rather than
/// representative. So the stars here are scenery, the ask is plain, and turning
/// it down takes one tap.
class MedievalRateDialog extends StatelessWidget {
  const MedievalRateDialog({
    super.key,
    required this.onRate,
    required this.onDismiss,
  });

  final VoidCallback onRate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.pageGutter(context),
          ),
          child: MedievalPanel(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StarRow(),
                const SizedBox(height: 12),
                Text(
                  'RATE ${AppInfo.name.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 16),
                    weight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: MedievalColors.textGold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'A word on the Play Store helps other puzzlers find the keep.',
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 12.5),
                    height: 1.4,
                    color: MedievalColors.textCream.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MedievalButton(
                        label: 'Not Now',
                        sfx: Sfx.back,
                        onPressed: onDismiss,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MedievalButton(
                        label: 'Rate',
                        style: MedievalButtonStyle.primary,
                        onPressed: onRate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Five lit stars, purely decorative — they are not a picker.
class _StarRow extends StatelessWidget {
  const _StarRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child:
              Icon(
                    Icons.star_rounded,
                    size: 26,
                    color: MedievalColors.bronzeHighlight,
                    shadows: [
                      Shadow(
                        color: MedievalColors.bronzeHighlight.withValues(
                          alpha: 0.7,
                        ),
                        blurRadius: 14,
                      ),
                    ],
                  )
                  .animate(delay: (90 * i).ms)
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    curve: Curves.elasticOut,
                    duration: 620.ms,
                  )
                  .fadeIn(duration: 180.ms),
        );
      }),
    );
  }
}

/// Puts the rate invitation up and reports whether the player accepted it.
Future<bool> showMedievalRateDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) => MedievalRateDialog(
      onRate: () => Navigator.pop(dialogContext, true),
      onDismiss: () => Navigator.pop(dialogContext, false),
    ),
  );
  return accepted ?? false;
}
