import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/rewarded_coins_cubit.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_coins_earned_dialog.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';

class MedievalInsufficientCoinsDialog extends StatelessWidget {
  const MedievalInsufficientCoinsDialog({
    super.key,
    required this.theme,
    required this.onPlayGame,
    required this.onWatchAd,
  });

  final VisualTheme theme;
  final VoidCallback onPlayGame;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final requiredCoins = theme.coinPrice;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.pageGutter(context),
          ),
          child: BlocBuilder<RewardedCoinsCubit, RewardedCoinsState>(
            buildWhen: (p, c) => p.coins != c.coins,
            builder: (context, rewardState) {
              final coins = rewardState.coins;
              final missing = (requiredCoins - coins).clamp(0, requiredCoins);

              return MedievalPanel(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 34,
                      color: MedievalColors.bronzeHighlight,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'NOT ENOUGH COINS',
                      textAlign: TextAlign.center,
                      style: MedievalTextStyles.cinzel(
                        size: Responsive.sp(context, 16),
                        weight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: MedievalColors.textGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      theme.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: MedievalTextStyles.cinzel(
                        size: Responsive.sp(context, 12),
                        color: theme.textGold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CoinRow(label: 'Required', value: '$requiredCoins'),
                    const SizedBox(height: 6),
                    _CoinRow(label: 'You have', value: '$coins'),
                    const SizedBox(height: 6),
                    _CoinRow(
                      label: 'Still need',
                      value: '$missing',
                      highlight: true,
                    ),
                    const SizedBox(height: 14),
                    BlocBuilder<RewardedCoinsCubit, RewardedCoinsState>(
                      buildWhen: (p, c) =>
                          p.quotaLabel != c.quotaLabel ||
                          p.canWatchAd != c.canWatchAd ||
                          p.adInProgress != c.adInProgress,
                      builder: (context, quotaState) {
                        final atLimit = !quotaState.canWatchAd;
                        return Column(
                          children: [
                            MedievalButton(
                              label: atLimit
                                  ? 'Ad limit reached'
                                  : 'Watch Ad to Earn',
                              style: MedievalButtonStyle.primary,
                              icon: Icons.ondemand_video_rounded,
                              shimmer: quotaState.canWatchAd,
                              brightWhenDisabled: atLimit,
                              onPressed:
                                  quotaState.canWatchAd &&
                                      !quotaState.adInProgress
                                  ? onWatchAd
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${quotaState.quotaLabel} ads today · +${GameConstants.coinsPerRewardedAd} coins each',
                              textAlign: TextAlign.center,
                              style: MedievalTextStyles.cinzel(
                                size: Responsive.sp(context, 10),
                                color: MedievalColors.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    MedievalButton(
                      label: 'Play Game',
                      icon: Icons.play_arrow_rounded,
                      onPressed: onPlayGame,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CoinRow extends StatelessWidget {
  const _CoinRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: MedievalTextStyles.cinzel(
              size: Responsive.sp(context, 11),
              color: MedievalColors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: MedievalTextStyles.cinzel(
            size: Responsive.sp(context, 12),
            weight: FontWeight.w700,
            color: highlight
                ? MedievalColors.bronzeHighlight
                : MedievalColors.textCream,
          ),
        ),
      ],
    );
  }
}

/// Puts the earn-coins dialog up for [theme].
///
/// [closeHostScreen] pops the screen underneath on the way to the board, which
/// the shop wants and the home carousel does not.
Future<void> showMedievalInsufficientCoinsDialog(
  BuildContext context, {
  required VisualTheme theme,
  bool closeHostScreen = false,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) =>
        BlocListener<RewardedCoinsCubit, RewardedCoinsState>(
          listenWhen: (p, c) => p.lastFeedback != c.lastFeedback,
          listener: (listenerContext, state) {
            final feedback = state.lastFeedback;
            if (feedback == null) return;

            switch (feedback) {
              case RewardedCoinsFeedback.earned:
                listenerContext.playSfx(Sfx.unlock);
                unawaited(
                  _celebrateReward(
                    dialogContext,
                    coins: state.coins,
                    price: theme.coinPrice,
                  ),
                );
              case RewardedCoinsFeedback.skipped:
                listenerContext.playSfx(Sfx.reject);
                MedievalToast.show(listenerContext, 'Ad skipped');
              case RewardedCoinsFeedback.unavailable:
                listenerContext.playSfx(Sfx.reject);
                MedievalToast.show(listenerContext, 'Ad unavailable right now');
              case RewardedCoinsFeedback.quotaReached:
                listenerContext.playSfx(Sfx.reject);
                MedievalToast.show(listenerContext, 'Daily ad limit reached');
            }
          },
          child: MedievalInsufficientCoinsDialog(
            theme: theme,
            onPlayGame: () {
              // The carousel may be previewing this locked hall; the board has
              // to open in the hall the player actually owns.
              context.read<ThemeCubit>().restoreEquippedTheme();
              final resume = context
                  .read<ProgressBloc>()
                  .state
                  .save
                  .continueLevelId;
              final router = GoRouter.of(context);
              Navigator.pop(dialogContext);
              if (closeHostScreen) router.pop();
              router.push('/play/$resume');
            },
            onWatchAd: () =>
                context.read<RewardedCoinsCubit>().watchAdForCoins(),
          ),
        ),
  );
}

/// Shows the reward receipt, then clears the way once the hall is affordable.
Future<void> _celebrateReward(
  BuildContext dialogContext, {
  required int coins,
  required int price,
}) async {
  await showMedievalCoinsEarnedDialog(
    dialogContext,
    earned: GameConstants.coinsPerRewardedAd,
    totalCoins: coins,
  );
  if (!dialogContext.mounted) return;
  if (coins >= price) Navigator.pop(dialogContext);
}
