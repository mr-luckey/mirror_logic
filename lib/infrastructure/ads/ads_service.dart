import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/infrastructure/ads/ad_network.dart';
import 'package:mirror_logic/infrastructure/ads/ads_remote_config.dart';
import 'package:mirror_logic/infrastructure/ads/meta_ads_bridge.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

export 'package:mirror_logic/infrastructure/ads/ad_network.dart';

/// How much of the interstitial cadence a placement agrees to wait for.
enum InterstitialPolicy {
  /// Waits for both the level-clear count and the quiet period. What an ad
  /// riding a level break asks for.
  levelBreak,

  /// Waits only for the quiet period. For exits that are not level breaks but
  /// still should not stack two ads on top of each other.
  quietPeriod,

  /// Shows on every tap, gates waived. For the handful of exits the game
  /// charges for without exception.
  always,
}

/// What became of a rewarded video the player asked for.
enum RewardedAdOutcome {
  /// Watched far enough to be paid. The caller owes the reward.
  earned,

  /// Closed early. No reward, and no charge either.
  skipped,

  /// Nothing to show: no fill, the SDK is down, or another full-screen ad
  /// already holds the screen.
  unavailable,
}

/// Loads and shows the game's ads.
///
/// Unity Ads is first priority; Meta Audience Network is the fallback for each
/// waterfall slot. Everything here is best-effort — no method throws at its
/// caller, and none of them block a path the player cannot complete without.
class AdsService {
  AdsService({
    AdsConfig? remoteConfig,
    this.levelsBetweenInterstitials = 3,
    Duration? minGapBetweenFullScreenAds,
    this.requestTimeout = const Duration(seconds: 10),
    this.forcedFillWait = const Duration(seconds: 4),
  }) : _remoteConfig = remoteConfig ?? AdsRemoteConfig.instance,
       _minGapOverride = minGapBetweenFullScreenAds;

  final AdsConfig _remoteConfig;
  final Duration? _minGapOverride;

  /// Level clears between two interstitials. The counter starts at zero every
  /// launch, so the opening boards of any session are always quiet.
  final int levelsBetweenInterstitials;

  /// Quiet period after any full-screen ad, rewarded ones included.
  Duration get minGapBetweenFullScreenAds =>
      _minGapOverride ?? _remoteConfig.interstitialMinInterval;

  /// Whether Remote Config currently permits banner requests.
  bool get bannerAdsEnabled =>
      GameConstants.adsEnabled && _remoteConfig.bannerAdsEnabled;

  /// Whether Remote Config currently permits interstitial requests and shows.
  bool get interstitialAdsEnabled =>
      GameConstants.adsEnabled && _remoteConfig.interstitialAdsEnabled;

  /// How long one unit gets to fill before the waterfall moves down a slot.
  final Duration requestTimeout;

  /// How long an [InterstitialPolicy.always] caller will stand and wait for an
  /// empty cache to fill before giving up and letting the player through.
  final Duration forcedFillWait;

  bool _ready = false;
  bool _fullScreenShowing = false;
  DateTime? _lastFullScreenAt;
  int _clearsSinceInterstitial = 0;
  bool _hasShownInterstitial = false;
  Future<void>? _bringUp;

  _InterstitialCache? _interstitial;
  _RewardedCache? _rewarded;
  Future<void>? _interstitialFill;
  Future<void>? _rewardedFill;

  /// Whether the SDK came up. False leaves everything below a no-op.
  bool get isReady => _ready;

  /// Whether a full-screen ad holds the screen right now.
  bool get isFullScreenAdShowing => _fullScreenShowing;

  /// Whether a rewarded video is cached and can start on the next tap.
  bool get hasRewardedAd => _rewarded != null;

  /// Brings the SDK up. Safe to call from anywhere, any number of times.
  Future<void> init() => _bringUp ??= _initialize();

  /// Ensures Remote Config is initialized and fetched for this launch.
  ///
  /// If the network is unavailable, Firebase keeps the last activated values;
  /// callers can proceed and rely on cached policy until connectivity returns.
  Future<void> syncRemoteConfig() => _remoteConfig.ensureInitialized();

