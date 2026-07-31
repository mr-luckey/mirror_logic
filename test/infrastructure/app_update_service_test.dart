import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';

import '../support/memory_box.dart';

void main() {
  AppUpdateKind classify({
    bool available = true,
    bool immediateAllowed = true,
    bool flexibleAllowed = true,
    int priority = 0,
    int? stalenessDays,
  }) {
    return AppUpdateService.classify(
      available: available,
      immediateAllowed: immediateAllowed,
      flexibleAllowed: flexibleAllowed,
      priority: priority,
      stalenessDays: stalenessDays,
      immediatePriority: 4,
      immediateStalenessDays: 21,
    );
  }

  group('classify', () {
    test('nothing on offer means nothing to do', () {
      expect(classify(available: false), AppUpdateKind.none);
    });

    test('a routine release downloads in the background', () {
      expect(classify(), AppUpdateKind.flexible);
    });

    test('a high-priority release takes over the screen', () {
      expect(classify(priority: 4), AppUpdateKind.immediate);
    });

    test('an update the device has sat on for weeks is forced', () {
      expect(classify(stalenessDays: 21), AppUpdateKind.immediate);
      expect(classify(stalenessDays: 20), AppUpdateKind.flexible);
    });

    test('a missing staleness figure is not treated as stale', () {
      expect(classify(stalenessDays: null), AppUpdateKind.flexible);
    });

    test('an urgent update Play will not run immediately falls back', () {
      // Play refuses the immediate flow on, say, a metered connection. Getting
      // the update by the slower route beats not offering it at all.
      expect(
        classify(priority: 5, immediateAllowed: false),
        AppUpdateKind.flexible,
      );
    });

    test('the blocking flow is used when it is the only one allowed', () {
      expect(classify(flexibleAllowed: false), AppUpdateKind.immediate);
    });

    test('an update neither flow can run is left alone', () {
      expect(
        classify(flexibleAllowed: false, immediateAllowed: false),
        AppUpdateKind.none,
      );
    });
  });

  group('postponing', () {
    late AppUpdateService updates;
    final now = DateTime(2026, 8, 1, 12);

    setUp(() {
      updates = AppUpdateService(
        storage: LocalStorageService(MemoryBox()),
        postponeFor: const Duration(days: 1),
      );
    });

    test('nothing is postponed to begin with', () {
      expect(updates.isPostponed(42), isFalse);
    });

    test('a declined version stays quiet until the snooze expires', () async {
      await updates.postpone(42);
      expect(updates.isPostponed(42), isTrue);
      expect(
        updates.isPostponed(42, now: now.add(const Duration(days: 400))),
        isFalse,
      );
    });

    test('a newer build is offered even inside the snooze', () async {
      // Declining 42 says nothing about 43, so shipping again reaches the
      // player rather than being swallowed by the old snooze.
      await updates.postpone(42);
      expect(updates.isPostponed(43), isFalse);
    });
  });
}
