import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';

/// Receipt for a rewarded video: what it paid, and what the purse holds now.
class MedievalCoinsEarnedDialog extends StatelessWidget {
  const MedievalCoinsEarnedDialog({
    super.key,
    required this.earned,
    required this.totalCoins,
    required this.onClose,
  });

  final int earned;
  final int totalCoins;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
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
                Icon(
                      Icons.monetization_on_rounded,
                      size: 44,
                      color: MedievalColors.bronzeHighlight,
                      shadows: [
                        Shadow(
                          color: MedievalColors.bronzeHighlight.withValues(
                            alpha: 0.7,
                          ),
                          blurRadius: 16,
                        ),
                      ],
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 620.ms,
                    )
                    .fadeIn(duration: 180.ms),
                const SizedBox(height: 12),
                Text(
                  'CONGRATULATIONS',
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzelDecorative(
                    size: Responsive.sp(context, 16),
                    weight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: MedievalColors.textGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You earned $earned coins',
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 13),
                    height: 1.4,
                    color: MedievalColors.textCream,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: MedievalColors.woodDeep.withValues(alpha: 0.55),
                    border: Border.all(
                      color: MedievalColors.bronze.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: MedievalColors.bronzeHighlight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total $totalCoins coins',
                        style: MedievalTextStyles.cinzel(
                          size: Responsive.sp(context, 12),
                          weight: FontWeight.w700,
                          color: MedievalColors.textGold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                MedievalButton(
                  label: 'Continue',
                  style: MedievalButtonStyle.primary,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMedievalCoinsEarnedDialog(
  BuildContext context, {
  required int earned,
  required int totalCoins,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) => MedievalCoinsEarnedDialog(
      earned: earned,
      totalCoins: totalCoins,
      onClose: () => Navigator.pop(dialogContext),
    ),
  );
}
