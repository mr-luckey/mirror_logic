import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:mirror_logic/core/constants/app_info.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Signature of `launchUrl`, so tests can stand in for the store intent.
typedef UrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Decides when to ask for a Play Store rating, and does the asking.
///
/// Like [AdsService] this is best-effort: a device with no Play Store, an
/// exhausted review quota or a dead plugin channel all leave the game working
/// with the prompt simply absent. Nothing here throws at its caller.
///
/// The prompt is rationed hard on purpose. Play's in-app review API silently
/// ignores requests once a device-level quota is spent, so an app that asks on
/// every level clear does not get more ratings — it burns its quota on players
/// who were never going to rate and has nothing left for the ones who would.
///
/// Cadence follows the usual WOW-moment pattern: wait until the player has
/// cleared the early tutorial boards ([levelsBeforeFirstAsk]), then ask on a
/// level-complete screen, then space later asks by a random gap in
/// [[levelsBetweenAsksMin], [levelsBetweenAsksMax]] so the prompt never feels
/// scheduled.
class ReviewService {
  ReviewService({
    required LocalStorageService storage,
    InAppReview? review,
    Random? random,
    UrlLauncher? launcher,
    this.levelsBeforeFirstAsk = 7,
    this.levelsBetweenAsksMin = 5,
    this.levelsBetweenAsksMax = 10,
    this.cooldown = const Duration(days: 5),
    this.maxAsks = 3,
    this.askChance = 0.35,
  }) : assert(levelsBetweenAsksMin >= 1),
       assert(levelsBetweenAsksMax >= levelsBetweenAsksMin),
       _storage = storage,
       _review = review ?? InAppReview.instance,
       _random = random ?? Random(),
       _launcher = launcher ?? launchUrl;

  final LocalStorageService _storage;
  final InAppReview _review;
  final Random _random;
  final UrlLauncher _launcher;

  /// Clears before the first ask. The opening boards are too simple to judge
  /// the game on; seven clears is past the tutorial and into real play.
  final int levelsBeforeFirstAsk;

  /// Shortest gap (in clears) before a follow-up ask may appear.
  final int levelsBetweenAsksMin;

  /// Longest gap (in clears) before a follow-up ask may appear.
  ///
  /// Each ask rolls a fresh gap in this range and stores it, so two players
  /// who both dismissed once do not meet the prompt again on the same level.
  final int levelsBetweenAsksMax;

  /// Wall-clock rest between asks, which also covers the player who reopens the
  /// app and grinds a dozen easy boards in one sitting.
  final Duration cooldown;

  /// Total asks over the app's whole lifetime on this device.
  final int maxAsks;

  /// Chance of asking at a moment that already passed every other gate.
  ///
  /// The prompt is meant to feel incidental rather than scheduled: two players
  /// on the same level should not both meet it, and one who dismissed it should
  /// not be able to predict its return.
  final double askChance;

  static const _settledKey = 'review_settled';
  static const _askCountKey = 'review_ask_count';
  static const _lastAskMsKey = 'review_last_ask_ms';
  static const _lastAskClearsKey = 'review_last_ask_clears';
  static const _nextGapKey = 'review_next_gap';

  static const _listingPath = 'details?id=${AppInfo.playStoreId}';
  static const _reviewPath =
      'details?id=${AppInfo.playStoreId}&showAllReviews=true';

  /// Whether the player has answered the question for good — either they went
  /// to the store, or they have used up every ask they were going to get.
  bool get hasSettled => _storage.readBool(_settledKey);

  int get askCount => _storage.readInt(_askCountKey);

