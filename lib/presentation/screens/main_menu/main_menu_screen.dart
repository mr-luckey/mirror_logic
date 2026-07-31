import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/screens/splash/splash_screen.dart'
    show GameTitle;
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_bronze_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_star_row.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_torch.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final crestSize =
        Responsive.wp(context, short ? 0.3 : 0.36).clamp(96.0, 168.0);

    return MedievalWoodBackground(
      child: Stack(
        children: [
          const _WallTorches(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 16),
              child: Column(
                children: [
                  const _TopStatusBar(),
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
                                SizedBox(height: short ? 10 : 22),
                                MedievalArtwork(
                                  asset: MedievalArt.crest,
                                  size: crestSize,
                                  glow: MedievalColors.laserGlow,
                                  glowStrength: 0.26,
                                )
                                    .animate()
                                    .fadeIn(duration: 550.ms)
                                    .scale(begin: const Offset(0.9, 0.9)),
                                SizedBox(height: short ? 10 : 16),
                                const GameTitle(),
                                const SizedBox(height: 8),
                                Text(
                                  'Reflect  •  Align  •  Solve',
                                  textAlign: TextAlign.center,
                                  style: MedievalTextStyles.cinzel(
                                    color: MedievalColors.textMuted,
                                    letterSpacing: 2,
                                    size: Responsive.sp(context, 12),
                                  ),
                                ),
                                SizedBox(height: short ? 26 : 40),
                                MedievalButton(
                                  label: 'Play',
                                  style: MedievalButtonStyle.primary,
                                  icon: Icons.play_arrow_rounded,
                                  shimmer: true,
                                  onPressed: () => context.push('/chapters'),
                                ).animate().fadeIn(delay: 250.ms).slideY(
                                      begin: 0.16,
                                      end: 0,
                                      curve: Curves.easeOutCubic,
                                    ),
                                SizedBox(height: short ? 14 : 22),
                                const _MenuGrid(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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

/// Torches bracketed to the wall behind the menu, flush with the screen edges.
class _WallTorches extends StatelessWidget {
  const _WallTorches();

  @override
  Widget build(BuildContext context) {
    final h = Responsive.hp(context, 0.16).clamp(90.0, 150.0);
    final top = Responsive.hp(context, 0.2);

    Widget torch({required bool flip}) => IgnorePointer(
          child: Opacity(
            opacity: 0.85,
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

class _MenuGrid extends StatelessWidget {
  const _MenuGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuTileData(
        icon: Icons.apartment_rounded,
        label: 'Building\nMode',
        locked: true,
        onTap: () => _soon(context),
      ),
      _MenuTileData(
        icon: Icons.calendar_today_rounded,
        label: 'Daily\nChallenge',
        locked: true,
        badge: true,
        onTap: () => _soon(context),
      ),
      _MenuTileData(
        icon: Icons.emoji_events_outlined,
        label: 'Achievements',
        locked: true,
        onTap: () => _soon(context),
      ),
      _MenuTileData(
        icon: Icons.bar_chart_rounded,
        label: 'Statistics',
        onTap: () => _showStats(context),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Responsive.isNarrow(context) ? 8.0 : 10.0;
        final tileWidth = (constraints.maxWidth - gap * 3) / 4;
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: tileWidth,
                child: _MenuTile(data: items[i])
                    .animate()
                    .fadeIn(delay: (350 + i * 90).ms, duration: 380.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
            ],
          ],
        );
      },
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Sealed until the next update')),
      );
  }

  void _showStats(BuildContext context) {
    final save = context.read<ProgressBloc>().state.save;
    final stars =
        save.levelProgress.values.fold<int>(0, (s, p) => s + p.stars);
    final completed =
        save.levelProgress.values.where((p) => p.completed).length;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(dialogContext),
            ),
            child: MedievalPanel(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHRONICLE',
                    style: MedievalTextStyles.cinzel(
                      size: Responsive.sp(context, 18),
                      weight: FontWeight.w700,
                      letterSpacing: 2.4,
                      color: MedievalColors.textGold,
                    ),
                  ),
                  const MedievalDivider(height: 18),
                  _StatLine(label: 'Levels cleared', value: '$completed'),
                  _StatLine(label: 'Stars earned', value: '$stars'),
                  _StatLine(label: 'Coins', value: '${save.coins}'),
                  const SizedBox(height: 16),
                  MedievalButton(
                    label: 'Close',
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MedievalTextStyles.cinzel(
              size: Responsive.sp(context, 13),
              color: MedievalColors.textMuted,
            ),
          ),
          Text(
            value,
            style: MedievalTextStyles.cinzelDecorative(
              size: Responsive.sp(context, 15),
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTileData {
  const _MenuTileData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;
  final bool badge;
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressBloc, ProgressState>(
      builder: (context, progress) {
        final stars = progress.save.levelProgress.values
            .fold<int>(0, (s, p) => s + p.stars);

        return MedievalPanel(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Flexible(
                child: MedievalPanel(
                  style: MedievalPanelStyle.inset,
                  radius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_moon_rounded,
                        color: MedievalColors.textGold,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Rank ${1 + (stars ~/ 9)}',
                          overflow: TextOverflow.ellipsis,
                          style: MedievalTextStyles.cinzel(
                            weight: FontWeight.w700,
                            size: Responsive.sp(context, 12),
                            color: MedievalColors.textGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const MedievalStarRow(filled: 3, size: 13, spacing: 1),
              const SizedBox(width: 3),
              Text(
                '$stars',
                style: MedievalTextStyles.cinzel(
                  weight: FontWeight.w700,
                  size: Responsive.sp(context, 12),
                ),
              ),
              const Spacer(),
              BlocBuilder<EconomyBloc, EconomyState>(
                builder: (context, eco) => MedievalResourceChip(
                  icon: Icons.monetization_on_rounded,
                  label: '${eco.coins}',
                  glowColor: MedievalColors.bronzeHighlight,
                ),
              ),
              const SizedBox(width: 8),
              MedievalBronzeButton(
                icon: Icons.settings_rounded,
                size: 34,
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.data});

  final _MenuTileData data;

  @override
  Widget build(BuildContext context) {
    final iconSize = Responsive.sp(context, 21).clamp(17.0, 25.0);
    final fontSize = Responsive.sp(context, 9.5).clamp(8.5, 11.5);

    return MedievalPressable(
      onPressed: data.onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: data.locked
                  ? [
                      MedievalColors.woodMid.withValues(alpha: 0.75),
                      MedievalColors.woodDeep,
                    ]
                  : const [Color(0xFF5A4030), Color(0xFF2A1B0F)],
            ),
            border: Border.all(
              color: data.locked
                  ? MedievalColors.bronzeDark.withValues(alpha: 0.7)
                  : MedievalColors.bronzeLight.withValues(alpha: 0.75),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.icon,
                        color: data.locked
                            ? MedievalColors.textMuted.withValues(alpha: 0.6)
                            : MedievalColors.textGold,
                        size: iconSize,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MedievalTextStyles.cinzel(
                          size: fontSize,
                          height: 1.15,
                          weight: FontWeight.w600,
                          color: data.locked
                              ? MedievalColors.textMuted
                              : MedievalColors.textCream,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.badge)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MedievalColors.greenPlus,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MedievalColors.greenPlus
                                .withValues(alpha: 0.8),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (data.locked)
                  Positioned(
                    right: 1,
                    top: 1,
                    child: Image.asset(
                      MedievalArt.padlock,
                      width: 13,
                      height: 13,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
