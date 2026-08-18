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

/// One slot in a placement waterfall.
///
/// Unity is tried first; Meta is the fallback for the same slot. Keeping both
/// ids together preserves the five-slot structure while switching networks.
class AdSlotIds {
  const AdSlotIds({required this.unity, required this.meta});

  final String unity;
  final String meta;
}

/// Every ad unit the game is allowed to request, in the order it tries them.
///
/// Each placement holds five slots because a single unit is a single point of
/// failure. [AdsService] walks the list top to bottom; within each slot it
/// tries Unity first, then Meta.
///
/// Replace the example ids with real Unity placement ids and Meta placement ids
/// before shipping. Slot count must stay at five.
abstract final class AdUnitIds {
  /// Unity Monetization game id. Use test id in debug; swap for production.
  static String get unityGameId {
    return defaultTargetPlatform == TargetPlatform.iOS ? _iosUnityGameId : _androidUnityGameId;
  }

  /// Unity test game ids — swap for production ids before release.
  static const String _androidUnityGameId = kDebugMode ? '14851' : '5880850';
  static const String _iosUnityGameId = kDebugMode ? '14850' : '5880851';

  /// Meta test app id — swap for production id before release.
  static const String metaAppId = kDebugMode ? '123456789012345' : '123456789012345';

  // -- Unity test placement ids (game ids 14850/14851) --
  static const String _unityTestBanner = 'banner';
  static const String _unityTestInterstitial = 'video';
  static const String _unityTestRewarded = 'rewardedVideo';

  // -- Meta Audience Network test placement ids --
  static const String _metaTestBanner = 'IMG_16_9_APP_INSTALL#YOUR_PLACEMENT_ID';
  static const String _metaTestInterstitial = 'IMG_16_9_APP_INSTALL#YOUR_PLACEMENT_ID';
  static const String _metaTestRewarded = 'VID_HD_16_9_46S_APP_INSTALL#YOUR_PLACEMENT_ID';

  static const List<AdSlotIds> _androidBanner = [
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_Android_1', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_Android_2', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_Android_3', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_Android_4', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_Android_5', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
  ];

  static const List<AdSlotIds> _androidInterstitial = [
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_Android_1', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_Android_2', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_Android_3', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_Android_4', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_Android_5', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
  ];

  static const List<AdSlotIds> _androidRewarded = [
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_Android_1', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_Android_2', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_Android_3', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_Android_4', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_Android_5', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
  ];

  static const List<AdSlotIds> _iosBanner = [
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_iOS_1', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_iOS_2', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_iOS_3', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_iOS_4', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestBanner : 'Banner_iOS_5', meta: kDebugMode ? _metaTestBanner : 'IMG_16_9_APP_INSTALL#5892850513905237'),
  ];

  static const List<AdSlotIds> _iosInterstitial = [
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_iOS_1', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_iOS_2', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_iOS_3', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_iOS_4', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestInterstitial : 'Interstitial_iOS_5', meta: kDebugMode ? _metaTestInterstitial : 'IMG_16_9_APP_INSTALL#5892850513905237'),
  ];

  static const List<AdSlotIds> _iosRewarded = [
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_iOS_1', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_iOS_2', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_iOS_3', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_iOS_4', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
    AdSlotIds(unity: kDebugMode ? _unityTestRewarded : 'Rewarded_iOS_5', meta: kDebugMode ? _metaTestRewarded : 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237'),
  ];

  /// Fewest units a placement may carry.
  static const int minUnitsPerPlacement = 5;

  /// The waterfall for [placement] on the platform the game is running on.
  static List<AdSlotIds> slotsFor(AdPlacement placement) {
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
