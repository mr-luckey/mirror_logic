import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit({required SaveRepository saveRepository})
    : _saveRepository = saveRepository,
      super(const AppSettings());

  final SaveRepository _saveRepository;

  Future<void> load() async {
    emit(_saveRepository.loadSettings());
  }

  Future<void> setMusicVolume(double value) async {
    final next = state.copyWith(musicVolume: value);
    emit(next);
    await _saveRepository.persistSettings(next);
  }

  Future<void> setSfxVolume(double value) async {
    final next = state.copyWith(sfxVolume: value);
    emit(next);
    await _saveRepository.persistSettings(next);
  }

  Future<void> setHaptics(bool value) async {
    final next = state.copyWith(haptics: value);
    emit(next);
    await _saveRepository.persistSettings(next);
  }

  Future<void> setAssistMode(bool value) async {
    final next = state.copyWith(assistMode: value);
    emit(next);
    await _saveRepository.persistSettings(next);
  }

  Future<void> setAngleReadout(bool value) async {
    final next = state.copyWith(angleReadout: value);
    emit(next);
    await _saveRepository.persistSettings(next);
  }
}
