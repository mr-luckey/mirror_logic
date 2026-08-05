import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// The wooden strip along the bottom of the app carrying a loaded banner.
///
/// Only ever built once there is an ad to put in it — `AdBannerHost` owns the
/// request and leaves the strip out of the tree entirely until one fills.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key, required this.ad});

  final BannerAd ad;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MedievalColors.woodDeep,
        border: Border(
          top: BorderSide(
            color: MedievalColors.bronzeDark.withValues(alpha: 0.55),
          ),
        ),
      ),
      // The strip owns the bottom inset for the whole app, so it has to keep
      // the ad clear of the gesture bar itself.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: GameConstants.adBannerHeight,
          child: Center(
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              // Keyed by the ad itself. `AdWidget` reads its ad once, in
              // initState, and never looks again — handed a replacement through
              // the same element it would keep the retired banner's platform view
              // on screen, so the refresh has to bring a new element with it.
              child: AdWidget(key: ValueKey(ad), ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
