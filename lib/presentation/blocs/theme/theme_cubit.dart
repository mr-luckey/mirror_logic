import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/domain/theme/visual_theme.dart';
import 'package:mirror_logic/infrastructure/art/game_art.dart';

enum ThemeActionResult {
  equipped,
  purchased,
  locked,
  unaffordable,
  alreadyOwned,
}

class ThemeCubitState extends Equatable {
  const ThemeCubitState({
    required this.selectedThemeId,
    required this.ownedThemeIds,
    required this.highestDisplayLevel,
    required this.coins,
    this.lastResult,
  });

  final String selectedThemeId;
  final List<String> ownedThemeIds;
  final int highestDisplayLevel;
  final int coins;
  final ThemeActionResult? lastResult;

  VisualTheme get selected => ThemeCatalog.byId(selectedThemeId);

  bool owns(String id) =>
      GameConstants.unlockAllThemesForTesting || ownedThemeIds.contains(id);

  bool isLevelUnlocked(VisualTheme theme) {
    if (GameConstants.unlockAllThemesForTesting) return true;
    return highestDisplayLevel >= theme.unlockLevel;
  }

  ThemeCubitState copyWith({
    String? selectedThemeId,
    List<String>? ownedThemeIds,
    int? highestDisplayLevel,
    int? coins,
    ThemeActionResult? lastResult,
    bool clearResult = false,
  }) {
    return ThemeCubitState(
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      ownedThemeIds: ownedThemeIds ?? this.ownedThemeIds,
      highestDisplayLevel: highestDisplayLevel ?? this.highestDisplayLevel,
      coins: coins ?? this.coins,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    );
  }

  @override
  List<Object?> get props => [
    selectedThemeId,
    ownedThemeIds,
    highestDisplayLevel,
    coins,
    lastResult,
  ];
}

class ThemeCubit extends Cubit<ThemeCubitState> {
  ThemeCubit({
    required SaveRepository saveRepository,
    required EconomyRepository economyRepository,
  }) : _saveRepository = saveRepository,
       _economyRepository = economyRepository,
       super(_fromSave(saveRepository.loadSave())) {
    unawaited(_ensureStarterOwned());
    ThemeController.applyById(state.selectedThemeId);
  }

  final SaveRepository _saveRepository;
  final EconomyRepository _economyRepository;

  /// Hall being previewed on the home carousel, if it is not the equipped one.
  String? _previewedThemeId;

  static ThemeCubitState _fromSave(PlayerSave save) {
    return ThemeCubitState(
      selectedThemeId: save.selectedThemeId,
      ownedThemeIds: List<String>.from(save.ownedThemeIds),
      highestDisplayLevel: save.highestDisplayLevel,
      coins: save.coins,
    );
  }

  /// Starter hall is always owned; paid halls stay locked until bought.
  Future<void> _ensureStarterOwned() async {
    final save = _saveRepository.loadSave();
    if (save.ownsTheme(ThemeCatalog.starterId) &&
        save.ownsTheme(save.selectedThemeId)) {
      return;
    }
    final owned = save.ownsTheme(ThemeCatalog.starterId)
        ? save.ownedThemeIds
        : [ThemeCatalog.starterId, ...save.ownedThemeIds];
    final selected = owned.contains(save.selectedThemeId)
        ? save.selectedThemeId
        : ThemeCatalog.starterId;
    final next = save.copyWith(
      saveSchemaVersion: 2,
      ownedThemeIds: owned,
      selectedThemeId: selected,
    );
    await _saveRepository.persistSave(next);
    emit(_fromSave(next).copyWith(clearResult: true));
    ThemeController.applyById(selected);
  }

  /// Sync from ProgressBloc after a level clear or coin change.
  ///
  /// A save write must not yank a hall the player is browsing off the screen,
  /// so an open preview keeps the display while [state] tracks what is owned.
  void syncFromSave(PlayerSave save) {
    emit(_fromSave(save).copyWith(clearResult: true));
    final display = _previewedThemeId ?? save.selectedThemeId;
    ThemeController.applyById(display);
    unawaited(GameArt.loadForTheme(display));
  }

