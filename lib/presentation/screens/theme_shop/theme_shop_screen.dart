import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_resource_chip.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

class ThemeShopScreen extends StatelessWidget {
  const ThemeShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final gutter = Responsive.pageGutter(context);

    return MedievalWoodBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
          child: Column(
            children: [
              MedievalScreenHeader(
                title: 'Theme Halls',
                onBack: () => context.pop(),
              ),
              BlocBuilder<EconomyBloc, EconomyState>(
                buildWhen: (p, c) => p.coins != c.coins,
                builder: (context, eco) => Align(
                  alignment: Alignment.centerRight,
                  child: MedievalResourceChip(
                    icon: Icons.monetization_on_rounded,
                    label: '${eco.coins}',
                    glowColor: MedievalColors.bronzeHighlight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Equip a hall — the whole game follows its look.',
                textAlign: TextAlign.center,
                style: MedievalTextStyles.cinzel(
                  size: Responsive.sp(context, 11),
                  color: MedievalColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: BlocBuilder<ThemeCubit, ThemeCubitState>(
                  builder: (context, themeState) {
                    return ListView.separated(
                      itemCount: ThemeCatalog.all.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final theme = ThemeCatalog.all[index];
                        return _ThemeCard(
                          theme: theme,
                          index: index + 1,
                          owned: themeState.owns(theme.id),
                          selected: themeState.selectedThemeId == theme.id,
                          levelUnlocked: themeState.isLevelUnlocked(theme),
                          coins: themeState.coins,
                        )
                            .animate()
                            .fadeIn(delay: (40 * index).ms)
                            .slideY(begin: 0.08, end: 0);
                      },
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.index,
    required this.owned,
    required this.selected,
    required this.levelUnlocked,
    required this.coins,
  });

  final VisualTheme theme;
  final int index;
  final bool owned;
  final bool selected;
  final bool levelUnlocked;
  final int coins;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final locked = !levelUnlocked && !owned;
    final canBuy = levelUnlocked && !owned;
    final afford = coins >= theme.coinPrice;

    return MedievalPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IndexBadge(index: index, color: theme.bronzeHighlight),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MedievalTextStyles.cinzelDecorative(
                        size: Responsive.sp(context, 14),
                        color: theme.textGold,
                        weight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? 'Unlock at Level ${theme.unlockLevel}'
                          : owned
                              ? (selected ? 'Equipped' : 'Owned')
                              : '${theme.coinPrice} coins',
                      style: MedievalTextStyles.cinzel(
                        size: Responsive.sp(context, 10),
                        color: MedievalColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.laserMid,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _ThemePreview(theme: theme, locked: !owned),
          const SizedBox(height: 12),
          if (locked)
            MedievalButton(
              label: 'Locked · Lv ${theme.unlockLevel}',
              icon: Icons.lock_rounded,
              brightWhenDisabled: true,
              onPressed: null,
            )
          else if (owned)
            MedievalButton(
              label: selected ? 'Equipped' : 'Equip',
              style: selected
                  ? MedievalButtonStyle.secondary
                  : MedievalButtonStyle.primary,
              icon: selected ? Icons.check_rounded : Icons.palette_rounded,
              onPressed: selected
                  ? null
                  : () => _act(context, theme.id),
            )
          else
            MedievalButton(
              label: canBuy
                  ? (afford ? 'Buy · ${theme.coinPrice}' : 'Need ${theme.coinPrice}')
                  : 'Buy',
              style: MedievalButtonStyle.primary,
              icon: Icons.monetization_on_rounded,
              shimmer: afford,
              brightWhenDisabled: canBuy && !afford,
              onPressed: afford ? () => _act(context, theme.id) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, String themeId) async {
    final result = await context.read<ThemeCubit>().selectOrBuy(themeId);
    if (!context.mounted) return;

    // Keep ProgressBloc / EconomyBloc in sync after a purchase spends coins.
    context.read<ProgressBloc>().add(const ProgressRefresh());
    final coins = context.read<ThemeCubit>().state.coins;
    context.read<EconomyBloc>().add(EconomyCoinsChanged(coins));

    switch (result) {
      case ThemeActionResult.purchased:
        context.playSfx(Sfx.unlock);
        MedievalToast.show(context, 'Theme purchased');
      case ThemeActionResult.equipped:
      case ThemeActionResult.alreadyOwned:
        context.playSfx(Sfx.tap);
        MedievalToast.show(context, 'Theme equipped');
      case ThemeActionResult.locked:
        context.playSfx(Sfx.reject);
        MedievalToast.show(context, 'Reach the unlock level first');
      case ThemeActionResult.unaffordable:
        context.playSfx(Sfx.reject);
        MedievalToast.show(context, 'Not enough coins');
    }
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$index',
        style: MedievalTextStyles.cinzelDecorative(
          size: 14,
          color: MedievalColors.parchmentInk,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.locked});

  final VisualTheme theme;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final w = MediaQuery.sizeOf(context).width;
    final h = (w * 0.42).clamp(120.0, 168.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              theme.thumbAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => ColoredBox(color: theme.woodDeep),
            ),
            if (locked)
              ColoredBox(
                color: MedievalColors.woodDeep.withValues(alpha: 0.45),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MedievalColors.bronzeMetal,
                      border: Border.all(
                        color: MedievalColors.bronzeDark,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 22,
                      color: MedievalColors.woodDeep,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