  Future<void> _initialize() async {
    if (!GameConstants.adsEnabled) {
      _ready = false;
      debugPrint('AdsService disabled: GameConstants.adsEnabled is false');
      return;
    }
    await _remoteConfig.ensureInitialized();
    try {
      await _initNetworks();
      _ready = true;
    } catch (error, stack) {
      _ready = false;
      debugPrint('AdsService disabled: $error\n$stack');
      return;
    }
    _fillCaches();
  }

  Future<void> _initNetworks() async {
    final unityReady = Completer<void>();
    UnityAds.init(
      gameId: AdUnitIds.unityGameId,
      testMode: kDebugMode,
      onComplete: () {
        if (!unityReady.isCompleted) unityReady.complete();
      },
      onFailed: (error, message) {
        debugPrint('Unity Ads init failed: $error $message');
        if (!unityReady.isCompleted) unityReady.complete();
      },
    );
    await unityReady.future.timeout(
      requestTimeout,
      onTimeout: () {
        debugPrint('Unity Ads init timed out');
      },
    );

    try {
      await MetaAdsBridge.initialize(testMode: kDebugMode);
    } catch (error) {
      debugPrint('Meta Audience Network init failed: $error');
    }
  }

  /// Fills the full-screen caches in the background.
  void warmUp() => unawaited(_warmUpIfOnline());

  Future<void> _warmUpIfOnline() async {
    if (!await _hasInternet()) return;
    await init();
    _fillCaches();
  }

  void _fillCaches() {
    if (!_ready) return;
    if (interstitialAdsEnabled) unawaited(_fillInterstitial());
    unawaited(_fillRewarded());
  }

  /// Refreshes the cached controls and immediately applies any ad kill switch.
  Future<void> refreshRemoteConfig() async {
    await _remoteConfig.refreshIfNeeded();
    if (!interstitialAdsEnabled) {
      await _interstitial?.dispose();
      _interstitial = null;
      return;
    }
    if (_ready) unawaited(_fillInterstitial());
  }

  /// Counts a cleared board towards the next interstitial.
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

  /// Ordered banner candidates: Unity then Meta for each of the five slots.
  ///
  /// [AdBannerHost] walks this list until one widget reports a load.
  List<BannerAdSelection> bannerCandidates({int startSlot = 0}) {
    if (!_ready || !bannerAdsEnabled) return const [];
    final slots = AdUnitIds.slotsFor(AdPlacement.banner);
    final candidates = <BannerAdSelection>[];
    for (var i = startSlot; i < slots.length; i++) {
      final slot = slots[i];
      candidates.add(
        BannerAdSelection(
          network: AdNetwork.unity,
          placementId: slot.unity,
          slotIndex: i,
        ),
      );
      candidates.add(
        BannerAdSelection(
          network: AdNetwork.meta,
          placementId: slot.meta,
          slotIndex: i,
        ),
      );
    }
    return candidates;
  }

  /// Shows an interstitial, if [policy] allows one and one is cached.
  Future<bool> showInterstitial({
    InterstitialPolicy policy = InterstitialPolicy.levelBreak,
  }) async {
    if (!interstitialAdsEnabled) return false;
    if (!await _hasInternet()) return false;
    if (!_ready || !interstitialAllowed(policy: policy)) return false;

    var cache = _interstitial;
    if (cache == null && policy == InterstitialPolicy.always) {
      await _fillInterstitial().timeout(forcedFillWait, onTimeout: () {});
      cache = _interstitial;
    }
    if (cache == null) {
      unawaited(_fillInterstitial());
      return false;
    }
    if (!claimFullScreenSlot()) return false;

    _interstitial = null;
    _clearsSinceInterstitial = 0;

    final shown = await _showInterstitialCache(cache);
    if (shown) _hasShownInterstitial = true;
    unawaited(_fillInterstitial());
    return shown;
  }

  /// Plays a rewarded video and reports whether the player earned the reward.
  Future<RewardedAdOutcome> showRewarded() async {
    if (!await _hasInternet()) return RewardedAdOutcome.unavailable;
    if (!_ready) return RewardedAdOutcome.unavailable;
    final cache = _rewarded;
    if (cache == null) {
      unawaited(_fillRewarded());
      return RewardedAdOutcome.unavailable;
    }
    if (!claimFullScreenSlot()) return RewardedAdOutcome.unavailable;

    _rewarded = null;
    final outcome = await _showRewardedCache(cache);
    unawaited(_fillRewarded());
    return outcome;
  }

