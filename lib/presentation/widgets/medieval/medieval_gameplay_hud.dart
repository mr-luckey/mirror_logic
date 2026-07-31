import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';

/// Top carved-wood HUD: pause left, level centred, coins right; hint hangs
/// under the right edge so it stays reachable without crowding the bar.
class MedievalGameplayHud extends StatelessWidget {
  const MedievalGameplayHud({
    super.key,
    required this.levelIndex,
    required this.stars,
    required this.coins,
    required this.hintCost,
    required this.onPause,
    required this.onHint,
    required this.onAddCoins,
  });

  final int levelIndex;
  final int stars;
  final int coins;

  /// Price of the hint, or null once it has been paid for on this board.
  final int? hintCost;

  final VoidCallback onPause;
  final VoidCallback onHint;
  final VoidCallback onAddCoins;

  static const double _coinScale = 1.05;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5A4030),
                  Color(0xFF3A2818),
                  Color(0xFF1A1008),
                ],
              ),
              border: Border.all(
                color: MedievalColors.bronzeLight.withValues(alpha: 0.85),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: MedievalColors.bronzeHighlight.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                MedievalBronzeButton(
                  icon: Icons.pause_rounded,
                  size: 44,
                  onPressed: onPause,
                ),
                Expanded(
                  child: Center(
                    child: _LevelShield(levelIndex: levelIndex, stars: stars),
                  ),
                ),
                MedievalResourceChip(
                  icon: Icons.monetization_on,
                  label: '$coins',
                  glowColor: MedievalColors.bronzeHighlight,
                  scale: _coinScale,
                  onTap: onAddCoins,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _HintButton(cost: hintCost, onPressed: onHint),
          ),
        ],
      ),
    );
  }
}

/// A bronze bulb stud with its price stamped underneath.
///
/// The label lives below the button rather than inside it so the icon reads at
/// a glance and the cost never widens the control.
class _HintButton extends StatelessWidget {
  const _HintButton({required this.cost, required this.onPressed});

  final int? cost;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final price = cost;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MedievalBronzeButton(
          icon: Icons.lightbulb,
          size: 52,
          onPressed: onPressed,
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (price != null) ...[
              const Icon(
                Icons.monetization_on,
                size: 10,
                color: MedievalColors.bronzeHighlight,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              price == null ? 'SHOWN' : '$price',
              style: MedievalTextStyles.cinzel(
                size: 10,
                weight: FontWeight.w700,
                letterSpacing: 0.6,
                color: MedievalColors.textGold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LevelShield extends StatelessWidget {
  const _LevelShield({required this.levelIndex, required this.stars});

  final int levelIndex;
  final int stars;

  @override
  Widget build(BuildContext context) {
    // Wider for three-digit global numbers (101…1000).
    final wide = levelIndex >= 100;
    return CustomPaint(
      painter: const _ShieldPainter(),
      child: SizedBox(
        width: wide ? 78 : 64,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LEVEL',
              style: MedievalTextStyles.cinzel(
                size: 8,
                letterSpacing: 1,
                color: MedievalColors.textGold,
              ),
            ),
            Text(
              '$levelIndex',
              style: MedievalTextStyles.cinzelDecorative(
                size: wide ? 16 : 18,
                color: MedievalColors.textCream,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < stars;
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 11,
                  color: filled
                      ? MedievalColors.bronzeHighlight
                      : MedievalColors.bronze.withValues(alpha: 0.7),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 2)
      ..lineTo(size.width - 4, size.height * 0.22)
      ..lineTo(size.width - 6, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 2,
        6,
        size.height * 0.62,
      )
      ..lineTo(4, size.height * 0.22)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MedievalColors.bronzeHighlight,
          MedievalColors.bronzeMid,
          MedievalColors.bronzeDark,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final stroke = Paint()
      ..color = MedievalColors.bronzeLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, stroke);

    canvas.drawPath(
      path,
      Paint()
        ..color = MedievalColors.woodDeep.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );

    final inset = Path()
      ..moveTo(size.width * 0.5, 8)
      ..lineTo(size.width - 10, size.height * 0.26)
      ..lineTo(size.width - 11, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height - 6,
        11,
        size.height * 0.58,
      )
      ..lineTo(10, size.height * 0.26)
      ..close();
    canvas.drawPath(
      inset,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MedievalColors.woodLight.withValues(alpha: 0.55),
            MedievalColors.woodDeep.withValues(alpha: 0.85),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
