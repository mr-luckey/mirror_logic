import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

import '../support/memory_box.dart';

/// A die that always comes up under any threshold, so the cadence gates are the
/// only thing deciding whether the prompt fires.
class _AlwaysRoll implements Random {
  @override
  double nextDouble() => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverRoll implements Random {
  @override
  double nextDouble() => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ReviewService build({Random? random}) => ReviewService(
    storage: LocalStorageService(MemoryBox()),
    random: random ?? _AlwaysRoll(),
    levelsBeforeFirstAsk: 4,
    levelsBetweenAsks: 12,
    cooldown: const Duration(days: 5),
    maxAsks: 3,
    askChance: 0.3,
  );

  final now = DateTime(2026, 8, 1, 12);

  group('eligibility', () {
    test('stays quiet until the player has solved enough boards', () {
      final review = build();
      expect(review.isEligible(levelsCleared: 3, now: now), isFalse);
      expect(review.isEligible(levelsCleared: 4, now: now), isTrue);
    });

    test('never asks again once the matter is settled', () async {
      final review = build();
      await review.markSettled();
      expect(review.isEligible(levelsCleared: 40, now: now), isFalse);
    });

    test('a second ask waits for both more play and more time', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 4);

      // Same sitting, a few more boards: too soon on both counts.
      expect(review.isEligible(levelsCleared: 10, now: now), isFalse);
      // Enough boards, but the cooldown has not run out.
      expect(review.isEligible(levelsCleared: 16, now: now), isFalse);
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
          levelsCleared: 16,
          now: now.add(const Duration(days: 6)),
        ),
        isTrue,
      );
    });

    test('spending the last ask settles the matter', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 4);
      await review.recordAsked(levelsCleared: 20);
      expect(review.hasSettled, isFalse);

      await review.recordAsked(levelsCleared: 40);
      expect(review.askCount, 3);
      expect(review.hasSettled, isTrue);
      expect(review.isEligible(levelsCleared: 100, now: now), isFalse);
    });

    test('a dismissal costs an ask, same as accepting', () async {
      final review = build();
      await review.recordAsked(levelsCleared: 4);
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
}
