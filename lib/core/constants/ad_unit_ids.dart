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
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosUnityGameId
        : _androidUnityGameId;
  }

  /// Example / test Unity game ids — replace before release.
  static const String _androidUnityGameId = '6177237';
  static const String _iosUnityGameId = '5880851';

  /// Meta Developer App ID — must match the prefix of every Meta placement id.
  static const String metaAppId = '1385141237044547';

  // Unity placementIds from Monetization CSV (case-sensitive).
  static const List<AdSlotIds> _androidBanner = [
    AdSlotIds(unity: 'Banner_1', meta: '1385141237044547_1385142403711097'),
    AdSlotIds(unity: 'Banner_2', meta: '1385141237044547_1385142763711061'),
    AdSlotIds(unity: 'Banner_3', meta: '1385141237044547_1385142897044381'),
    AdSlotIds(unity: 'Banner_4', meta: '1385141237044547_1385143033711034'),
    AdSlotIds(unity: 'Banner_5', meta: '1385141237044547_1385143123711025'),
  ];

  static const List<AdSlotIds> _androidInterstitial = [
    AdSlotIds(unity: 'Inter_1', meta: '1385141237044547_1385143267044344'),
    AdSlotIds(unity: 'Inter_2', meta: '1385141237044547_1385143203711017'),
    AdSlotIds(unity: 'Inter_3', meta: '1385141237044547_1385144233710914'),
    AdSlotIds(unity: 'Inter_4', meta: '1385141237044547_1385144537044217'),
    AdSlotIds(unity: 'Inter_5', meta: '1385141237044547_1385144607044210'),
  ];

  static const List<AdSlotIds> _androidRewarded = [
    AdSlotIds(unity: 'Reward_1', meta: '1385141237044547_1385144887044182'),
    AdSlotIds(unity: 'Reward_2', meta: '1385141237044547_1385145023710835'),
    AdSlotIds(unity: 'Reward_3', meta: '1385141237044547_1385145177044153'),
    AdSlotIds(unity: 'Reward_4', meta: '1385141237044547_1385145240377480'),
    // Fifth Unity slot; Meta reuses the prior placement until a dedicated id exists.
    AdSlotIds(unity: 'Reward_5', meta: '1385141237044547_1385145240377480'),
  ];

  static const List<AdSlotIds> _iosBanner = [
    AdSlotIds(
      unity: 'Banner_iOS_1',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Banner_iOS_2',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Banner_iOS_3',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Banner_iOS_4',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Banner_iOS_5',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
  ];

  static const List<AdSlotIds> _iosInterstitial = [
    AdSlotIds(
      unity: 'Interstitial_iOS_1',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Interstitial_iOS_2',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Interstitial_iOS_3',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Interstitial_iOS_4',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Interstitial_iOS_5',
      meta: 'IMG_16_9_APP_INSTALL#5892850513905237',
    ),
  ];

  static const List<AdSlotIds> _iosRewarded = [
    AdSlotIds(
      unity: 'Rewarded_iOS_1',
      meta: 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Rewarded_iOS_2',
      meta: 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Rewarded_iOS_3',
      meta: 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Rewarded_iOS_4',
      meta: 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237',
    ),
    AdSlotIds(
      unity: 'Rewarded_iOS_5',
      meta: 'VID_HD_16_9_46S_APP_INSTALL#5892850513905237',
    ),
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
