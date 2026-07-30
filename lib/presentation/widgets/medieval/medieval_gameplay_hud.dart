import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';

/// Top carved-wood HUD: pause, chapter, level shield, coins, hints.
class MedievalGameplayHud extends StatelessWidget {
  const MedievalGameplayHud({
    super.key,
    required this.chapterLabel,
    required this.chapterTitle,
    required this.levelIndex,
    required this.stars,
    required this.coins,
    required this.hintsLabel,
    required this.onPause,
    required this.onHint,
    required this.onAddCoins,
  });

  final String chapterLabel;
  final String chapterTitle;
  final int levelIndex;
  final int stars;
  final int coins;
  final String hintsLabel;
  final VoidCallback onPause;
  final VoidCallback onHint;
  final VoidCallback onAddCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MedievalBronzeButton(
            icon: Icons.pause_rounded,
            size: 44,
            onPressed: onPause,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    MedievalColors.bronzeDark.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
                border: Border.all(
                  color: MedievalColors.bronze.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapterLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedievalTextStyles.cinzel(
                      size: 9,
                      letterSpacing: 1.2,
                      color: MedievalColors.textGold,
                    ),
                  ),
                  Text(
                    chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedievalTextStyles.cinzel(
                      size: 13,
                      weight: FontWeight.w700,
                      color: MedievalColors.textCream,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _LevelShield(levelIndex: levelIndex, stars: stars),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MedievalResourceChip(
                    icon: Icons.monetization_on,
                    label: '$coins',
                    glowColor: MedievalColors.bronzeHighlight,
                    onAdd: onAddCoins,
                  ),
                  const SizedBox(width: 6),
                  MedievalResourceChip(
                    icon: Icons.lightbulb,
                    label: hintsLabel,
                    glowColor: MedievalColors.laserMid,
                    onAdd: onHint,
                  ),
                ],
              ),
            ),
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
    return CustomPaint(
      painter: const _ShieldPainter(),
      child: SizedBox(
        width: 64,
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
                size: 18,
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
