import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

class SaveRepository {
  SaveRepository(this._storage);

  final LocalStorageService _storage;
  static const _saveKey = 'player_save';
  static const _settingsKey = 'app_settings';

  PlayerSave loadSave() {
    final json = _storage.readJson(_saveKey);
    if (json == null) return const PlayerSave();
    // Losing progress is bad; refusing to launch is worse.
    try {
      return PlayerSave.fromJson(json);
    } catch (_) {
      return const PlayerSave();
    }
  }

  Future<void> persistSave(PlayerSave save) async {
    await _storage.writeJson(_saveKey, save.toJson());
  }

  AppSettings loadSettings() {
    final json = _storage.readJson(_settingsKey);
    if (json == null) return const AppSettings();
    try {
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> persistSettings(AppSettings settings) async {
    await _storage.writeJson(_settingsKey, settings.toJson());
  }

  /// Wipes stars, unlocks and last-played, but keeps the purse and themes.
  ///
  /// Coins are earned currency; a player clearing their progress to replay the
  /// game has not asked to be charged for it. The tutorial flag stays too —
  /// nobody resetting their stars is asking to be taught the rules again.
  /// Owned halls stay as well — they were paid for with those coins.
  Future<void> resetProgress() async {
    final current = loadSave();
    await _storage.writeJson(
      _saveKey,
      PlayerSave(
        coins: current.coins,
        onboardingComplete: current.onboardingComplete,
        walkthroughSeen: current.walkthroughSeen,
        ownedThemeIds: current.ownedThemeIds,
        selectedThemeId: current.selectedThemeId,
      ).toJson(),
    );
  }
}
