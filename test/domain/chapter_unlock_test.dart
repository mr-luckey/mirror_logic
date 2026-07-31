import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

PlayerSave _saveWithStars(String chapterId, int stars) {
  // Spread the stars over whole levels so the save looks like real play.
  final progress = <String, LevelProgress>{};
  var left = stars;
  var index = 1;
  while (left > 0) {
    final awarded = left >= 3 ? 3 : left;
    final id = '${chapterId}_${index.toString().padLeft(3, '0')}';
    progress[id] = LevelProgress(levelId: id, stars: awarded, completed: true);
    left -= awarded;
    index++;
  }
  return PlayerSave(levelProgress: progress);
}

void main() {
  test('a fresh player starts with no coin', () {
    expect(const PlayerSave().coins, 0);
  });

  group('chapter unlocking', () {
    test('the first chapter is never sealed', () {
      expect(const PlayerSave().isChapterUnlocked('ch1'), isTrue);
    });

    test('every later chapter starts sealed', () {
      const save = PlayerSave();
      for (var n = 2; n <= 10; n++) {
        expect(save.isChapterUnlocked('ch$n'), isFalse, reason: 'ch$n');
      }
    });

    test('one star short keeps the next chapter sealed', () {
      final save = _saveWithStars(
        'ch1',
        GameConstants.starsToUnlockNextChapter - 1,
      );
      expect(save.isChapterUnlocked('ch2'), isFalse);
      expect(save.starsMissingToUnlock('ch2'), 1);
    });

    test('the full star count opens the next chapter only', () {
      final save = _saveWithStars(
        'ch1',
        GameConstants.starsToUnlockNextChapter,
      );
      expect(save.isChapterUnlocked('ch2'), isTrue);
      expect(save.starsMissingToUnlock('ch2'), 0);
      expect(save.isChapterUnlocked('ch3'), isFalse);
    });

    test('stars from ch1 do not count towards ch10', () {
      // `ch1` must not prefix-match `ch10`, or clearing the first hall would
      // hand the player the last one.
      final save = _saveWithStars(
        'ch1',
        GameConstants.starsToUnlockNextChapter,
      );
      expect(save.isChapterUnlocked('ch10'), isFalse);
    });
  });
}
