import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/infrastructure/ads/ads_remote_config.dart';
import 'package:mirror_logic/infrastructure/network/network_guard.dart';

/// How much of the interstitial cadence a placement agrees to wait for.
enum InterstitialPolicy {
  /// Waits for both the level-clear count and the quiet period.
  levelBreak,

  /// Waits only for the quiet period (pause-menu exits).
  quietPeriod,

  /// Shows on every tap, gates waived (forced exits).
  always,
}

/// What became of a rewarded video the player asked for.
enum RewardedAdOutcome {
  earned,
  skipped,
  unavailable,
}

/// Loads and shows ads. Placement-based unit IDs. No fill waterfall.
///
/// Offline = idle. No-fill is legitimate. Best-effort — never throws to UI.
class AdsService {
  AdsService({
    AdsConfig? remoteConfig,
    NetworkGuard? network,
    this.levelsBetweenInterstitials = 3,
    Duration? minGapBetweenFullScreenAds,
    this.requestTimeout = const Duration(seconds: 10),
    this.forcedFillWait = const Duration(seconds: 4),
    this.maxRetries = 2,
    this.retryBackoff = const Duration(seconds: 30),
  }) : _remoteConfig = remoteConfig ?? AdsRemoteConfig.instance,
       _network = network ?? NetworkGuard(),
       _minGapOverride = minGapBetweenFullScreenAds;

  final AdsConfig _remoteConfig;
  final NetworkGuard _network;
  final Duration? _minGapOverride;

  final int levelsBetweenInterstitials;
  final Duration requestTimeout;
  final Duration forcedFillWait;
  final int maxRetries;
  final Duration retryBackoff;

  Duration get minGapBetweenFullScreenAds =>
      _minGapOverride ?? _remoteConfig.interstitialMinInterval;

  bool get bannerAdsEnabled =>
      GameConstants.adsEnabled && _remoteConfig.bannerAdsEnabled;

  bool get interstitialAdsEnabled =>
      GameConstants.adsEnabled && _remoteConfig.interstitialAdsEnabled;

  bool get isOnline => _network.isOnline;

  bool _ready = false;
  bool _initializing = false;
  bool _fullScreenShowing = false;
  bool _appForeground = true;
  DateTime? _lastFullScreenAt;
  int _clearsSinceInterstitial = 0;
  bool _hasShownInterstitial = false;
  Future<void>? _bringUp;

  InterstitialAd? _interstitial;
  String? _interstitialPlacement;
  RewardedAd? _rewarded;
  String? _rewardedPlacement;
  Future<void>? _interstitialFill;
  Future<void>? _rewardedFill;

  int _interstitialAttempts = 0;
  int _rewardedAttempts = 0;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;

  bool get isReady => _ready;
  bool get isFullScreenAdShowing => _fullScreenShowing;
  bool get hasRewardedAd => hasRewardedFor('hint');

  bool hasRewardedFor(String placement) =>
      _rewarded != null && _rewardedPlacement == placement;

  /// Maps cadence policy → named AdMob placement (one unit ID).
  static String interstitialPlacementFor(InterstitialPolicy policy) {
    return switch (policy) {
      InterstitialPolicy.levelBreak => 'level_break',
      InterstitialPolicy.quietPeriod => 'pause_exit',
      InterstitialPolicy.always => 'forced_exit',
    };
  }

  void setAppForeground(bool foreground) {
    _appForeground = foreground;
    if (!foreground) {
      _interstitialRetry?.cancel();
      _rewardedRetry?.cancel();
      return;
    }
    if (_network.isOnline) _fillCaches();
  }

  Future<void> init() => _bringUp ??= _bootstrap();

  Future<void> _bootstrap() async {
    if (!GameConstants.adsEnabled) {
      _ready = false;
      debugPrint('AdsService disabled: GameConstants.adsEnabled is false');
      return;
    }
    await _remoteConfig.ensureInitialized();
    await _network.start(onOnline: _onNetworkRestored);
    if (!_network.isOnline) {
      debugPrint('AdsService idle: offline at bootstrap');
      return;
    }
    await _ensureSdk();
    _fillCaches();
  }

