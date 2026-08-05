import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

import '../support/memory_box.dart';

void main() {
  late SaveRepository saves;
  late EconomyRepository economy;

  setUp(() {
    saves = SaveRepository(LocalStorageService(MemoryBox()));
    economy = EconomyRepository(saves);
  });

  group('PlayerSave rewarded ads', () {
    test('defaults missing fields to zero for old saves', () {
      final save = PlayerSave.fromJson(const {'coins': 12});

      expect(save.rewardedAdsWatched, 0);
      expect(save.rewardedAdsWindowStartMs, 0);
    });

    test('round-trips rewarded ad fields', () {
      const save = PlayerSave(
        coins: 40,
        rewardedAdsWatched: 7,
        rewardedAdsWindowStartMs: 1_700_000_000_000,
      );

      final restored = PlayerSave.fromJson(save.toJson());
      expect(restored.rewardedAdsWatched, 7);
      expect(restored.rewardedAdsWindowStartMs, 1_700_000_000_000);
    });
  });

  group('normalizeRewardedAdWindow', () {
    test('clears an expired rolling window', () {
      final started = DateTime(2026, 1, 1, 12);
      final now = started.add(GameConstants.rewardedAdsWindow);
      final save = PlayerSave(
        rewardedAdsWatched: 10,
        rewardedAdsWindowStartMs: started.millisecondsSinceEpoch,
      );

      final normalized = EconomyRepository.normalizeRewardedAdWindow(
        save,
        now: now,
      );

      expect(normalized.rewardedAdsWatched, 0);
      expect(normalized.rewardedAdsWindowStartMs, 0);
    });

    test('keeps an active window intact', () {
      final started = DateTime(2026, 1, 1, 12);
      final now = started.add(const Duration(hours: 12));
      final save = PlayerSave(
        rewardedAdsWatched: 10,
        rewardedAdsWindowStartMs: started.millisecondsSinceEpoch,
      );

      final normalized = EconomyRepository.normalizeRewardedAdWindow(
        save,
        now: now,
      );

      expect(normalized, save);
    });
  });

  group('grantRewardedAdCoins', () {
    test('starts a window on the first earned ad', () async {
      final now = DateTime(2026, 2, 1, 9, 30);

      final grant = await economy.grantRewardedAdCoins(now: now);

      expect(grant.result, RewardedAdGrantResult.granted);
      expect(grant.save.coins, GameConstants.coinsPerRewardedAd);
      expect(grant.save.rewardedAdsWatched, 1);
      expect(grant.save.rewardedAdsWindowStartMs, now.millisecondsSinceEpoch);
    });

    test('adds five coins per earned ad inside the window', () async {
      final now = DateTime(2026, 2, 1, 9, 30);
      await saves.persistSave(
        PlayerSave(
          coins: 20,
          rewardedAdsWatched: 3,
          rewardedAdsWindowStartMs: now.millisecondsSinceEpoch,
        ),
      );

      final grant = await economy.grantRewardedAdCoins(now: now);

      expect(grant.save.coins, 25);
      expect(grant.save.rewardedAdsWatched, 4);
    });

    test('rejects once the 20-ad quota is reached', () async {
      final now = DateTime(2026, 2, 1, 9, 30);
      await saves.persistSave(
        PlayerSave(
          coins: 100,
          rewardedAdsWatched: GameConstants.maxRewardedAdsPerWindow,
          rewardedAdsWindowStartMs: now.millisecondsSinceEpoch,
        ),
      );

      final grant = await economy.grantRewardedAdCoins(now: now);

      expect(grant.result, RewardedAdGrantResult.quotaExceeded);
      expect(grant.save.coins, 100);
      expect(grant.save.rewardedAdsWatched, 20);
    });

    test('resets quota after 24 hours before granting', () async {
      final started = DateTime(2026, 2, 1, 9, 30);
      final now = started.add(GameConstants.rewardedAdsWindow);
      await saves.persistSave(
        PlayerSave(
          coins: 50,
          rewardedAdsWatched: 12,
          rewardedAdsWindowStartMs: started.millisecondsSinceEpoch,
        ),
      );

      final grant = await economy.grantRewardedAdCoins(now: now);

      expect(grant.result, RewardedAdGrantResult.granted);
      expect(grant.save.rewardedAdsWatched, 1);
      expect(grant.save.coins, 50 + GameConstants.coinsPerRewardedAd);
      expect(grant.save.rewardedAdsWindowStartMs, now.millisecondsSinceEpoch);
    });
  });

  group('resetProgress', () {
    test('keeps rewarded ad quota fields', () async {
      await saves.persistSave(
        const PlayerSave(
          coins: 80,
          rewardedAdsWatched: 9,
          rewardedAdsWindowStartMs: 1_700_000_000_000,
        ),
      );

      await saves.resetProgress();

      final save = saves.loadSave();
      expect(save.rewardedAdsWatched, 9);
      expect(save.rewardedAdsWindowStartMs, 1_700_000_000_000);
    });
  });
}
