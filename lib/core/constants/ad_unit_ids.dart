import 'package:flutter/foundation.dart';

/// Official Google sample units. Used only when [AppAdsConfig.testMode] is true.
abstract final class GoogleTestAdUnits {
  static const androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
}

/// Named ad placements — one unit ID each. Never a fill-chasing waterfall.
///
/// Extra slots exist so different screens/features can use different units.
/// Empty strings disable that slot. Debug builds use Google test IDs.
abstract final class AppAdsConfig {
  /// Debug / automated tests → Google samples. Release → production lists.
  static bool get testMode => kDebugMode;

  static const bannerPlacements = <String, int>{
    'app': 0,
    'home': 1,
    'game': 2,
    'result': 3,
    'settings': 4,
  };

  static const interstitialPlacements = <String, int>{
    'level_break': 0,
    'pause_exit': 1,
    'forced_exit': 2,
  };

  static const rewardedPlacements = <String, int>{
    'hint': 0,
    'coins': 1,
  };

  /// Production Android App ID (manifest): ca-app-pub-6619866004331477~1908110434
  static const List<String> _androidBanner = [
    'ca-app-pub-6619866004331477/5886953707',
    'ca-app-pub-6619866004331477/1561580365',
    'ca-app-pub-6619866004331477/8071148392',
    'ca-app-pub-6619866004331477/9634627022',
    'ca-app-pub-6619866004331477/5444985053',
  ];

  static const List<String> _androidInterstitial = [
    'ca-app-pub-6619866004331477/8321545352',
    'ca-app-pub-6619866004331477/7095154245',
    'ca-app-pub-6619866004331477/5782072572',
    'ca-app-pub-6619866004331477/3155909233',
    'ca-app-pub-6619866004331477/2491518651',
  ];

  static const List<String> _androidRewarded = [
    'ca-app-pub-6619866004331477/8617943301',
    'ca-app-pub-6619866004331477/9641426537',
    'ca-app-pub-6619866004331477/7304861630',
    'ca-app-pub-6619866004331477/8280243405',
    'ca-app-pub-6619866004331477/8673783628',
  ];

  /// iOS production units not supplied yet — empty disables release iOS ads.
  static const List<String> _iosBanner = ['', '', '', '', ''];
  static const List<String> _iosInterstitial = ['', '', '', '', ''];
  static const List<String> _iosRewarded = ['', '', '', '', ''];

  static const int maxUnitsPerFormat = 5;

  static List<String> get bannerAdUnits =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosBanner : _androidBanner;

  static List<String> get interstitialAdUnits =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _iosInterstitial
      : _androidInterstitial;

  static List<String> get rewardedAdUnits =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _iosRewarded
      : _androidRewarded;

  static String? bannerUnitId(String placement) => _unit(
    bannerAdUnits,
    bannerPlacements[placement],
    format: _AdFormat.banner,
  );

  static String? interstitialUnitId(String placement) => _unit(
    interstitialAdUnits,
    interstitialPlacements[placement],
    format: _AdFormat.interstitial,
  );

  static String? rewardedUnitId(String placement) => _unit(
    rewardedAdUnits,
    rewardedPlacements[placement],
    format: _AdFormat.rewarded,
  );

  static String? _unit(
    List<String> units,
    int? index, {
    required _AdFormat format,
  }) {
    if (index == null || index < 0) return null;
    if (testMode) return _testId(format);
    if (index >= units.length) return null;
    final id = units[index].trim();
    return id.isEmpty ? null : id;
  }

  static String _testId(_AdFormat format) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return switch (format) {
      _AdFormat.banner =>
        ios ? GoogleTestAdUnits.iosBanner : GoogleTestAdUnits.androidBanner,
      _AdFormat.interstitial => ios
          ? GoogleTestAdUnits.iosInterstitial
          : GoogleTestAdUnits.androidInterstitial,
      _AdFormat.rewarded =>
        ios ? GoogleTestAdUnits.iosRewarded : GoogleTestAdUnits.androidRewarded,
    };
  }
}

enum _AdFormat { banner, interstitial, rewarded }

/// Back-compat alias used by older imports/tests.
@Deprecated('Use AppAdsConfig')
typedef AdUnitIds = AppAdsConfig;

/// Format labels kept for Remote Config / docs; not a request waterfall.
enum AdPlacement {
  banner,
  interstitial,
  rewarded,
}
