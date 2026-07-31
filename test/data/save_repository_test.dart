import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

import '../support/memory_box.dart';

void main() {
  late SaveRepository saves;

  setUp(() => saves = SaveRepository(LocalStorageService(MemoryBox())));

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
}