  Future<void> dispose() async {
    await _interstitial?.dispose();
    _interstitial = null;
    await _rewarded?.dispose();
    _rewarded = null;
    _ready = false;
    _bringUp = null;
  }

  // ---------------------------------------------------------------------------
  // The full-screen gate
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _fillInterstitial() async {
    if (!interstitialAdsEnabled) {
      await _interstitial?.dispose();
      _interstitial = null;
      return;
    }
    if (!_ready || _interstitial != null) return;
    if (!await _hasInternet()) return;
    return _interstitialFill ??= _runFill(
      () async => _interstitial = await _waterfallFullScreen(
        AdPlacement.interstitial,
        _loadUnityInterstitial,
        _loadMetaInterstitial,
      ),
      onDone: () => _interstitialFill = null,
    );
  }

  Future<void> _fillRewarded() async {
    if (!await _hasInternet()) return;
    if (!_ready || _rewarded != null) return Future<void>.value();
    return _rewardedFill ??= _runFill(
      () async => _rewarded = await _waterfallFullScreen(
        AdPlacement.rewarded,
        _loadUnityRewarded,
        _loadMetaRewarded,
      ),
      onDone: () => _rewardedFill = null,
    );
  }

  Future<T?> _waterfallFullScreen<T extends _FullScreenCache>(
    AdPlacement placement,
    Future<T?> Function(String placementId) loadUnity,
    Future<T?> Function(String placementId) loadMeta,
  ) async {
    for (final slot in AdUnitIds.slotsFor(placement)) {
      final unity = await loadUnity(slot.unity);
      if (unity != null) return unity;
      final meta = await loadMeta(slot.meta);
      if (meta != null) return meta;
    }
    return null;
  }

  Future<_InterstitialCache?> _loadUnityInterstitial(String placementId) async {
    final loaded = await _unityLoad(placementId);
    if (!loaded) return null;
    return _InterstitialCache.unity(placementId);
  }

  Future<_InterstitialCache?> _loadMetaInterstitial(String placementId) async {
    await MetaAdsBridge.disposeInterstitial();
    await MetaAdsBridge.loadInterstitial(placementId);
    // Wait for the native side to report readiness.
    final ready = await _pollMetaReady(
      MetaAdsBridge.isInterstitialReady,
    );
    if (!ready) return null;
    return _InterstitialCache.meta(placementId);
  }

  Future<_RewardedCache?> _loadUnityRewarded(String placementId) async {
    final loaded = await _unityLoad(placementId);
    if (!loaded) return null;
    return _RewardedCache.unity(placementId);
  }

  Future<bool> _unityLoad(String placementId) async {
    final completer = Completer<bool>();
    UnityAds.load(
      placementId: placementId,
      onComplete: (_) {
        if (!completer.isCompleted) completer.complete(true);
      },
      onFailed: (_, error, message) {
        debugPrint('Unity load failed $placementId: $error $message');
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        debugPrint('Unity load timed out: $placementId');
        return false;
      },
    );
  }

