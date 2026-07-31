import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';

/// Top HUD: pause left, level centred, coins right, all on one line.
///
/// There is no panel behind it — the wood backdrop already reads as a frame,
/// and a second one stole board height on short phones. The hint lives down on
/// the board instead, next to the thing it explains.
class MedievalGameplayHud extends StatelessWidget {
  const MedievalGameplayHud({
    super.key,
    required this.levelIndex,
    required this.stars,
    required this.coins,
    required this.onPause,
    required this.onAddCoins,
  });

  final int levelIndex;
  final int stars;
  final int coins;
  final VoidCallback onPause;
  final VoidCallback onAddCoins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MedievalBronzeButton(
            icon: Icons.pause_rounded,
            size: 40,
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
            onTap: onAddCoins,
          ),
        ],
      ),
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
        width: wide ? 72 : 60,
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LEVEL',
              style: MedievalTextStyles.cinzel(
                size: 7.5,
                letterSpacing: 1,
                color: MedievalColors.textGold,
              ),
            ),
            Text(
              '$levelIndex',
              style: MedievalTextStyles.cinzelDecorative(
                size: wide ? 15 : 17,
                color: MedievalColors.textCream,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < stars;
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 10,
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
