import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';
import 'package:mirror_logic/presentation/widgets/gold_cta_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);
    final diagramHeight = Responsive.hp(context, 0.22).clamp(120.0, 200.0);

    return AtmosphericBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 16),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'HOW TO PLAY',
                                maxLines: 1,
                                style: AppTextStyles.orbitron(
                                  size: Responsive.sp(context, 22),
                                  weight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GlassPanel(
                              glow: true,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: diagramHeight,
                                    width: double.infinity,
                                    child: const CustomPaint(
                                      painter: _TutorialPainter(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Drag a mirror to rotate it. The laser updates live — bounce the beam into the crystal.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.exo2(
                                      size: Responsive.sp(context, 15),
                                      height: 1.4,
                                      color: AppColors.textPrimary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .slideY(begin: 0.08, end: 0),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GoldCtaButton(
                label: 'Start Playing',
                width: double.infinity,
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  context
                      .read<ProgressBloc>()
                      .add(const ProgressOnboardingCompleted());
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

class _TutorialPainter extends CustomPainter {
  const _TutorialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final mirrorY = size.height * 0.55;
    final mirrorX = size.width * 0.45;

    // Laser beam
    final beamPaint = Paint()
      ..color = AppColors.hotPink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(20, size.height * 0.25), Offset(mirrorX, mirrorY), beamPaint);
    canvas.drawLine(Offset(mirrorX, mirrorY),
        Offset(size.width - 30, size.height * 0.3), beamPaint);

    // Beam glow
    canvas.drawLine(
      Offset(20, size.height * 0.25),
      Offset(mirrorX, mirrorY),
      Paint()
        ..color = AppColors.hotPink.withValues(alpha: 0.3)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Mirror
    canvas.drawLine(
      Offset(mirrorX - 40, mirrorY + 20),
      Offset(mirrorX + 40, mirrorY - 20),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Rotation arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(mirrorX, mirrorY), radius: 55),
      -0.8,
      1.6,
      false,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Crystal
    canvas.drawCircle(
      Offset(size.width - 36, size.height * 0.28),
      18,
      Paint()..color = AppColors.cyan,
    );
    canvas.drawCircle(
      Offset(size.width - 36, size.height * 0.28),
      24,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
