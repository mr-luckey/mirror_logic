import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/presentation/blocs/ad_banner/ad_banner_cubit.dart';
import 'package:mirror_logic/presentation/widgets/ads/ad_banner_slot.dart';

/// Lays the bottom banner under whichever screen is on top.
///
/// One strip for the whole app rather than one per screen. Banner candidates
/// are tried Unity-first, Meta-second per slot, and the strip hides while a
/// full-screen ad holds the screen so two ads never overlap.
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

        return Stack(
          children: [
            child,
            if (state.visible && selection != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AdBannerSlot(
                  key: ValueKey(
                    '${selection.mountKey}-${state.mountGeneration}',
                  ),
                  selection: selection,
                  onLoaded: cubit.onBannerLoaded,
                  onFailed: cubit.onBannerFailed,
                ),
              ),
            if (state.loading && selection != null)
              Offstage(
                child: AdBannerSlot(
                  key: ValueKey(
                    'load-${selection.mountKey}-${state.mountGeneration}',
                  ),
                  selection: selection,
                  onLoaded: cubit.onBannerLoaded,
                  onFailed: cubit.onBannerFailed,
                ),
              ),
          ],
        );
      },
    );
  }
}
