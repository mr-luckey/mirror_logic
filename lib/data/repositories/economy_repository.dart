import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

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

  /// Clearing any level pays the same flat purse.
  int coinsForClear() => GameConstants.coinsPerLevel;

  @Deprecated('Stars no longer change the purse; use coinsForClear()')
  int coinsForStars(int stars) => coinsForClear();
}
