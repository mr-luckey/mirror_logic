import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';

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
/// Everything here is best-effort. A device that cannot reach AdMob, a region
/// with no fill, or a unit id that was never cut all leave the game fully
/// playable with the ad simply absent — no method on this class throws at its
/// caller, and none of them are on a path the player cannot complete without.
class AdsService {
  AdsService({
    this.levelsBetweenInterstitials = 3,
    this.minGapBetweenFullScreenAds = const Duration(seconds: 45),
    this.requestTimeout = const Duration(seconds: 10),
    this.forcedFillWait = const Duration(seconds: 4),
  });

  /// Level clears between two interstitials. The counter starts at zero every
  /// launch, so the opening boards of any session are always quiet.
  final int levelsBetweenInterstitials;

  /// Quiet period after any full-screen ad, rewarded ones included: a player
  /// who just sat through a video to buy a hint should not meet an interstitial
  /// the moment they finish the board.
  final Duration minGapBetweenFullScreenAds;

  /// How long one unit gets to fill before the waterfall moves down a slot.
  final Duration requestTimeout;

  /// How long an [InterstitialPolicy.always] caller will stand and wait for an
  /// empty cache to fill before giving up and letting the player through.
  ///
  /// The cache is refilled the moment an ad closes, so the only realistic way
  /// one of these placements finds it empty is being tapped during that refill.
  /// Waiting out those few seconds is what makes "always" mean it, and the cap
  /// is what keeps a dead network from parking the player on a button.
  final Duration forcedFillWait;

  bool _ready = false;
  bool _fullScreenShowing = false;
  DateTime? _lastFullScreenAt;
  int _clearsSinceInterstitial = 0;
  Future<void>? _bringUp;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  Future<void>? _interstitialFill;
  Future<void>? _rewardedFill;

  /// Whether the SDK came up. False leaves everything below a no-op.
  bool get isReady => _ready;

  /// Whether a full-screen ad holds the screen right now.
  bool get isFullScreenAdShowing => _fullScreenShowing;

  /// Whether a rewarded video is cached and can start on the next tap.
  ///
  /// The hint sheet only offers the video when this is true: an ad that still
  /// has to be fetched leaves the player on a dead button for several seconds,
  /// which reads as a broken game rather than a slow network.
  bool get hasRewardedAd => _rewarded != null;

