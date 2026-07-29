import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final short = Responsive.isShort(context);
    final titleSize = Responsive.sp(context, 32).clamp(24.0, 36.0);
    final crystalSize = Responsive.wp(context, short ? 0.36 : 0.42)
        .clamp(120.0, 180.0);

    return AtmosphericBackground(
      child: _SplashBootstrap(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(context),
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'MIRROR LOGIC',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: GoogleFonts.orbitron(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: AppColors.textPrimary,
                      shadows: [
                        Shadow(
                          color: AppColors.accentBright.withValues(alpha: 0.7),
                          blurRadius: 24,
                        ),
                        Shadow(
                          color: AppColors.hotPink.withValues(alpha: 0.4),
                          blurRadius: 48,
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.15, end: 0),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'REFLECT  •  ALIGN  •  SOLVE',
                    maxLines: 1,
                    style: GoogleFonts.exo2(
                      letterSpacing: 2,
                      color: AppColors.muted,
                      fontSize: Responsive.sp(context, 12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                SizedBox(height: short ? 24 : 40),
                SizedBox(
                  width: crystalSize,
                  height: crystalSize,
                  child: const CustomPaint(painter: _CrystalPainter()),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.96, 0.96),
                      end: const Offset(1.04, 1.04),
                      duration: 1600.ms,
                      curve: Curves.easeInOut,
                    ),
                const Spacer(flex: 3),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.wp(context, 0.08),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.panel,
                      color: AppColors.accentBright,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),
                SizedBox(height: short ? 28 : 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashBootstrap extends StatefulWidget {
  const _SplashBootstrap({required this.child});
  final Widget child;

  @override
  State<_SplashBootstrap> createState() => _SplashBootstrapState();
}

class _SplashBootstrapState extends State<_SplashBootstrap> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await context.read<LevelRepository>().preloadCatalog();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final onboarded =
        context.read<ProgressBloc>().state.save.onboardingComplete;
    context.go(onboarded ? '/menu' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CrystalPainter extends CustomPainter {
  const _CrystalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;

    // Outer glow
    canvas.drawCircle(
      c,
      r * 1.3,
      Paint()
        ..color = AppColors.accentBright.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );
    canvas.drawCircle(
      c,
      r * 1.1,
      Paint()
        ..color = AppColors.hotPink.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.85, c.dy - r * 0.18)
      ..lineTo(c.dx + r * 0.55, c.dy + r * 0.85)
      ..lineTo(c.dx - r * 0.55, c.dy + r * 0.85)
      ..lineTo(c.dx - r * 0.85, c.dy - r * 0.18)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.accentBright,
            AppColors.hotPink,
            AppColors.accent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    // Laser hint line
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.72),
      Offset(c.dx - r * 0.35, c.dy + r * 0.15),
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.8)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
