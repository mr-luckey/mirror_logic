import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/app_update_gate.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/home/home_cubit.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';
import 'package:mirror_logic/presentation/screens/splash/splash_screen.dart'
    show GameTitle;
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_exit_scope.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_insufficient_coins_dialog.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_torch.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

/// Home hall carousel. Page index lives in [HomeCubit]; swipe only previews.
/// Continue / Play confirms the hall via [ThemeCubit.confirmHall].
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(
        selectedThemeId: context.read<ThemeCubit>().state.selectedThemeId,
      ),
      child: const _MainMenuView(),
    );
  }
}

class _MainMenuView extends StatefulWidget {
  const _MainMenuView();

  @override
  State<_MainMenuView> createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<_MainMenuView> with RouteAware {
  static final List<VisualTheme> _halls = ThemeCatalog.all;

  late final PageController _pageController;
  bool _routeSubscribed = false;

  /// True while [PageController] is jumped from code, not a finger swipe.
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    final initial = context.read<HomeCubit>().state;
    _pageController = PageController(
      initialPage: initial,
      viewportFraction: 0.92,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheThumbs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRouter.routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      AppRouter.routeObserver.unsubscribe(this);
    }
    _pageController.dispose();
    super.dispose();
  }

  /// Returning from play / chapters with no open preview → permanent hall.
  /// Returning from settings while previewing a locked hall → keep that preview.
  @override
  void didPopNext() {
    _reconcileCarouselAfterReturn();
  }

  void _reconcileCarouselAfterReturn() {
    if (!mounted) return;
    final theme = context.read<ThemeCubit>();
    if (theme.isPreviewing) return;

    final equippedId = theme.state.selectedThemeId;
    final index = HomeCubit.indexOf(equippedId);
    context.read<HomeCubit>().snapToTheme(equippedId);
    _jumpCarouselTo(index);
    theme.restoreEquippedTheme();
  }

  void _jumpCarouselTo(int index) {
    if (!_pageController.hasClients) return;
    final current = _pageController.page?.round() ?? index;
    if (current == index) return;
    _programmaticPage = true;
    _pageController.jumpToPage(index);
    _programmaticPage = false;
  }

  void _precacheThumbs() {
    if (!mounted) return;
    for (final hall in _halls) {
      precacheImage(AssetImage(hall.thumbAsset), context);
    }
  }

