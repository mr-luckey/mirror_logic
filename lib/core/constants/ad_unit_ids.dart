import 'package:flutter/foundation.dart';

/// The three kinds of ad the game serves.
enum AdPlacement {
  /// The strip under every screen the player spends time on.
  banner,

  /// Full screen, between levels, unpaid.
  interstitial,

  /// Full screen, watched by choice, pays for a hint.
  rewarded,
}

/// Every ad unit the game is allowed to request, in the order it tries them.
///
/// Each placement holds five slots because a single unit is a single point of
/// failure: a new unit that has not warmed up, one throttled by low fill in a
/// region, or one a mediation partner is temporarily starving all return the
/// same "no ad" as a broken id. [AdsService] walks the list top to bottom and
/// shows the first unit that fills, so a dead slot costs one failed request
/// rather than the impression.
///
/// Replace the ids in place when the real units are cut. The loader only cares
/// about the order — first entry gets every request that can be filled, later
/// entries only ever see traffic the ones above them could not take.
abstract final class AdUnitIds {
  /// Google's own test units, which always fill. Every slot holds the same id
  /// on purpose: five distinct placeholders would only mean five identical
  /// requests. Swap each line for its real unit before shipping.
  static const List<String> _androidBanner = [
    'ca-app-pub-6018501407074634/9018064835',
    'ca-app-pub-6018501407074634/6419821659',
    'ca-app-pub-6018501407074634/7541331633',
    'ca-app-pub-6018501407074634/2144062547',
    'ca-app-pub-6018501407074634/3518326144',
  ];

  static const List<String> _androidInterstitial = [
    'ca-app-pub-6018501407074634/5476802894',
    'ca-app-pub-6018501407074634/5883997006',
    'ca-app-pub-6018501407074634/4083684384',
    'ca-app-pub-6018501407074634/1697194191',
    'ca-app-pub-6018501407074634/6228249967',
  ];

  static const List<String> _androidRewarded = [
    'ca-app-pub-6018501407074634/2850639558',
    'ca-app-pub-6018501407074634/9384112521',
    'ca-app-pub-6018501407074634/2452656484',
    'ca-app-pub-6018501407074634/1457521047',
    'ca-app-pub-6018501407074634/7911394547',
  ];

  static const List<String> _iosBanner = [
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/2934735716',
  ];

  static const List<String> _iosInterstitial = [
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/4411468910',
  ];

  static const List<String> _iosRewarded = [
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
    'ca-app-pub-3940256099942544/1712485313',
  ];

  /// Fewest units a placement may carry.
  ///
  /// The loader walks whatever the list holds, so a sixth entry costs nothing
  /// to add — this is only here so a list that loses an entry to a careless
  /// find-and-replace fails a test instead of quietly serving four deep.
  static const int minUnitsPerPlacement = 5;

  /// The waterfall for [placement] on the platform the game is running on.
  ///
  /// Reads [defaultTargetPlatform] rather than `dart:io` so tests can pump the
  /// service without a device underneath them.
  static List<String> forPlacement(AdPlacement placement) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    switch (placement) {
      case AdPlacement.banner:
        return ios ? _iosBanner : _androidBanner;
      case AdPlacement.interstitial:
        return ios ? _iosInterstitial : _androidInterstitial;
      case AdPlacement.rewarded:
        return ios ? _iosRewarded : _androidRewarded;
    }
  }
}
