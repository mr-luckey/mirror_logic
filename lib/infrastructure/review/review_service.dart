import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

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
class ReviewService {
  ReviewService({
    required LocalStorageService storage,
    InAppReview? review,
    Random? random,
    this.levelsBeforeFirstAsk = 4,
    this.levelsBetweenAsks = 12,
    this.cooldown = const Duration(days: 5),
    this.maxAsks = 3,
    this.askChance = 0.3,
  }) : _storage = storage,
       _review = review ?? InAppReview.instance,
       _random = random ?? Random();

  final LocalStorageService _storage;
  final InAppReview _review;
  final Random _random;

  /// Clears a player owes before the first ask. Nobody who has solved three
  /// boards knows yet whether they like the game.
  final int levelsBeforeFirstAsk;

  /// Further clears between one ask and the next, so a second prompt lands
  /// after real play rather than on the next screen.
  final int levelsBetweenAsks;

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

  /// Whether the player has answered the question for good — either they went
  /// to the store, or they have used up every ask they were going to get.
  bool get hasSettled => _storage.readBool(_settledKey);

  int get askCount => _storage.readInt(_askCountKey);

  DateTime? get lastAskedAt {
    final ms = _storage.readInt(_lastAskMsKey);
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
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
    if (since < levelsBetweenAsks) return false;

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
  Future<void> recordAsked({required int levelsCleared}) async {
    final asks = askCount + 1;
    await _storage.writeInt(_askCountKey, asks);
    await _storage.writeInt(
      _lastAskMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _storage.writeInt(_lastAskClearsKey, levelsCleared);
    // Spending the last ask settles the matter; there is no point keeping the
    // other bookkeeping alive for a prompt that can never fire again.
    if (asks >= maxAsks) await markSettled();
  }

  /// Closes the subject for good.
  Future<void> markSettled() => _storage.writeBool(_settledKey, true);

  /// Runs Play's in-app review sheet, and reports whether it was even offered.
  ///
  /// This is the path the random prompt takes. Play gives no signal about what
  /// the player did in the sheet — or whether it appeared at all — so the
  /// subject is settled either way rather than re-asked on a maybe.
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

  /// Opens the Play listing.
  ///
  /// This is the path the About and Settings buttons take, rather than the
  /// in-app sheet: a player who deliberately tapped "Rate" must land somewhere
  /// visible, and the sheet does nothing at all once the quota is spent — which
  /// reads as a broken button.
  Future<bool> openStoreListing() async {
    try {
      await _review.openStoreListing();
      return true;
    } catch (error, stack) {
      debugPrint('store listing failed: $error\n$stack');
      return false;
    }
  }
}