  void syncCoins(int coins) {
    if (coins == state.coins) return;
    emit(state.copyWith(coins: coins, clearResult: true));
  }

  Future<ThemeActionResult> selectOrBuy(String themeId) async {
    final theme = ThemeCatalog.byId(themeId);

    if (state.owns(themeId)) {
      return _equip(themeId);
    }

    if (!state.isLevelUnlocked(theme)) {
      emit(state.copyWith(lastResult: ThemeActionResult.locked));
      return ThemeActionResult.locked;
    }

    if (theme.isFree) {
      return _purchaseFree(themeId);
    }

    final spent = await _economyRepository.spendCoins(theme.coinPrice);
    if (spent == null) {
      emit(state.copyWith(lastResult: ThemeActionResult.unaffordable));
      return ThemeActionResult.unaffordable;
    }

    final owned = List<String>.from(spent.ownedThemeIds);
    if (!owned.contains(themeId)) owned.add(themeId);
    final next = spent.copyWith(ownedThemeIds: owned, selectedThemeId: themeId);
    await _saveRepository.persistSave(next);
    _previewedThemeId = null;
    ThemeController.applyById(themeId);
    unawaited(GameArt.loadForTheme(themeId));
    emit(_fromSave(next).copyWith(lastResult: ThemeActionResult.purchased));
    return ThemeActionResult.purchased;
  }

  Future<ThemeActionResult> _purchaseFree(String themeId) async {
    final save = _saveRepository.loadSave();
    if (save.ownsTheme(themeId)) {
      return _equip(themeId);
    }
    final owned = List<String>.from(save.ownedThemeIds)..add(themeId);
    final next = save.copyWith(ownedThemeIds: owned, selectedThemeId: themeId);
    await _saveRepository.persistSave(next);
    _previewedThemeId = null;
    ThemeController.applyById(themeId);
    unawaited(GameArt.loadForTheme(themeId));
    emit(_fromSave(next).copyWith(lastResult: ThemeActionResult.purchased));
    return ThemeActionResult.purchased;
  }

  Future<ThemeActionResult> _equip(String themeId) async {
    _previewedThemeId = null;
    final save = _saveRepository.loadSave();
    if (save.selectedThemeId == themeId) {
      ThemeController.applyById(themeId);
      unawaited(GameArt.loadForTheme(themeId));
      emit(state.copyWith(lastResult: ThemeActionResult.alreadyOwned));
      return ThemeActionResult.alreadyOwned;
    }
    final next = save.copyWith(selectedThemeId: themeId);
    await _saveRepository.persistSave(next);
    ThemeController.applyById(themeId);
    unawaited(GameArt.loadForTheme(themeId));
    emit(_fromSave(next).copyWith(lastResult: ThemeActionResult.equipped));
    return ThemeActionResult.equipped;
  }

  /// Live hall preview while the home carousel is scrolling — colors swap
  /// immediately, board art reloads, no toast spam.
  void previewHall(String themeId) {
    _previewedThemeId = themeId == state.selectedThemeId ? null : themeId;
    if (ThemeController.current.id == themeId) return;
    ThemeController.applyById(themeId);
    unawaited(GameArt.loadForTheme(themeId));
  }

  /// Drops a locked-hall preview and puts the owned hall back on screen.
  ///
  /// Previewing never touches [state], so the equipped id is still the one the
  /// player paid for — the board must not open dressed in a hall they browsed.
  void restoreEquippedTheme() {
    _previewedThemeId = null;
    final equipped = state.selectedThemeId;
    if (ThemeController.current.id == equipped) return;
    ThemeController.applyById(equipped);
    unawaited(GameArt.loadForTheme(equipped));
  }

  /// Final hall selection — Continue / Play on an owned carousel page.
  ///
  /// Previewing on swipe never reaches here; only an explicit confirm writes
  /// [selectedThemeId] and keeps that hall until the next confirm.
  Future<ThemeActionResult> confirmHall(String themeId) async {
    if (!state.owns(themeId)) {
      emit(state.copyWith(lastResult: ThemeActionResult.locked));
      return ThemeActionResult.locked;
    }
    return _equip(themeId);
  }
}
