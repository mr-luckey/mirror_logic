import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'dart:async';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final short = Responsive.isShort(context);
    final crestSize = Responsive.wp(
      context,
      short ? 0.44 : 0.54,
    ).clamp(150.0, 250.0);

    return MedievalWoodBackground(
      child: _SplashBootstrap(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(context),
            ),
            child: Column(
              children: [
                const Spacer(flex: 3),
                MedievalArtwork(
                      asset: MedievalArt.crest,
                      size: crestSize,
                      glow: MedievalColors.laserGlow,
                      glowStrength: 0.3,
                    )
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(0.86, 0.86),
                      curve: Curves.easeOutBack,
                    )
                    .then()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.035, 1.035),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
                SizedBox(height: short ? 20 : 32),
                const GameTitle(),
                SizedBox(height: short ? 6 : 10),
                Text(
                  'REFLECT  •  ALIGN  •  SOLVE',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 11),
                    letterSpacing: 3,
                    color: MedievalColors.textMuted,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
                const Spacer(flex: 3),
                const _ForgeBar(),
                SizedBox(height: short ? 28 : 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The engraved wordmark, shared by the splash and the main menu.
class GameTitle extends StatelessWidget {
  const GameTitle({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            'MIRROR LOGIC',
            maxLines: 1,
            textAlign: TextAlign.center,
            style:
                MedievalTextStyles.cinzelDecorative(
                  size: Responsive.sp(context, 30) * scale,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: MedievalColors.textGold,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: MedievalColors.bronzeHighlight.withValues(
                        alpha: 0.55,
                      ),
                      blurRadius: 22,
                    ),
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.14, end: 0);
  }
}

/// Loading bar styled as molten bronze running along a carved channel.
class _ForgeBar extends StatelessWidget {
  const _ForgeBar();

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.wp(context, 0.1)),
      child: Container(
        height: 10,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(
            color: MedievalColors.bronze.withValues(alpha: 0.7),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 4,
            backgroundColor: Colors.transparent,
            color: MedievalColors.bronzeHighlight,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
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
    // Warm catalog in background only. Parsing a large manifest on the UI
    // isolate can stall first navigation on slower devices.
    unawaited(
      context.read<LevelRepository>().preloadCatalog().catchError((_) {}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final onboarded = context
        .read<ProgressBloc>()
        .state
        .save
        .onboardingComplete;
    context.go(onboarded ? '/menu' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
