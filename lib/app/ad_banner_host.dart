import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/presentation/blocs/ad_banner/ad_banner_cubit.dart';
import 'package:mirror_logic/presentation/widgets/ads/ad_banner_slot.dart';

/// Lays the bottom banner under whichever screen is on top.
///
/// One strip for the whole app. Unity first, then Meta, looping until a fill
/// sticks. Hides only while a full-screen ad is up or on splash/onboarding.
class AdBannerHost extends StatelessWidget {
  const AdBannerHost({super.key, required this.child});

  final Widget child;

  /// Whether the route at [location] carries a banner.
  static bool showsBannerAt(String location) =>
      !location.startsWith('/splash') && !location.startsWith('/onboarding');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdBannerCubit(ads: context.read<AdsService>()),
      child: _AdBannerBody(child: child),
    );
  }
}

class _AdBannerBody extends StatelessWidget {
  const _AdBannerBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdBannerCubit, AdBannerState>(
      builder: (context, state) {
        final cubit = context.read<AdBannerCubit>();
        final selection = state.selection;
        final location =
            AppRouter.router.routerDelegate.currentConfiguration.uri.path;
        final isGameplayScreen = location.startsWith('/play/');

        // Mount as soon as a candidate is chosen so Unity/Meta can load.
        // Keep the same key across load→loaded so the fill is not destroyed.
        if (!state.show || selection == null) return child;

        final banner = AdBannerSlot(
          key: ValueKey('${selection.mountKey}-${state.mountGeneration}'),
          selection: selection,
          onLoaded: cubit.onBannerLoaded,
          onFailed: cubit.onBannerFailed,
        );

        if (isGameplayScreen) {
          return Stack(
            children: [
              child,
              Positioned(left: 0, right: 0, bottom: 0, child: banner),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: child,
              ),
            ),
            banner,
          ],
        );
      },
    );
  }
}
