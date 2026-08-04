import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _steps = [
    (
      Icons.touch_app_rounded,
      'Turn the mirrors',
      'Drag any mirror to swing it around its post. The beam redraws as you go.',
    ),
    (
      Icons.auto_awesome_rounded,
      'Feel the lock',
      'When the beam lines up on a target the mirror catches and the phone taps back.',
    ),
    (
      Icons.diamond_rounded,
      'Light the crystal',
      'Touch every mirror on the board on the way, or the crystal turns you away red.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final gutter = Responsive.pageGutter(context);
    final diagramHeight = Responsive.hp(context, 0.2).clamp(110.0, 190.0);

    return MedievalWoodBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
          child: Column(
            children: [
              const MedievalScreenHeader(
                title: 'How to Play',
                subtitle: 'The way of the light',
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MedievalPanel(
                                  padding: const EdgeInsets.all(10),
                                  child: MedievalPanel(
                                    style: MedievalPanelStyle.inset,
                                    radius: 8,
                                    padding: const EdgeInsets.all(8),
                                    child: SizedBox(
                                      height: diagramHeight,
                                      width: double.infinity,
                                      child: const CustomPaint(
                                        painter: _TutorialPainter(),
                                      ),
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.08, end: 0),
                            SizedBox(height: 14 * Responsive.scaleOf(context)),
                            for (var i = 0; i < _steps.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child:
                                    _StepRow(
                                          icon: _steps[i].$1,
                                          title: _steps[i].$2,
                                          body: _steps[i].$3,
                                        )
                                        .animate()
                                        .fadeIn(
                                          delay: (180 + i * 130).ms,
                                          duration: 420.ms,
                                        )
                                        .slideX(begin: 0.08, end: 0),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              MedievalButton(
                label: 'Enter the Keep',
                style: MedievalButtonStyle.primary,
                icon: Icons.play_arrow_rounded,
                shimmer: true,
                onPressed: () {
                  context.read<ProgressBloc>().add(
                    const ProgressOnboardingCompleted(),
                  );
                  context.go('/menu');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return MedievalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  MedievalColors.bronze.withValues(alpha: 0.5),
                  MedievalColors.woodDeep,
                ],
              ),
              border: Border.all(color: MedievalColors.bronzeDark, width: 1.4),
            ),
            child: Icon(icon, size: 17, color: MedievalColors.textGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 13),
                    weight: FontWeight.w700,
                    color: MedievalColors.textGold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 11.5),
                    height: 1.35,
                    color: MedievalColors.textCream.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPainter extends CustomPainter {
  const _TutorialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _drawStoneFloor(canvas, size);

    final emitter = Offset(size.width * 0.1, size.height * 0.26);
    final hinge = Offset(size.width * 0.46, size.height * 0.6);
    final crystal = Offset(size.width * 0.88, size.height * 0.3);

    _drawBeam(canvas, emitter, hinge);
    _drawBeam(canvas, hinge, crystal);

    // Mirror: the bar the player turns, drawn on the bisector of the two legs
    // so the reflection reads as physically correct.
    final inA = (hinge - emitter).direction;
    final outA = (crystal - hinge).direction;
    final normal = (inA + outA) / 2 + math.pi / 2;
    final half = size.shortestSide * 0.26;
    final arm = Offset(math.cos(normal), math.sin(normal)) * half;

    canvas.drawLine(
      hinge - arm,
      hinge + arm,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      hinge - arm,
      hinge + arm,
      Paint()
        ..shader = LinearGradient(
          colors: [
            MedievalColors.bronzeHighlight,
            MedievalColors.crystal,
            MedievalColors.bronze,
          ],
        ).createShader(Rect.fromCircle(center: hinge, radius: half))
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Rotation hint: an arc with a fingertip dot riding it.
    final arcRect = Rect.fromCircle(center: hinge, radius: half * 1.42);
    canvas.drawArc(
      arcRect,
      normal - 1.15,
      2.3,
      false,
      Paint()
        ..color = MedievalColors.bronzeLight.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final tipA = normal + 1.15;
    final tip = hinge + Offset(math.cos(tipA), math.sin(tipA)) * half * 1.42;
    canvas.drawCircle(tip, 5, Paint()..color = MedievalColors.bronzeHighlight);
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..color = MedievalColors.bronzeHighlight.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Hinge post
    canvas.drawCircle(hinge, 6, Paint()..color = MedievalColors.bronzeDark);
    canvas.drawCircle(hinge, 3, Paint()..color = MedievalColors.bronzeLight);

    _drawEmitter(canvas, emitter);
    _drawCrystal(canvas, crystal);
  }

  void _drawStoneFloor(Canvas canvas, Size size) {
    final tile = size.width / 7;
    final grout = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var x = tile; x < size.width; x += tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grout);
    }
    for (var y = tile; y < size.height; y += tile) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grout);
    }
  }

  void _drawBeam(Canvas canvas, Offset a, Offset b) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = MedievalColors.laserGlow.withValues(alpha: 0.28)
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = MedievalColors.laserMid
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = MedievalColors.laserCore
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEmitter(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      13,
      Paint()
        ..shader = RadialGradient(
          colors: [MedievalColors.bronzeLight, MedievalColors.bronzeDark],
        ).createShader(Rect.fromCircle(center: c, radius: 13)),
    );
    canvas.drawCircle(
      c,
      13,
      Paint()
        ..color = MedievalColors.bronzeHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 5, Paint()..color = MedievalColors.laserCore);
  }

  void _drawCrystal(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      24,
      Paint()
        ..color = MedievalColors.laserGlow.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final r = 13.0;
    final gem = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.72, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.72, c.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MedievalColors.laserCore, MedievalColors.crystalDeep],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..color = MedievalColors.bronzeLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
