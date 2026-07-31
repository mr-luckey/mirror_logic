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

  Future<void> resetProgress() async {
    await _storage.writeJson(_saveKey, const PlayerSave().toJson());
  }
}