  void _onPageChanged(int index) {
    context.read<HomeCubit>().setPage(index);
    if (_programmaticPage) return;
    HapticFeedback.selectionClick();
    context.playSfx(Sfx.tap);
    // Preview only — permanent selection waits for Continue / Play.
    context.read<ThemeCubit>().previewHall(_halls[index].id);
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index.clamp(0, _halls.length - 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Do not ThemeController.watch here — mid-theme rebuilds of this shell
    // were fighting the PageView scroll. Wood / chrome watch on their own.
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final size = MediaQuery.sizeOf(context);

    return AppUpdateGate(
      child: MedievalExitScope(
        child: BlocListener<HomeCubit, int>(
          listenWhen: (p, c) => p != c,
          listener: (context, page) => _jumpCarouselTo(page),
          child: MedievalWoodBackground(
            child: Stack(
              children: [
                const _WallTorches(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 620;
                        final cardWidth = (size.width * 0.86).clamp(
                          260.0,
                          compact ? 340.0 : 380.0,
                        );
                        final heroHeight = cardWidth * 0.68;
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        final cacheWidth = (cardWidth * dpr).round();

                        final header = Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _TopStatusBar(),
                            SizedBox(height: short ? 6 : 10),
                            const GameTitle()
                                .animate()
                                .fadeIn(duration: 450.ms)
                                .slideY(begin: -0.08, end: 0),
                            const SizedBox(height: 6),
                            Text(
                              'Swipe to choose a hall',
                              style: MedievalTextStyles.cinzel(
                                color: MedievalColors.textMuted,
                                letterSpacing: 1.4,
                                size: Responsive.sp(context, 11),
                              ),
                            ),
                            SizedBox(height: short ? 10 : 14),
                          ],
                        );

                        final carousel = SizedBox(
                          height: heroHeight + 10,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: _halls.length,
                                allowImplicitScrolling: true,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (context, index) {
                                  final theme = _halls[index];
                                  return BlocBuilder<HomeCubit, int>(
                                    buildWhen: (p, c) =>
                                        p == index || c == index,
                                    builder: (context, page) {
                                      final active = page == index;
                                      return BlocBuilder<
                                        ThemeCubit,
                                        ThemeCubitState
                                      >(
                                        buildWhen: (p, c) =>
                                            p.owns(theme.id) !=
                                                c.owns(theme.id) ||
                                            p.selectedThemeId !=
                                                c.selectedThemeId,
                                        builder: (context, themeState) {
                                          final owned = themeState.owns(
                                            theme.id,
                                          );
                                          return AnimatedScale(
                                            scale: active ? 1.0 : 0.94,
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            child: Center(
                                              child: _ThemeHeroCard(
                                                theme: theme,
                                                width: cardWidth,
                                                height: heroHeight,
                                                cacheWidth: cacheWidth,
                                                locked: !owned,
                                                equipped: themeState.selected,
                                                onTap: () {
                                                  if (!owned) {
                                                    context.push('/themes');
                                                    return;
                                                  }
                                                  if (active) return;
                                                  _goTo(index);
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                              BlocBuilder<HomeCubit, int>(
                                builder: (context, page) {
                                  return Stack(
                                    children: [
                                      if (page > 0)
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: _HallChevron(
                                              direction: AxisDirection.left,
                                              onTap: () => _goTo(page - 1),
                                            ),
                                          ),
                                        ),
                                      if (page < _halls.length - 1)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: _HallChevron(
                                              direction: AxisDirection.right,
                                              onTap: () => _goTo(page + 1),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );

                        final footer = Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            BlocBuilder<HomeCubit, int>(
                              builder: (context, page) => _PageDots(
                                count: _halls.length,
                                index: page,
                              ),
                            ),
                            SizedBox(height: short ? 14 : 20),
                            const _PlayButtons(),
                          ],
                        );

                        if (compact) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                children: [header, carousel, footer],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            header,
                            Expanded(child: Center(child: carousel)),
                            footer,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeHeroCard extends StatelessWidget {
  const _ThemeHeroCard({
    required this.theme,
    required this.width,
    required this.height,
    required this.cacheWidth,
    required this.locked,
    required this.equipped,
    required this.onTap,
  });

  final VisualTheme theme;
  final double width;
  final double height;
  final int cacheWidth;
  final bool locked;

  /// Hall the player actually owns. The seal is painted from this rather than
  /// the previewed hall, so browsing locked halls never recolours the lock.
  final VisualTheme equipped;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1024,
              height: 682,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    theme.thumbAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: cacheWidth,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  if (locked) _ChapterStyleLockSeal(equipped: equipped),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same bronze seal used on locked chapter cards (scaled for home hero thumbs).
class _ChapterStyleLockSeal extends StatelessWidget {
  const _ChapterStyleLockSeal({required this.equipped});

  final VisualTheme equipped;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: equipped.woodDeep.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: equipped.bronzeMetal,
            border: Border.all(color: equipped.bronzeDark, width: 2.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(Icons.lock_rounded, size: 64, color: equipped.woodDeep),
        ),
      ),
    );
  }
}

class _HallChevron extends StatelessWidget {
  const _HallChevron({required this.direction, required this.onTap});

  final AxisDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final left = direction == AxisDirection.left;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MedievalColors.woodMid.withValues(alpha: 0.78),
            border: Border.all(
              color: MedievalColors.bronzeLight.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            left
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_forward_ios_rounded,
            size: 16,
            color: MedievalColors.textGold,
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active
                ? MedievalColors.bronzeHighlight
                : MedievalColors.textMuted.withValues(alpha: 0.35),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: MedievalColors.bronzeHighlight.withValues(
                        alpha: 0.45,
                      ),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _PlayButtons extends StatelessWidget {
  const _PlayButtons();

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return BlocBuilder<HomeCubit, int>(
      builder: (context, page) {
        final hall =
            ThemeCatalog.all[page.clamp(0, ThemeCatalog.all.length - 1)];
        return BlocBuilder<ThemeCubit, ThemeCubitState>(
          buildWhen: (p, c) =>
              p.owns(hall.id) != c.owns(hall.id) || p.coins != c.coins,
          builder: (context, themeState) {
            final hallLocked = !themeState.owns(hall.id);
            return BlocBuilder<ProgressBloc, ProgressState>(
              buildWhen: (p, c) =>
                  p.save.lastPlayedLevelId != c.save.lastPlayedLevelId ||
                  p.save.continueLevelId != c.save.continueLevelId,
              builder: (context, progress) {
                final last = progress.save.lastPlayedLevelId;

                return Column(
                  children: [
                    MedievalButton(
                      label: hallLocked
                          ? 'Locked · ${hall.coinPrice} coins'
                          : (last == null ? 'Play' : 'Continue'),
                      style: MedievalButtonStyle.primary,
                      icon: hallLocked
                          ? Icons.lock_rounded
                          : Icons.play_arrow_rounded,
                      shimmer: !hallLocked,
                      brightWhenDisabled: hallLocked,
                      onPressed: hallLocked
                          ? () => _unlockHall(
                              context,
                              hall: hall,
                              coins: themeState.coins,
                            )
                          : () => _continueWithHall(
                              context,
                              hallId: hall.id,
                              levelId: progress.save.continueLevelId,
                            ),
                    ),
                    if (!hallLocked) ...[
                      const SizedBox(height: 11),
                      MedievalButton(
                        label: 'Chapters',
                        icon: Icons.menu_book_rounded,
                        onPressed: () {
                          // Leaving without Continue drops any carousel preview.
                          context.read<ThemeCubit>().restoreEquippedTheme();
                          context.push('/chapters');
                        },
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Locks in the visible owned hall, then opens the continue level.
  Future<void> _continueWithHall(
    BuildContext context, {
    required String hallId,
    required String levelId,
  }) async {
    await context.read<ThemeCubit>().confirmHall(hallId);
    if (!context.mounted) return;
    // Keep ProgressBloc's in-memory save aligned with the equipped hall so a
    // later progress write cannot resurrect the previous theme id.
    context.read<ProgressBloc>().add(const ProgressRefresh());
    context.push('/play/$levelId');
  }

  /// Buys the hall outright when the purse allows, and otherwise opens the
  /// same earn-coins dialog the shop uses.
  Future<void> _unlockHall(
    BuildContext context, {
    required VisualTheme hall,
    required int coins,
  }) async {
    if (coins < hall.coinPrice) {
      context.playSfx(Sfx.reject);
      await showMedievalInsufficientCoinsDialog(context, theme: hall);
      return;
    }

    final themeCubit = context.read<ThemeCubit>();
    final result = await themeCubit.selectOrBuy(hall.id);
    if (!context.mounted) return;

    context.read<ProgressBloc>().add(const ProgressRefresh());
    context.read<EconomyBloc>().add(
      EconomyCoinsChanged(themeCubit.state.coins),
    );

    if (result == ThemeActionResult.purchased) {
      context.playSfx(Sfx.unlock);
      MedievalToast.show(context, 'Hall unlocked');
    }
  }
}

class _WallTorches extends StatelessWidget {
  const _WallTorches();

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final h = Responsive.hp(context, 0.14).clamp(80.0, 130.0);
    final top = Responsive.hp(context, 0.18);

    Widget torch({required bool flip}) => IgnorePointer(
      child: Opacity(
        opacity: 0.75,
        child: MedievalTorch(width: h * 0.55, height: h, flip: flip),
      ),
    );

    return Stack(
      children: [
        Positioned(left: -8, top: top, child: torch(flip: false)),
        Positioned(right: -8, top: top, child: torch(flip: true)),
      ],
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar();

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Column(
      children: [
        Row(
          children: [
            BlocBuilder<EconomyBloc, EconomyState>(
              buildWhen: (p, c) => p.coins != c.coins,
              builder: (context, eco) => MedievalResourceChip(
                icon: Icons.monetization_on_rounded,
                label: '${eco.coins}',
                glowColor: MedievalColors.bronzeHighlight,
              ),
            ),
            const Spacer(),
            MedievalBronzeButton(
              icon: Icons.settings_rounded,
              size: 34,
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        BlocBuilder<ProgressBloc, ProgressState>(
          buildWhen: (p, c) =>
              p.save.lastPlayedLevelId != c.save.lastPlayedLevelId,
          builder: (context, progress) {
            final last = progress.save.lastPlayedLevelId;
            return Text(
              last == null ? 'Level 1' : 'Level ${_labelFor(last)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MedievalTextStyles.cinzelDecorative(
                weight: FontWeight.w700,
                size: Responsive.sp(context, 22),
                color: MedievalColors.textGold,
                letterSpacing: 1.4,
              ),
            );
          },
        ),
      ],
    );
  }

  static String _labelFor(String levelId) {
    final match = RegExp(r'^ch(\d+)_(\d+)$').firstMatch(levelId);
    if (match == null) return levelId;
    final chapter = int.parse(match.group(1)!);
    final index = int.parse(match.group(2)!);
    return '${(chapter - 1) * 100 + index}';
  }
}
