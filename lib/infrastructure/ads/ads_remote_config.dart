import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// The ad controls consumed by [AdsService].
///
/// Keeping this as a small interface makes cadence tests independent from the
/// Firebase platform plugin.
abstract interface class AdsConfig {
  bool get bannerAdsEnabled;
  bool get interstitialAdsEnabled;
  Duration get interstitialMinInterval;
  bool get interstitialSkipFirst;

  Future<void> ensureInitialized();
  Future<void> refreshIfNeeded();
}

/// Best-effort Firebase Remote Config controls for banner and interstitial ads.
///
/// Rewarded ads and placement ids deliberately stay outside Remote Config.
/// Until Firebase is available, these in-code defaults preserve the app's
/// current ad behavior.
class AdsRemoteConfig implements AdsConfig {
  AdsRemoteConfig._();

  static final AdsRemoteConfig instance = AdsRemoteConfig._();

  static const _keyAdsEnabled = 'ads_enabled';
  static const _keyBannerEnabled = 'banner_ads_enabled';
  static const _keyInterstitialEnabled = 'interstitial_ads_enabled';
  static const _keyInterstitialMinIntervalSeconds =
      'interstitial_min_interval_seconds';
  static const _keyInterstitialSkipFirst = 'interstitial_skip_first';

  static const defaultInterstitialMinInterval = Duration(seconds: 45);

  static const Map<String, dynamic> _defaults = {
    _keyAdsEnabled: true,
    _keyBannerEnabled: true,
    _keyInterstitialEnabled: true,
    _keyInterstitialMinIntervalSeconds: 45,
    _keyInterstitialSkipFirst: true,
  };

  FirebaseRemoteConfig? _remoteConfig;
  Future<void>? _initialization;

  bool get _adsEnabled => _bool(_keyAdsEnabled, true);

  @override
  bool get bannerAdsEnabled => _adsEnabled && _bool(_keyBannerEnabled, true);

  @override
  bool get interstitialAdsEnabled =>
      _adsEnabled && _bool(_keyInterstitialEnabled, true);

  @override
  bool get interstitialSkipFirst => _bool(_keyInterstitialSkipFirst, true);

  @override
  Duration get interstitialMinInterval {
    final seconds = _int(
      _keyInterstitialMinIntervalSeconds,
      defaultInterstitialMinInterval.inSeconds,
    ).clamp(0, 3600);
    return Duration(seconds: seconds);
  }

  @override
  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 12),
        ),
      );
      await remoteConfig.setDefaults(_defaults);
      await remoteConfig.activate();
      _remoteConfig = remoteConfig;
      _logActiveValues('cached');
      await refreshIfNeeded();
    } catch (error) {
      _remoteConfig = null;
      _log('using in-code defaults (Firebase unavailable): $error');
    }
  }

  @override
  Future<void> refreshIfNeeded() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return;
    try {
      final changed = await remoteConfig.fetchAndActivate();
      if (changed) _logActiveValues('fetched');
    } catch (error) {
      _log('fetch skipped/failed; using cache/defaults: $error');
    }
  }

  bool _bool(String key, bool fallback) {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return fallback;
    try {
      return remoteConfig.getBool(key);
    } catch (_) {
      return fallback;
    }
  }

  int _int(String key, int fallback) {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return fallback;
    try {
      return remoteConfig.getInt(key);
    } catch (_) {
      return fallback;
    }
  }

  void _logActiveValues(String source) {
    _log(
      '$source: banner=$bannerAdsEnabled '
      'interstitial=$interstitialAdsEnabled '
      'gap=${interstitialMinInterval.inSeconds}s '
      'skipFirst=$interstitialSkipFirst',
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[AdsRC] $message');
  }
}
