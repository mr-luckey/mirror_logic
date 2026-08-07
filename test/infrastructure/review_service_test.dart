import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/core/constants/app_info.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../support/memory_box.dart';

/// A die that always comes up under any threshold, so the cadence gates are the
/// only thing deciding whether the prompt fires. Gaps always roll the minimum.
class _AlwaysRoll implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverRoll implements Random {
  @override
  double nextDouble() => 1;

  @override
  int nextInt(int max) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Always rolls the maximum gap so follow-up eligibility can be checked at the
/// far end of the 5–10 window.
class _MaxGapRoll implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ReviewService build({Random? random}) => ReviewService(
    storage: LocalStorageService(MemoryBox()),
    random: random ?? _AlwaysRoll(),
    levelsBeforeFirstAsk: 7,
    levelsBetweenAsksMin: 5,
    levelsBetweenAsksMax: 10,
    cooldown: const Duration(days: 5),
    maxAsks: 3,
    askChance: 0.35,
  );

  // Fixed clock so recordAsked and cooldown checks share one timeline.
  final now = DateTime(2026, 8, 1, 12);

  group('eligibility', () {
    test('stays quiet through the early tutorial boards', () {
      final review = build();
      expect(review.isEligible(levelsCleared: 3, now: now), isFalse);
      expect(review.isEligible(levelsCleared: 6, now: now), isFalse);
      expect(review.isEligible(levelsCleared: 7, now: now), isTrue);
    });

    test('never asks again once the matter is settled', () async {
      final review = build();
      await review.markSettled();
      expect(review.isEligible(levelsCleared: 40, now: now), isFalse);
    });

    test('a second ask waits for a rolled gap and more time', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 7, now: now);
      // AlwaysRoll picks the minimum gap of 5.
      expect(review.nextAskGap, 5);

      // Same sitting, a few more boards: too soon on both counts.
      expect(review.isEligible(levelsCleared: 10, now: now), isFalse);
      // Enough boards, but the cooldown has not run out.
      expect(review.isEligible(levelsCleared: 12, now: now), isFalse);
      // Enough time, but the player has barely played since.
      expect(
        review.isEligible(
          levelsCleared: 10,
          now: now.add(const Duration(days: 6)),
        ),
        isFalse,
      );
      // Both satisfied.
      expect(
        review.isEligible(
          levelsCleared: 12,
          now: now.add(const Duration(days: 6)),
        ),
        isTrue,
      );
    });

    test('follow-up gap can stretch to the top of the 5–10 window', () async {
      final review = build(random: _MaxGapRoll());
      await review.recordAsked(levelsCleared: 7, now: now);
      expect(review.nextAskGap, 10);

      expect(
        review.isEligible(
          levelsCleared: 16,
          now: now.add(const Duration(days: 6)),
        ),
        isFalse,
      );
      expect(
        review.isEligible(
          levelsCleared: 17,
          now: now.add(const Duration(days: 6)),
        ),
        isTrue,
      );
    });

    test('spending the last ask settles the matter', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 7);
      await review.recordAsked(levelsCleared: 20);
      expect(review.hasSettled, isFalse);

      await review.recordAsked(levelsCleared: 40);
      expect(review.askCount, 3);
      expect(review.hasSettled, isTrue);
      expect(review.isEligible(levelsCleared: 100, now: now), isFalse);
    });

    test('a dismissal costs an ask, same as accepting', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 7);
      expect(review.askCount, 1);
      expect(review.lastAskedAt, isNotNull);
    });
  });

  group('shouldAskNow', () {
    test('an eligible moment can still lose the roll', () {
      expect(
        build(random: _NeverRoll()).shouldAskNow(levelsCleared: 40),
        isFalse,
      );
    });

    test('a winning roll on an ineligible moment still asks nothing', () {
      expect(build().shouldAskNow(levelsCleared: 1), isFalse);
    });

    test('an eligible moment with a winning roll asks', () {
      expect(build().shouldAskNow(levelsCleared: 40), isTrue);
    });
  });

  group('openReviewPage', () {
    test('opens the Play review intent with the app id', () async {
      Uri? launched;
      final review = ReviewService(
        storage: LocalStorageService(MemoryBox()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) {
          launched = uri;
          return Future.value(true);
        },
      );

      final ok = await review.openReviewPage();

      expect(ok, isTrue);
      expect(launched, isNotNull);
      expect(launched!.toString(), contains(AppInfo.playStoreId));
      expect(launched.toString(), contains('showAllReviews=true'));
    });

    test('falls back to https when market intent fails', () async {
      final launched = <Uri>[];
      final review = ReviewService(
        storage: LocalStorageService(MemoryBox()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) {
          launched.add(uri);
          if (uri.scheme == 'market') return Future.value(false);
          return Future.value(true);
        },
      );

      final ok = await review.openReviewPage();

      expect(ok, isTrue);
      expect(launched.length, 2);
      expect(launched.first.scheme, 'market');
      expect(launched.last.scheme, 'https');
      expect(launched.last.toString(), contains('showAllReviews=true'));
    });
  });

  group('openStoreListing', () {
    test('uses market then https rather than claiming plugin success', () async {
      final launched = <Uri>[];
      final review = ReviewService(
        storage: LocalStorageService(MemoryBox()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) {
          launched.add(uri);
          if (uri.scheme == 'market') return Future.value(false);
          return Future.value(true);
        },
      );

      final ok = await review.openStoreListing();

      expect(ok, isTrue);
      expect(launched.last.scheme, 'https');
      expect(launched.last.toString(), isNot(contains('showAllReviews')));
    });
  });
}
