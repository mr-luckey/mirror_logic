import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';
import 'package:mirror_logic/presentation/widgets/gold_cta_button.dart';
import 'package:mirror_logic/presentation/widgets/star_row.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final titleSize =
        Responsive.sp(context, short ? 34 : 42).clamp(28.0, 44.0);

    return AtmosphericBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
          child: Column(
            children: [
              const _TopStatusBar(),
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
                            SizedBox(height: short ? 24 : 48),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.accentBright,
                                    AppColors.hotPink,
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'MIRROR\nLOGIC',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.orbitron(
                                    fontSize: titleSize,
                                    height: 1.05,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(
                                  begin: const Offset(0.94, 0.94),
                                  end: const Offset(1, 1),
                                ),
                            const SizedBox(height: 8),
                            Text(
                              'Reflect  •  Align  •  Solve',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.exo2(
                                color: AppColors.muted,
                                letterSpacing: 1.2,
                                size: Responsive.sp(context, 14),
                              ),
                            ),
                            SizedBox(height: short ? 32 : 48),
                            GoldCtaButton(
                              label: 'Play',
                              width: double.infinity,
                              icon: Icons.play_arrow_rounded,
                              onPressed: () => context.push('/chapters'),
                            )
                                .animate(
                                    onPlay: (c) => c.repeat(reverse: true))
                                .shimmer(
                                  delay: 900.ms,
                                  duration: 1800.ms,
                                  color: Colors.white24,
                                ),
                            SizedBox(height: short ? 16 : 24),
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
        final gap = Responsive.isNarrow(context) ? 8.0 : 12.0;
        final tileWidth = (constraints.maxWidth - gap * 3) / 4;
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: tileWidth,
                child: _MenuTile(data: items[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming in the next update')),
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
      builder: (dialogContext) => AlertDialog(
        title: Text('Statistics', style: AppTextStyles.orbitron()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Levels cleared: $completed',
                style: AppTextStyles.exo2(color: AppColors.textPrimary)),
            Text('Total stars: $stars',
                style: AppTextStyles.exo2(color: AppColors.textPrimary)),
            Text('Coins: ${save.coins}',
                style: AppTextStyles.exo2(color: AppColors.textPrimary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
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
        return Row(
          children: [
            Flexible(
              child: GlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                borderRadius: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.military_tech,
                      color: AppColors.accentBright,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Lv ${1 + (stars ~/ 9)}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.exo2(
                          weight: FontWeight.w700,
                          size: Responsive.sp(context, 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const StarRow(filled: 3, size: 14),
            const SizedBox(width: 2),
            Text(
              '$stars',
              style: AppTextStyles.exo2(
                weight: FontWeight.w700,
                size: Responsive.sp(context, 13),
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<EconomyBloc, EconomyState>(
              builder: (context, eco) {
                return Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: CurrencyChip(coins: eco.coins),
                  ),
                );
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_rounded,
                  color: AppColors.textPrimary),
            ),
          ],
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
    final iconSize = Responsive.sp(context, 22).clamp(18.0, 26.0);
    final fontSize = Responsive.sp(context, 10).clamp(9.0, 12.0);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: data.locked ? null : AppColors.cardGradient,
          color: data.locked ? AppColors.panel.withValues(alpha: 0.5) : null,
          border: Border.all(
            color: data.locked
                ? AppColors.glassBorder
                : AppColors.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: data.onTap,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            data.icon,
                            color: data.locked
                                ? AppColors.muted
                                : AppColors.accent,
                            size: iconSize,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.exo2(
                              size: fontSize,
                              height: 1.1,
                              weight: FontWeight.w600,
                              color: data.locked
                                  ? AppColors.muted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.badge)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.hotPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (data.locked)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child:
                          Icon(Icons.lock, size: 11, color: AppColors.muted),
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
