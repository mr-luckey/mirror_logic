import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

import '../support/memory_box.dart';

void main() {
  late SaveRepository saves;

  setUp(() => saves = SaveRepository(LocalStorageService(MemoryBox())));

  group('continueLevelId', () {
    test('is the first level on a fresh save', () {
      expect(const PlayerSave().continueLevelId, 'ch1_001');
    });

    test('is the furthest unlocked level, not the last one played', () {
      const save = PlayerSave(
        unlockedLevelIds: ['ch1_001', 'ch1_002', 'ch1_003'],
        lastPlayedLevelId: 'ch1_002',
      );

      expect(save.continueLevelId, 'ch1_003');
    });

    test('counts chapters rather than comparing ids as strings', () {
      const save = PlayerSave(
        unlockedLevelIds: ['ch1_001', 'ch2_004', 'ch1_099'],
        lastPlayedLevelId: 'ch1_099',
      );

      expect(save.continueLevelId, 'ch2_004');
    });
  });

  group('resetProgress', () {
    test('keeps the coin the player earned', () async {
      await saves.persistSave(const PlayerSave(coins: 137));

      await saves.resetProgress();

      expect(saves.loadSave().coins, 137);
    });

    test('clears stars, unlocks and last played', () async {
      await saves.persistSave(
        const PlayerSave(
          coins: 40,
          unlockedLevelIds: ['ch1_001', 'ch1_002', 'ch2_001'],
          lastPlayedLevelId: 'ch2_014',
          hintsUsedTotal: 6,
          levelProgress: {
            'ch1_001': LevelProgress(
              levelId: 'ch1_001',
              stars: 3,
              completed: true,
            ),
          },
        ),
      );

      await saves.resetProgress();

      final save = saves.loadSave();
      expect(save.levelProgress, isEmpty);
      expect(save.lastPlayedLevelId, isNull);
      expect(save.hintsUsedTotal, 0);
      expect(save.unlockedLevelIds, const PlayerSave().unlockedLevelIds);
    });
  });

  group('in-memory cache', () {
    test('loadSave sees a theme write before disk flush finishes', () async {
      await saves.persistSave(const PlayerSave(selectedThemeId: 'golden_sun'));

      // Fire a theme change without awaiting the disk write chain.
      final pending = saves.persistSave(
        saves.loadSave().copyWith(selectedThemeId: 'moonlight_castle'),
      );

      expect(saves.loadSave().selectedThemeId, 'moonlight_castle');
      await pending;
      expect(saves.loadSave().selectedThemeId, 'moonlight_castle');
    });
  });
}
