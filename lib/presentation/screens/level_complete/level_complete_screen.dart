import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/review_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_rate_dialog.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

class LevelCompleteArgs {
  const LevelCompleteArgs({
    required this.levelId,
    required this.chapterId,
    required this.levelIndex,
    required this.stars,
    required this.moves,
    required this.timeSeconds,
    required this.coinsEarned,
    this.nextLevelId,
  });

  final String levelId;
  final String chapterId;
  final int levelIndex;
  final int stars;
  final int moves;
  final double timeSeconds;
  final int coinsEarned;
  final String? nextLevelId;
}

class LevelCompleteScreen extends StatefulWidget {
  const LevelCompleteScreen({super.key, required this.args});

  final LevelCompleteArgs args;

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen> {
  static const _rank = ['Cleared', 'Well Struck', 'Masterful', 'Flawless'];

  /// Matches the wreath and stat-panel entrance animations.
  static const _firstStarDelay = Duration(milliseconds: 620);
  static const _starGap = Duration(milliseconds: 230);
  static const _coinDelay = Duration(milliseconds: 900);

  /// After the star fanfare lands and before the player taps Next — the WOW
  /// beat Play's guidance wants for a rating ask.
  static const _ratePromptDelay = Duration(milliseconds: 1400);

  final List<Timer> _fanfare = [];

  LevelCompleteArgs get args => widget.args;

  bool _clearCounted = false;

  /// [ReviewService] said yes; dialog not shown yet (timer or early Next).
  bool _ratePending = false;
  int _rateCleared = 0;
  bool _rateInFlight = false;

  @override
  void initState() {
    super.initState();
    _scheduleFanfare();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The clear counts towards the next interstitial here rather than on the
    // board, because this screen is the only place every finished level lands.
    // It waits for didChangeDependencies because reading a scope in initState
    // is not allowed.
    if (_clearCounted) return;
    _clearCounted = true;
    context.ads?.registerLevelCleared();
    _scheduleRatePrompt();
  }

  /// Unique clears on the save, including this board even if [ProgressBloc]
  /// has not emitted the write yet (completion is fire-and-forget before nav).
  int _completedClears() {
    final save = context.read<ProgressBloc>().state.save;
    final completed = save.levelProgress.values.where((p) => p.completed).length;
    final thisDone = save.levelProgress[args.levelId]?.completed ?? false;
    return thisDone ? completed : completed + 1;
  }

  /// Considers asking for a rating after the stars land, before Next.
  ///
  /// Level complete is the app's WOW moment. First ask after seven unique
  /// clears, then again every 5–10 clears. A fast Next tap still sees it —
  /// [_leave] flushes a pending ask before navigating away.
  void _scheduleRatePrompt() {
    final review = context.review;
    if (review == null) return;

    final cleared = _completedClears();
    if (!review.shouldAskNow(levelsCleared: cleared)) return;

    _ratePending = true;
    _rateCleared = cleared;
    _fanfare.add(
      Timer(_ratePromptDelay, () => unawaited(_presentRateIfPending())),
    );
  }

  Future<void> _presentRateIfPending() async {
    if (!_ratePending || _rateInFlight) return;
    _rateInFlight = true;

    try {
      final review = context.review;
      if (!mounted || review == null) {
        _ratePending = false;
        return;
      }
      // An interstitial can be on screen if the player tapped through already;
      // stacking a dialog under a native ad activity loses the dialog. Keep the
      // ask pending so a later clear can try again — do not burn the budget.
      if (context.ads?.isFullScreenAdShowing ?? false) return;

      _ratePending = false;
      await review.recordAsked(levelsCleared: _rateCleared);
      if (!mounted) return;

      final accepted = await showMedievalRateDialog(context);
      if (!accepted || !mounted) return;

      // The player is handed off to Play from here, which reports nothing back
      // about what they did, so this is the last time we ask either way.
      await review.markSettled();
      final opened = await review.promptForRating();
      if (!opened && mounted) {
        MedievalToast.show(context, 'Could not open the Play Store');
      }
    } finally {
      _rateInFlight = false;
    }
  }

  /// Leaves the results screen, giving an interstitial the gap on the way out.
  ///
  /// Between two levels is the one moment in this game where a full-screen ad
  /// interrupts nothing: the board is finished, the reward is already written to
  /// the save, and the player has not started thinking about the next puzzle
  /// yet. Next Level waits for the level cadence; Replay / Levels / Home only
  /// honour the quiet period so ads never stack back-to-back.
  Future<void> _leave(
    String route, {
    required bool replace,
    InterstitialPolicy policy = InterstitialPolicy.levelBreak,
  }) async {
    // Next before the timer must not cancel the WOW ask.
    if (_ratePending || _rateInFlight) {
      await _presentRateIfPending();
      if (!mounted) return;
    }
    await context.ads?.showInterstitial(policy: policy);
    if (!mounted) return;
    if (replace) {
      context.pushReplacement(route);
    } else {
      context.go(route);
    }
  }

  /// Each star chimes as it lands, then the coin reward lands on top.
  void _scheduleFanfare() {
    for (var i = 0; i < args.stars; i++) {
      _fanfare.add(
        Timer(_firstStarDelay + _starGap * i, () => _play(Sfx.star)),
      );
    }
    if (args.coinsEarned > 0) {
      _fanfare.add(Timer(_coinDelay, () => _play(Sfx.coin)));
    }
  }

  void _play(Sfx sfx) {
    if (!mounted) return;
    context.playSfx(sfx);
  }

  @override
  void dispose() {
    for (final timer in _fanfare) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final time = args.timeSeconds;
    final timeLabel =
        '${time.floor() ~/ 60}:${(time.floor() % 60).toString().padLeft(2, '0')}';
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final wreath = Responsive.wp(
      context,
      short ? 0.5 : 0.6,
    ).clamp(180.0, 300.0);

    // The board behind this screen is frozen in its solved state, so back has
    // to go somewhere useful instead of returning to it. Deliberately ad-free:
    // a player reaching for the system back button is trying to get out, and
    // the cadence counter keeps its place for whenever they next tap through.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/levels/${args.chapterId}');
      },
      child: MedievalWoodBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
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
                        _Trophy(size: wreath, stars: args.stars),
                        SizedBox(height: short ? 8 : 14),
                        Text(
                              _rank[args.stars.clamp(0, 3)].toUpperCase(),
                              maxLines: 1,
                              style:
                                  MedievalTextStyles.cinzelDecorative(
                                    size: Responsive.sp(context, 21),
                                    weight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: MedievalColors.textGold,
                                  ).copyWith(
                                    shadows: [
                                      Shadow(
                                        color: MedievalColors.bronzeHighlight
                                            .withValues(alpha: 0.6),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                            )
                            .animate()
                            .fadeIn(delay: 550.ms)
                            .slideY(
                              begin: 0.25,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),
                        const SizedBox(height: 4),
                        Text(
                          'Level ${args.levelIndex}',
                          style: MedievalTextStyles.cinzel(
                            size: Responsive.sp(context, 11),
                            letterSpacing: 2,
                            color: MedievalColors.textMuted,
                          ),
                        ).animate().fadeIn(delay: 650.ms),
                        SizedBox(height: short ? 14 : 20),
                        MedievalPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Column(
                                children: [
                                  _stat(context, 'Moves', '${args.moves}'),
                                  const MedievalDivider(),
                                  _stat(context, 'Time', timeLabel),
                                  const MedievalDivider(),
                                  _stat(
                                    context,
                                    'Coin',
                                    '+${args.coinsEarned}',
                                    highlight: true,
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 750.ms)
                            .slideY(begin: 0.1, end: 0),
                        SizedBox(height: short ? 16 : 24),
                        if (args.nextLevelId != null) ...[
                          MedievalButton(
                            label: 'Next Level',
                            style: MedievalButtonStyle.primary,
                            icon: Icons.arrow_forward_rounded,
                            shimmer: true,
                            onPressed: () => _leave(
                              '/play/${args.nextLevelId}',
                              replace: true,
                            ),
                          ).animate().fadeIn(delay: 900.ms),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: MedievalButton(
                                label: 'Replay',
                                icon: Icons.refresh_rounded,
                                onPressed: () => _leave(
                                  '/play/${args.levelId}',
                                  replace: true,
                                  policy: InterstitialPolicy.quietPeriod,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MedievalButton(
                                label: 'Levels',
                                icon: Icons.grid_view_rounded,
                                sfx: Sfx.back,
                                onPressed: () => _leave(
                                  '/levels/${args.chapterId}',
                                  replace: false,
                                  policy: InterstitialPolicy.quietPeriod,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 1000.ms),
                        const SizedBox(height: 10),
                        // Without this the only way back to the menu is walking
                        // the whole level/chapter stack back up.
                        MedievalButton(
                          label: 'Home',
                          icon: Icons.home_rounded,
                          sfx: Sfx.back,
                          onPressed: () => _leave(
                            '/menu',
                            replace: false,
                            policy: InterstitialPolicy.quietPeriod,
                          ),
                        ).animate().fadeIn(delay: 1050.ms),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: MedievalTextStyles.cinzel(
                color: MedievalColors.textMuted,
                letterSpacing: 1.6,
                size: Responsive.sp(context, 11),
              ),
            ),
          ),
          Text(
            value,
            style: MedievalTextStyles.cinzelDecorative(
              weight: FontWeight.w700,
              size: Responsive.sp(context, 17),
              color: highlight
                  ? MedievalColors.bronzeHighlight
                  : MedievalColors.textCream,
            ),
          ),
        ],
      ),
    );
  }
}

/// The laurel wreath with the earned stars set inside its opening.
class _Trophy extends StatelessWidget {
  const _Trophy({required this.size, required this.stars});

  final double size;
  final int stars;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final starSize = size * 0.17;

    return SizedBox(
      width: size,
      height: size * 0.92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MedievalArtwork(
                asset: MedievalArt.wreath,
                size: size,
                glow: MedievalColors.bronzeHighlight,
                glowStrength: 0.48,
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack)
              .then()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.02, 1.02),
                duration: 2400.ms,
              ),
          Align(
            alignment: const Alignment(0, -0.18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final lit = i < stars;
                // The middle star sits proud of the other two.
                final scale = i == 1 ? 1.24 : 1.0;
                return Padding(
                  padding: EdgeInsets.only(
                    left: 2,
                    right: 2,
                    bottom: i == 1 ? starSize * 0.22 : 0,
                  ),
                  child:
                      Icon(
                            lit
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: starSize * scale,
                            color: lit
                                ? MedievalColors.bronzeHighlight
                                : MedievalColors.bronzeDark,
                            shadows: lit
                                ? [
                                    Shadow(
                                      color: MedievalColors.bronzeHighlight
                                          .withValues(alpha: 0.85),
                                      blurRadius: 18,
                                    ),
                                  ]
                                : null,
                          )
                          .animate(delay: (320 + 170 * i).ms)
                          .scale(
                            begin: const Offset(0.2, 0.2),
                            end: const Offset(1, 1),
                            curve: Curves.elasticOut,
                            duration: 700.ms,
                          )
                          .fadeIn(duration: 200.ms),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