  /// Brings the SDK up. Safe to call from anywhere, any number of times.
  ///
  /// The future is kept so later callers can join a bring-up already in flight
  /// instead of racing it. Launch fires this without waiting, and the SDK can
  /// take a few seconds on a cold first run — which is longer than the splash
  /// screen, so the first banner request would otherwise arrive while the SDK
  /// was still starting and be turned away for good.
  Future<void> init() => _bringUp ??= _initialize();

  Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (error, stack) {
      // No ad is worth a black screen on launch.
      _ready = false;
      debugPrint('AdsService disabled: $error\n$stack');
      return;
    }
    _fillCaches();
  }

  /// Fills the full-screen caches in the background, standing the SDK up first
  /// if launch's own attempt has not landed yet.
  ///
  /// Both ads are fetched well ahead of the tap that shows them: a rewarded
  /// video is tens of megabytes, and fetching it on demand would put the wait
  /// between the player's decision and their reward.
  void warmUp() => unawaited(init().then((_) => _fillCaches()));

  void _fillCaches() {
    if (!_ready) return;
    unawaited(_fillInterstitial());
    unawaited(_fillRewarded());
  }

  /// Counts a cleared board towards the next interstitial.
  void registerLevelCleared() => _clearsSinceInterstitial++;

  /// Whether the level-break cadence allows an interstitial right now.
  ///
  /// Pure bookkeeping — it says nothing about whether an ad is actually cached.
  @visibleForTesting
  bool get interstitialDue =>
      interstitialAllowed(policy: InterstitialPolicy.levelBreak);

  /// Whether an interstitial may be shown, by the rules the caller plays under.
  ///
  /// See [InterstitialPolicy]. The clear counter only applies to ads that ride a
  /// level break: leaving the board from the pause menu is already a deliberate
  /// stop, so an ad there does not interrupt a puzzle in progress and does not
  /// need to wait for the third clear.
  @visibleForTesting
  bool interstitialAllowed({required InterstitialPolicy policy}) {
    if (policy == InterstitialPolicy.always) return true;

    final last = _lastFullScreenAt;
    if (last != null &&
        DateTime.now().difference(last) < minGapBetweenFullScreenAds) {
      return false;
    }
    if (policy == InterstitialPolicy.levelBreak &&
        _clearsSinceInterstitial < levelsBetweenInterstitials) {
      return false;
    }
    return true;
  }

  /// Shows an interstitial, if [policy] allows one and one is cached.
  ///
  /// Completes when the ad closes, so callers can hold navigation until the
  /// player is back. Returns whether anything was shown.
  Future<bool> showInterstitial({
    InterstitialPolicy policy = InterstitialPolicy.levelBreak,
  }) async {
    if (!_ready || !interstitialAllowed(policy: policy)) return false;

    var ad = _interstitial;
    if (ad == null && policy == InterstitialPolicy.always) {
      await _fillInterstitial().timeout(forcedFillWait, onTimeout: () {});
      ad = _interstitial;
    }
    if (ad == null) {
      // Nothing cached: leave the cadence counter alone so the next clear gets
      // another go, and start the fetch that should have been ready by now.
      unawaited(_fillInterstitial());
      return false;
    }
    if (!claimFullScreenSlot()) return false;

    _interstitial = null;
    _clearsSinceInterstitial = 0;

    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        releaseFullScreenSlot(shown: true);
        _settle(closed);
        unawaited(_fillInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('interstitial failed to show: $error');
        ad.dispose();
        releaseFullScreenSlot(shown: false);
        _settle(closed);
        unawaited(_fillInterstitial());
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

  /// Plays a rewarded video and reports whether the player earned the reward.
  ///
  /// Only ever shows an already-cached ad, so the video starts on the tap that
  /// asked for it.
  Future<RewardedAdOutcome> showRewarded() async {
    if (!_ready) return RewardedAdOutcome.unavailable;
    final ad = _rewarded;
    if (ad == null) {
      unawaited(_fillRewarded());
      return RewardedAdOutcome.unavailable;
    }
    if (!claimFullScreenSlot()) return RewardedAdOutcome.unavailable;

    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        releaseFullScreenSlot(shown: true);
        _settle(closed);
        unawaited(_fillRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('rewarded failed to show: $error');
        ad.dispose();
        releaseFullScreenSlot(shown: false);
        _settle(closed);
        unawaited(_fillRewarded());
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

  /// The first banner unit that fills at [size], or null if none do.
  ///
  /// Waits out the SDK bring-up rather than failing against it, because the
  /// first banner of a session is asked for seconds after launch.
  ///
  /// Ownership passes to the caller: whoever mounts the ad disposes it.
  Future<BannerAd?> loadBanner(AdSize size) async {
    await init();
    if (!_ready) return null;
    return _waterfall(
      AdPlacement.banner,
      (unitId) => _requestBanner(unitId, size),
    );
  }

  Future<void> dispose() async {
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
    _ready = false;
    _bringUp = null;
  }

  // ---------------------------------------------------------------------------
  // The full-screen gate
  // ---------------------------------------------------------------------------

  /// Claims the right to put a full-screen ad up, or refuses.
  ///
  /// An interstitial and a rewarded video can both sit cached at once, and the
  /// two paths that show them are independent — the win fanfare can fire a
  /// level-end interstitial in the same frame a hint tap resolves, and a double
  /// tap can ask twice. Two `show()` calls in flight stack two native
  /// activities, and the one underneath never gets the dismiss callback it is
  /// waiting on: its reward is lost and the gate would stay shut for good. So
  /// whoever claims it first shows, and the loser backs off quietly.
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
    // Only a real impression starts the quiet period; an ad that failed to
    // show should not buy the next one a reprieve.
    if (shown) _lastFullScreenAt = DateTime.now();
  }

  /// Waits for the ad to close, but never forever.
  ///
  /// A dismiss callback that never arrives would leave the gate shut and the
  /// caller's navigation hanging behind an ad the player has already closed.
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

  /// Walks [placement]'s units top to bottom and returns the first fill.
  Future<T?> _waterfall<T extends Object>(
    AdPlacement placement,
    Future<T?> Function(String unitId) request,
  ) async {
    for (final unitId in AdUnitIds.forPlacement(placement)) {
      final ad = await request(unitId);
      if (ad != null) return ad;
    }
    return null;
  }

  Future<void> _fillInterstitial() {
    if (!_ready || _interstitial != null) return Future<void>.value();
    // A second caller joins the request in flight rather than racing a parallel
    // waterfall down the same list and throwing one of the two ads away.
    return _interstitialFill ??= _runFill(
      () async => _interstitial = await _waterfall(
        AdPlacement.interstitial,
        _requestInterstitial,
      ),
      onDone: () => _interstitialFill = null,
    );
  }

  Future<void> _fillRewarded() {
    if (!_ready || _rewarded != null) return Future<void>.value();
    return _rewardedFill ??= _runFill(
      () async =>
          _rewarded = await _waterfall(AdPlacement.rewarded, _requestRewarded),
      onDone: () => _rewardedFill = null,
    );
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

  Future<BannerAd?> _requestBanner(String unitId, AdSize size) {
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

  Future<InterstitialAd?> _requestInterstitial(String unitId) {
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
    return request.result;
  }

  Future<RewardedAd?> _requestRewarded(String unitId) {
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
    return request.result;
  }
}

/// One unit's turn in the waterfall, as a future that always resolves.
///
/// AdMob answers a request with one of two callbacks, or — on a wedged network
/// stack — neither. The timeout is what keeps a single silent unit from
/// stalling the whole list, and [_settled] is what keeps a late answer from
/// handing back an ad nobody is waiting for any more.
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
      // The waterfall has already moved on; this ad has no owner to dispose it.
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
