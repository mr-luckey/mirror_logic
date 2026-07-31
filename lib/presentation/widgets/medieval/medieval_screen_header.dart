import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';

/// Carved title bar with a bronze back button, used at the top of every
/// non-gameplay screen so they all read as the same place.
class MedievalScreenHeader extends StatelessWidget {
  const MedievalScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scale = Responsive.scaleOf(context);
    final back = onBack;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      child: Row(
        children: [
          if (back != null)
            MedievalBronzeButton(
              icon: Icons.arrow_back_rounded,
              onPressed: back,
              size: 42 * scale,
            )
          else
            SizedBox(width: 42 * scale),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 19),
                    weight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: MedievalColors.textGold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedievalTextStyles.cinzel(
                      size: Responsive.sp(context, 10),
                      letterSpacing: 1.2,
                      color: MedievalColors.textMuted,
                    ),
                  ),
                ],
                SizedBox(height: 6 * scale),
                _RuleWithDiamond(width: Responsive.wp(context, 0.42)),
              ],
            ),
          ),
          SizedBox(
            width: 42 * scale,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

/// Bronze rule tapering out of a centre diamond, the game's title underline.
class _RuleWithDiamond extends StatelessWidget {
  const _RuleWithDiamond({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    Widget rule(bool flip) => Expanded(
          child: Container(
            height: 1.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: flip ? Alignment.centerRight : Alignment.centerLeft,
                end: flip ? Alignment.centerLeft : Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  MedievalColors.bronzeLight.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        );

    return SizedBox(
      width: width,
      child: Row(
        children: [
          rule(false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: MedievalColors.bronzeLight,
                  boxShadow: [
                    BoxShadow(
                      color: MedievalColors.bronzeHighlight
                          .withValues(alpha: 0.6),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          rule(true),
        ],
      ),
    );
  }
}