  DateTime? get lastAskedAt {
    final ms = _storage.readInt(_lastAskMsKey);
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Gap rolled for the next follow-up, or the minimum if none is stored yet.
  @visibleForTesting
  int get nextAskGap {
    final stored = _storage.readInt(_nextGapKey);
    return stored == 0 ? levelsBetweenAsksMin : stored;
  }

  /// Every gate except the dice roll, so the cadence can be tested without
  /// standing in for [Random].
  @visibleForTesting
  bool isEligible({required int levelsCleared, required DateTime now}) {
    if (hasSettled) return false;
    final asks = askCount;
    if (asks >= maxAsks) return false;
    if (levelsCleared < levelsBeforeFirstAsk) return false;
    if (asks == 0) return true;

    final since = levelsCleared - _storage.readInt(_lastAskClearsKey);
    if (since < nextAskGap) return false;

    final last = lastAskedAt;
    if (last != null && now.difference(last) < cooldown) return false;
    return true;
  }

  /// Whether to put the prompt up at this exact moment.
  ///
  /// Consuming: the dice are rolled here, so a caller that asks twice about the
  /// same moment can get two different answers. Call it once, at the point you
  /// are prepared to show the dialog.
  bool shouldAskNow({required int levelsCleared, DateTime? now}) {
    if (!isEligible(levelsCleared: levelsCleared, now: now ?? DateTime.now())) {
      return false;
    }
    return _random.nextDouble() < askChance;
  }

  /// Books an ask against the budget, whichever way the player answers it.
  ///
  /// A dismissal costs the same as an acceptance by design — the point of the
  /// budget is to limit how often the player is interrupted, and being asked is
  /// the interruption.
  Future<void> recordAsked({
    required int levelsCleared,
    DateTime? now,
  }) async {
    final asks = askCount + 1;
    await _storage.writeInt(_askCountKey, asks);
    await _storage.writeInt(
      _lastAskMsKey,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await _storage.writeInt(_lastAskClearsKey, levelsCleared);
    await _storage.writeInt(_nextGapKey, _rollAskGap());
    // Spending the last ask settles the matter; there is no point keeping the
    // other bookkeeping alive for a prompt that can never fire again.
    if (asks >= maxAsks) await markSettled();
  }

  /// Inclusive roll in [[levelsBetweenAsksMin], [levelsBetweenAsksMax]].
  int _rollAskGap() {
    final span = levelsBetweenAsksMax - levelsBetweenAsksMin;
    return levelsBetweenAsksMin + _random.nextInt(span + 1);
  }

  /// Closes the subject for good.
  Future<void> markSettled() => _storage.writeBool(_settledKey, true);

  /// Runs Play's in-app review sheet, and reports whether it was even offered.
  ///
  /// Play gives no signal about what the player did in the sheet — or whether
  /// it appeared at all — so callers that need a visible destination should
  /// fall back to [openReviewPage] when this returns false.
  Future<bool> requestReview() async {
    try {
      if (!await _review.isAvailable()) return false;
      await _review.requestReview();
      return true;
    } catch (error, stack) {
      debugPrint('review request failed: $error\n$stack');
      return false;
    }
  }

  /// Opens the Play listing via store / web intents.
  ///
  /// Does not trust [InAppReview.openStoreListing] alone: that API can return
  /// without throwing even when nothing opened, which used to block HTTPS
  /// fallback and make Rate look broken.
  Future<bool> openStoreListing() => _openStorePath(_listingPath);

  /// Puts the player on the listing's review section, where they can write one.
  ///
  /// Prefer this for an explicit "Rate" tap. Play's in-app sheet is silent when
  /// the device quota is spent or the build did not come from Play.
  Future<bool> openReviewPage() => _openStorePath(_reviewPath);

  /// Explicit Rate flow: open a real Play destination the player can see.
  ///
  /// [requestReview] alone is not enough here — Play may report the API as
  /// available and still show nothing (quota / sideload), which reads as a
  /// broken Rate button. Native sheet is only a last-ditch fallback.
  Future<bool> promptForRating() async {
    if (await openReviewPage()) return true;
    return requestReview();
  }

  Future<bool> _openStorePath(String path) async {
    if (await _launch(Uri.parse('market://$path'))) return true;
    if (await _launch(Uri.parse('https://play.google.com/store/apps/$path'))) {
      return true;
    }
    // Last resort — may no-op without throwing on sideloaded / iOS builds.
    try {
      await _review.openStoreListing();
      // Plugin success is unverifiable; only claim success if a prior launch
      // already returned true. Reaching here means intents failed.
      debugPrint('store listing plugin invoked after intent failure');
    } catch (error, stack) {
      debugPrint('store listing failed: $error\n$stack');
    }
    return false;
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await _launcher(uri, mode: LaunchMode.externalApplication);
    } catch (error, stack) {
      debugPrint('review page failed for $uri: $error\n$stack');
      return false;
    }
  }
}