  void _onNetworkRestored() {
    unawaited(() async {
      await _ensureSdk();
      if (_appForeground) _fillCaches();
    }());
  }

  Future<void> _ensureSdk() async {
    if (_ready || _initializing || !GameConstants.adsEnabled) return;
    if (!_network.isOnline) return;
    _initializing = true;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (error, stack) {
      _ready = false;
      debugPrint('AdsService SDK init failed: $error\n$stack');
    } finally {
      _initializing = false;
    }
  }

  void warmUp({
    String interstitialPlacement = 'level_break',
    String rewardedPlacement = 'hint',
  }) {
    unawaited(_warmUp(interstitialPlacement, rewardedPlacement));
  }

  Future<void> _warmUp(String interstitialPlacement, String rewardedPlacement) async {
    await init();
    if (!_network.isOnline || !_appForeground) return;
    await _ensureSdk();
    if (interstitialAdsEnabled) {
      unawaited(preloadInterstitial(placement: interstitialPlacement));
    }
    unawaited(preloadRewarded(placement: rewardedPlacement));
  }

  void _fillCaches() {
    if (!_ready || !_appForeground || !_network.isOnline) return;
    if (interstitialAdsEnabled) {
      unawaited(preloadInterstitial(placement: 'level_break'));
    }
    unawaited(preloadRewarded(placement: 'hint'));
  }

  Future<void> refreshRemoteConfig() async {
    await _remoteConfig.refreshIfNeeded();
    if (!interstitialAdsEnabled) {
      await _interstitial?.dispose();
      _interstitial = null;
      _interstitialPlacement = null;
      return;
    }
    if (_ready) unawaited(preloadInterstitial(placement: 'level_break'));
  }

  void registerLevelCleared() => _clearsSinceInterstitial++;

  @visibleForTesting
  bool get interstitialDue =>
      interstitialAllowed(policy: InterstitialPolicy.levelBreak);

  @visibleForTesting
  bool interstitialAllowed({required InterstitialPolicy policy}) {
    if (!interstitialAdsEnabled) return false;
    if (policy == InterstitialPolicy.always) return true;

    final last = _lastFullScreenAt;
    if (last != null &&
        DateTime.now().difference(last) < minGapBetweenFullScreenAds) {
      return false;
    }
    final requiredClears =
        !_hasShownInterstitial && !_remoteConfig.interstitialSkipFirst
        ? 1
        : levelsBetweenInterstitials;
    if (policy == InterstitialPolicy.levelBreak &&
        _clearsSinceInterstitial < requiredClears) {
      return false;
    }
    return true;
  }

