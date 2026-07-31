import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';

/// How a panel sits against the wood backdrop.
enum MedievalPanelStyle {
  /// Bolted on top of the wall: wood gradient, bright bronze rim, drop shadow.
  raised,

  /// Carved into the surface it sits on: dark, thin rim, no shadow.
  inset,
}

/// A bronze-framed wooden panel, the standard content surface off the board.
///
/// This is the card treatment the gameplay HUD and pause dialog use, pulled
/// out so every screen frames its content the same way.
class MedievalPanel extends StatelessWidget {
  const MedievalPanel({
    super.key,
    required this.child,
    this.style = MedievalPanelStyle.raised,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
    this.glow,
  });

  final Widget child;
  final MedievalPanelStyle style;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Accent colour for a halo around the panel, marking it as the live one.
  final Color? glow;

  static const LinearGradient _raisedFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5A4030), Color(0xFF3A2818), Color(0xFF1A1008)],
  );

  @override
  Widget build(BuildContext context) {
    final inset = style == MedievalPanelStyle.inset;
    final accent = glow;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: inset
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MedievalColors.bronzeDark.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.35),
                ],
              )
            : _raisedFill,
        border: Border.all(
          color: inset
              ? MedievalColors.bronze.withValues(alpha: 0.55)
              : (accent ?? MedievalColors.bronzeLight).withValues(alpha: 0.85),
          width: inset ? 1 : 2.2,
        ),
        boxShadow: inset
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                // Faint warm rim from the top-left, the light direction every
                // medieval surface in the game shares.
                BoxShadow(
                  color: (accent ?? MedievalColors.bronzeHighlight).withValues(
                    alpha: accent == null ? 0.12 : 0.4,
                  ),
                  blurRadius: accent == null ? 6 : 16,
                  offset: Offset(0, accent == null ? -1 : 0),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A hairline bronze rule for separating rows inside a panel.
class MedievalDivider extends StatelessWidget {
  const MedievalDivider({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                MedievalColors.bronze.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