  /// Polls [isReady] until it returns `true` or [requestTimeout] elapses.
  Future<bool> _pollMetaReady(Future<bool> Function() isReady) async {
    const interval = Duration(milliseconds: 200);
    final deadline = DateTime.now().add(requestTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await isReady()) return true;
      await Future<void>.delayed(interval);
    }
    debugPrint('Meta load timed out');
    return false;
  }

  Future<_RewardedCache?> _loadMetaRewarded(String placementId) async {
    await MetaAdsBridge.disposeRewarded();
    await MetaAdsBridge.loadRewarded(placementId);
    final ready = await _pollMetaReady(
      MetaAdsBridge.isRewardedReady,
    );
    if (!ready) return null;
    return _RewardedCache.meta(placementId);
  }

  Future<bool> _showInterstitialCache(_InterstitialCache cache) async {
    final closed = Completer<void>();
    var shown = false;

    switch (cache.network) {
      case AdNetwork.unity:
        try {
          await UnityAds.showVideoAd(
            placementId: cache.placementId,
            onStart: (_) => shown = true,
            onComplete: (_) {
              releaseFullScreenSlot(shown: true);
              _settle(closed);
            },
            onSkipped: (_) {
              releaseFullScreenSlot(shown: true);
              _settle(closed);
            },
            onFailed: (_, error, message) {
              debugPrint('Unity interstitial show failed: $error $message');
              releaseFullScreenSlot(shown: false);
              _settle(closed);
            },
          );
        } catch (error) {
          debugPrint('Unity interstitial show threw: $error');
          releaseFullScreenSlot(shown: false);
          _settle(closed);
          return false;
        }
      case AdNetwork.meta:
        try {
          final result = await MetaAdsBridge.showInterstitial();
          shown = result['shown'] == true;
          releaseFullScreenSlot(shown: shown);
          _settle(closed);
        } catch (error) {
          debugPrint('Meta interstitial show threw: $error');
          releaseFullScreenSlot(shown: false);
          _settle(closed);
          return false;
        }
    }

    await _awaitClose(closed);
    return shown;
  }

  Future<RewardedAdOutcome> _showRewardedCache(_RewardedCache cache) async {
    final closed = Completer<void>();
    var earned = false;
    var shown = false;

    switch (cache.network) {
      case AdNetwork.unity:
        try {
          await UnityAds.showVideoAd(
            placementId: cache.placementId,
            onStart: (_) => shown = true,
            onComplete: (_) {
              earned = true;
              releaseFullScreenSlot(shown: true);
              _settle(closed);
            },
            onSkipped: (_) {
              releaseFullScreenSlot(shown: true);
              _settle(closed);
            },
            onFailed: (_, error, message) {
              debugPrint('Unity rewarded show failed: $error $message');
              releaseFullScreenSlot(shown: false);
              _settle(closed);
            },
          );
        } catch (error) {
          debugPrint('Unity rewarded show threw: $error');
          releaseFullScreenSlot(shown: false);
          _settle(closed);
          return RewardedAdOutcome.unavailable;
        }
      case AdNetwork.meta:
        try {
          final result = await MetaAdsBridge.showRewarded();
          shown = result['shown'] == true;
          earned = result['earned'] == true;
          releaseFullScreenSlot(shown: shown);
          _settle(closed);
        } catch (error) {
          debugPrint('Meta rewarded show threw: $error');
          releaseFullScreenSlot(shown: false);
          _settle(closed);
          return RewardedAdOutcome.unavailable;
        }
    }

    await _awaitClose(closed);
    if (!shown) return RewardedAdOutcome.unavailable;
    return earned ? RewardedAdOutcome.earned : RewardedAdOutcome.skipped;
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

  Future<bool> _hasInternet() async {
    try {
      final status = await Connectivity().checkConnectivity();
      return status.any((s) => s != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}

sealed class _FullScreenCache {
  AdNetwork get network;
  String get placementId;
  Future<void> dispose();
}

final class _InterstitialCache implements _FullScreenCache {
  _InterstitialCache._({required this.network, required this.placementId});

  factory _InterstitialCache.unity(String placementId) =>
      _InterstitialCache._(network: AdNetwork.unity, placementId: placementId);

  factory _InterstitialCache.meta(String placementId) =>
      _InterstitialCache._(network: AdNetwork.meta, placementId: placementId);

  @override
  final AdNetwork network;
  @override
  final String placementId;

  @override
  Future<void> dispose() async {
    if (network == AdNetwork.meta) await MetaAdsBridge.disposeInterstitial();
  }
}

final class _RewardedCache implements _FullScreenCache {
  _RewardedCache._({required this.network, required this.placementId});

  factory _RewardedCache.unity(String placementId) =>
      _RewardedCache._(network: AdNetwork.unity, placementId: placementId);

  factory _RewardedCache.meta(String placementId) =>
      _RewardedCache._(network: AdNetwork.meta, placementId: placementId);

  @override
  final AdNetwork network;
  @override
  final String placementId;

  @override
  Future<void> dispose() async {
    if (network == AdNetwork.meta) await MetaAdsBridge.disposeRewarded();
  }
}