  Future<void> preloadInterstitial({
    String placement = 'level_break',
  }) async {
    if (!interstitialAdsEnabled) return;
    if (_interstitial != null && _interstitialPlacement == placement) return;
    if (!_ready || !_appForeground) return;
    if (!_network.isOnline) return;
    if (_interstitialAttempts > maxRetries) return;

    final unitId = AppAdsConfig.interstitialUnitId(placement);
    if (unitId == null) return;

    return _interstitialFill ??= _runFill(() async {
      try {
        _interstitialRetry?.cancel();
        await _interstitial?.dispose();
        _interstitial = null;
        _interstitialPlacement = null;

        final request = _AdRequest<InterstitialAd>(
          unitId: unitId,
          timeout: requestTimeout,
        );
        unawaited(
          InterstitialAd.load(
            adUnitId: unitId,
            request: const AdRequest(),
            adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: request.filled,
              onAdFailedToLoad: request.empty,
            ),
          ),
        );
        final ad = await request.result;
        if (ad == null) {
          _interstitialAttempts++;
          _scheduleInterstitialRetry(placement);
          return;
        }
        _interstitialAttempts = 0;
        _interstitial = ad;
        _interstitialPlacement = placement;
      } catch (error, stack) {
        debugPrint('preloadInterstitial failed: $error\n$stack');
      }
    }, onDone: () => _interstitialFill = null);
  }

  Future<bool> showInterstitial({
    InterstitialPolicy policy = InterstitialPolicy.levelBreak,
  }) async {
    if (!interstitialAdsEnabled) return false;
    if (!_network.isOnline) return false;
    if (!_ready || !interstitialAllowed(policy: policy)) return false;

    final placement = interstitialPlacementFor(policy);
    var ad = (_interstitialPlacement == placement) ? _interstitial : null;
    if (ad == null && policy == InterstitialPolicy.always) {
      await preloadInterstitial(placement: placement)
          .timeout(forcedFillWait, onTimeout: () {});
      ad = (_interstitialPlacement == placement) ? _interstitial : null;
    }
    if (ad == null) {
      unawaited(preloadInterstitial(placement: placement));
      return false;
    }
    if (!claimFullScreenSlot()) return false;

    _interstitial = null;
    _interstitialPlacement = null;
    _clearsSinceInterstitial = 0;

    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _hasShownInterstitial = true;
        releaseFullScreenSlot(shown: true);
        _settle(closed);
        unawaited(preloadInterstitial(placement: placement));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('interstitial failed to show: $error');
        ad.dispose();
        releaseFullScreenSlot(shown: false);
        _settle(closed);
        unawaited(preloadInterstitial(placement: placement));
      },
    );

    try {
      await ad.show();
    } catch (error) {
      debugPrint('interstitial show threw: $error');
      releaseFullScreenSlot(shown: false);
      _settle(closed);
      return false;
    }
    await _awaitClose(closed);
    return true;
  }

  Future<void> preloadRewarded({String placement = 'hint'}) async {
    if (_rewarded != null && _rewardedPlacement == placement) return;
    if (!_ready || !_appForeground) return;
    if (!_network.isOnline) return;
    if (_rewardedAttempts > maxRetries) return;

    final unitId = AppAdsConfig.rewardedUnitId(placement);
    if (unitId == null) return;

    return _rewardedFill ??= _runFill(() async {
      try {
        _rewardedRetry?.cancel();
        await _rewarded?.dispose();
        _rewarded = null;
        _rewardedPlacement = null;

        final request = _AdRequest<RewardedAd>(
          unitId: unitId,
          timeout: requestTimeout,
        );
        unawaited(
          RewardedAd.load(
            adUnitId: unitId,
            request: const AdRequest(),
            rewardedAdLoadCallback: RewardedAdLoadCallback(
              onAdLoaded: request.filled,
              onAdFailedToLoad: request.empty,
            ),
          ),
        );
        final ad = await request.result;
        if (ad == null) {
          _rewardedAttempts++;
          _scheduleRewardedRetry(placement);
          return;
        }
        _rewardedAttempts = 0;
        _rewarded = ad;
        _rewardedPlacement = placement;
      } catch (error, stack) {
        debugPrint('preloadRewarded failed: $error\n$stack');
      }
    }, onDone: () => _rewardedFill = null);
  }

  Future<RewardedAdOutcome> showRewarded({String placement = 'hint'}) async {
    if (!_network.isOnline) return RewardedAdOutcome.unavailable;
    if (!_ready) return RewardedAdOutcome.unavailable;

    var ad = (_rewardedPlacement == placement) ? _rewarded : null;
    if (ad == null) {
      unawaited(preloadRewarded(placement: placement));
      return RewardedAdOutcome.unavailable;
    }
    if (!claimFullScreenSlot()) return RewardedAdOutcome.unavailable;

    _rewarded = null;
    _rewardedPlacement = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        releaseFullScreenSlot(shown: true);
        _settle(closed);
        unawaited(preloadRewarded(placement: placement));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('rewarded failed to show: $error');
        ad.dispose();
        releaseFullScreenSlot(shown: false);
        _settle(closed);
        unawaited(preloadRewarded(placement: placement));
      },
    );

    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (error) {
      debugPrint('rewarded show threw: $error');
      releaseFullScreenSlot(shown: false);
      _settle(closed);
      return RewardedAdOutcome.unavailable;
    }
    await _awaitClose(closed);
    return earned ? RewardedAdOutcome.earned : RewardedAdOutcome.skipped;
  }

  /// Loads the single unit for [placement]. Caller owns dispose.
  Future<BannerAd?> loadBanner(
    AdSize size, {
    String placement = 'app',
  }) async {
    await init();
    if (!_ready || !bannerAdsEnabled || !_appForeground) return null;
    if (!_network.isOnline) return null;

    final unitId = AppAdsConfig.bannerUnitId(placement);
    if (unitId == null) return null;

    final request = _AdRequest<BannerAd>(
      unitId: unitId,
      timeout: requestTimeout,
    );
    final ad = BannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => request.filled(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          request.empty(error);
        },
      ),
    );
    unawaited(ad.load());
    return request.result;
  }

  Future<void> dispose() async {
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    await _interstitial?.dispose();
    _interstitial = null;
    await _rewarded?.dispose();
    _rewarded = null;
    _ready = false;
    _bringUp = null;
    await _network.dispose();
  }

  @visibleForTesting
  bool claimFullScreenSlot() {
    if (_fullScreenShowing) return false;
    _fullScreenShowing = true;
    return true;
  }

  @visibleForTesting
  void releaseFullScreenSlot({required bool shown}) {
    if (!_fullScreenShowing) return;
    _fullScreenShowing = false;
    if (shown) _lastFullScreenAt = DateTime.now();
  }

  Future<void> _awaitClose(Completer<void> closed) {
    return closed.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('full-screen ad never reported its dismissal');
        releaseFullScreenSlot(shown: true);
      },
    );
  }

  void _settle(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> _runFill(
    Future<void> Function() fill, {
    required VoidCallback onDone,
  }) async {
    try {
      await fill();
    } finally {
      onDone();
    }
  }

  void _scheduleInterstitialRetry(String placement) {
    _interstitialRetry?.cancel();
    if (!_appForeground || !interstitialAdsEnabled) return;
    if (_interstitialAttempts > maxRetries) return;
    if (!_network.isOnline) return;
    final delay = retryBackoff * _interstitialAttempts.clamp(1, 8);
    _interstitialRetry = Timer(
      delay > const Duration(minutes: 5) ? const Duration(minutes: 5) : delay,
      () => unawaited(preloadInterstitial(placement: placement)),
    );
  }

  void _scheduleRewardedRetry(String placement) {
    _rewardedRetry?.cancel();
    if (!_appForeground) return;
    if (_rewardedAttempts > maxRetries) return;
    if (!_network.isOnline) return;
    final delay = retryBackoff * _rewardedAttempts.clamp(1, 8);
    _rewardedRetry = Timer(
      delay > const Duration(minutes: 5) ? const Duration(minutes: 5) : delay,
      () => unawaited(preloadRewarded(placement: placement)),
    );
  }
}

class _AdRequest<T extends Ad> {
  _AdRequest({required this.unitId, required Duration timeout}) {
    _timer = Timer(timeout, () {
      if (_settled) return;
      debugPrint('ad unit $unitId did not answer in time');
      _finish(null);
    });
  }

  final String unitId;
  final Completer<T?> _completer = Completer<T?>();
  Timer? _timer;
  bool _settled = false;

  Future<T?> get result => _completer.future;

  void filled(T ad) {
    if (_settled) {
      ad.dispose();
      return;
    }
    _finish(ad);
  }

  void empty(Object error) {
    if (_settled) return;
    debugPrint('ad unit $unitId returned no ad: $error');
    _finish(null);
  }

  void _finish(T? ad) {
    _settled = true;
    _timer?.cancel();
    _timer = null;
    if (!_completer.isCompleted) _completer.complete(ad);
  }
}
