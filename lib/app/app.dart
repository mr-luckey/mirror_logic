import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/ad_banner_host.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/app_update_scope.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/review_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/app/theme/app_theme.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/analytics/analytics_service.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/infrastructure/notifications/local_notification_service.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/economy/rewarded_coins_cubit.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';

class MirrorLogicApp extends StatefulWidget {
  const MirrorLogicApp({super.key});

  @override
  State<MirrorLogicApp> createState() => _MirrorLogicAppState();
}

class _MirrorLogicAppState extends State<MirrorLogicApp> {
  @override
  void initState() {
    super.initState();
    // After the first frame the Activity exists, so the permission dialog
    // and notification channel can be created correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapNotifications());
    });
  }

  Future<void> _bootstrapNotifications() async {
    final notifications = context.read<LocalNotificationService>();
    final analytics = context.read<AnalyticsService>();
    final count = await notifications.scheduleNotifications();
    if (count > 0) {
      unawaited(
        analytics.logNotificationScheduled(count: count, source: 'launch'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The save record is the single source of truth for coins, and ProgressBloc
    // is its only writer on level completion. Mirroring its balance here means
    // the HUD can never read a stale total mid-write.
    return MultiBlocListener(
      listeners: [
        BlocListener<ProgressBloc, ProgressState>(
          listenWhen: (p, c) => p.save.coins != c.save.coins,
          listener: (context, state) => context.read<EconomyBloc>().add(
            EconomyCoinsChanged(state.save.coins),
          ),
        ),
        BlocListener<ProgressBloc, ProgressState>(
          listenWhen: (p, c) =>
              p.save.unlockedLevelIds != c.save.unlockedLevelIds ||
              p.save.ownedThemeIds != c.save.ownedThemeIds ||
              p.save.selectedThemeId != c.save.selectedThemeId ||
              p.save.coins != c.save.coins,
          listener: (context, state) =>
              context.read<ThemeCubit>().syncFromSave(state.save),
        ),
        BlocListener<EconomyBloc, EconomyState>(
          listenWhen: (p, c) => p.coins != c.coins,
          listener: (context, state) {
            context.read<ThemeCubit>().syncCoins(state.coins);
            context.read<RewardedCoinsCubit>().syncCoins(state.coins);
          },
        ),
        BlocListener<RewardedCoinsCubit, RewardedCoinsState>(
          listenWhen: (p, c) => p.coins != c.coins,
          listener: (context, state) {
            context.read<EconomyBloc>().add(EconomyCoinsChanged(state.coins));
            context.read<ProgressBloc>().add(const ProgressRefresh());
          },
        ),
      ],
      child: AdsScope(
        ads: context.read<AdsService>(),
        child: AudioScope(
          audio: context.read<AudioService>(),
          child: ReviewScope(
            review: context.read<ReviewService>(),
            child: AppUpdateScope(
              updates: context.read<AppUpdateService>(),
              child: _Router(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Router extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // AudioScope stays above MaterialApp forever. Hall swaps only refresh
    // ThemeData + InheritedNotifier dependents — never the audio service.
    return MaterialApp.router(
      title: 'Mirror Logic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.2,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: ThemeScope(
            child: HallHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

/// Keeps Material [ThemeData] in sync with the equipped hall.
///
/// Uses [ListenableBuilder]'s `child` slot so the navigator element is not
/// recreated here (recreating it previously silenced audio). Page chrome is
/// refreshed by [MedievalWoodBackground] + [ThemeScope] instead.
class HallHost extends StatelessWidget {
  const HallHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.notifier,
      builder: (context, preserved) {
        return Theme(
          data: AppTheme.dark,
          child: AdBannerHost(child: preserved ?? const SizedBox.shrink()),
        );
      },
      child: child,
    );
  }
}
