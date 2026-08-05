import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

enum RewardedAdGrantResult { granted, quotaExceeded }

class EconomyRepository {
  EconomyRepository(this._saveRepository);

  final SaveRepository _saveRepository;

  int getCoins() => _saveRepository.loadSave().coins;

  Future<PlayerSave> addCoins(int amount) async {
    final save = _saveRepository.loadSave();
    final next = save.copyWith(coins: save.coins + amount);
    await _saveRepository.persistSave(next);
    return next;
  }

  Future<PlayerSave?> spendCoins(int amount) async {
    final save = _saveRepository.loadSave();
    if (save.coins < amount) return null;
    final next = save.copyWith(coins: save.coins - amount);
    await _saveRepository.persistSave(next);
    return next;
  }

  /// Normalizes an expired rewarded-ad window and persists when it changed.
  Future<PlayerSave> loadNormalizedSave({DateTime? now}) async {
    final save = _saveRepository.loadSave();
    final normalized = normalizeRewardedAdWindow(save, now: now);
    if (normalized != save) {
      await _saveRepository.persistSave(normalized);
    }
    return normalized;
  }

  /// Grants coins for one fully watched rewarded ad in a single save write.
  Future<({RewardedAdGrantResult result, PlayerSave save})>
  grantRewardedAdCoins({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    var save = await loadNormalizedSave(now: clock);

    if (save.rewardedAdsWatched >= GameConstants.maxRewardedAdsPerWindow) {
      return (result: RewardedAdGrantResult.quotaExceeded, save: save);
    }

    final windowStart = save.rewardedAdsWindowStartMs == 0
        ? clock.millisecondsSinceEpoch
        : save.rewardedAdsWindowStartMs;

    final next = save.copyWith(
      coins: save.coins + GameConstants.coinsPerRewardedAd,
      rewardedAdsWatched: save.rewardedAdsWatched + 1,
      rewardedAdsWindowStartMs: windowStart,
    );
    await _saveRepository.persistSave(next);
    return (result: RewardedAdGrantResult.granted, save: next);
  }

  /// Clears an expired rolling window without mutating the save on disk.
  static PlayerSave normalizeRewardedAdWindow(
    PlayerSave save, {
    DateTime? now,
  }) {
    if (save.rewardedAdsWindowStartMs == 0) return save;

    final started = DateTime.fromMillisecondsSinceEpoch(
      save.rewardedAdsWindowStartMs,
    );
    final elapsed = (now ?? DateTime.now()).difference(started);
    if (elapsed < GameConstants.rewardedAdsWindow) return save;

    return save.copyWith(rewardedAdsWatched: 0, rewardedAdsWindowStartMs: 0);
  }

  /// Clearing any level pays the same flat purse.
  int coinsForClear() => GameConstants.coinsPerLevel;

  @Deprecated('Stars no longer change the purse; use coinsForClear()')
  int coinsForStars(int stars) => coinsForClear();
}
