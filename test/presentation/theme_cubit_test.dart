import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';

import '../support/memory_box.dart';

void main() {
  late SaveRepository saves;
  late EconomyRepository economy;
  late ThemeCubit cubit;

  setUp(() {
    saves = SaveRepository(LocalStorageService(MemoryBox()));
    economy = EconomyRepository(saves);
    cubit = ThemeCubit(saveRepository: saves, economyRepository: economy);
  });

  tearDown(() async {
    await cubit.close();
    ThemeController.applyById(ThemeCatalog.starterId);
  });

  test('previewHall applies colors without persisting ownership', () {
    const lockedId = 'moonlight_castle';
    final before = saves.loadSave();

    cubit.previewHall(lockedId);

    expect(ThemeController.current.id, lockedId);
    expect(saves.loadSave().selectedThemeId, before.selectedThemeId);
    expect(saves.loadSave().ownedThemeIds, before.ownedThemeIds);
    expect(cubit.state.owns(lockedId), isFalse);
  });

  test('a coin sync does not cancel an open preview', () {
    const lockedId = 'moonlight_castle';
    cubit.previewHall(lockedId);

    cubit.syncFromSave(saves.loadSave().copyWith(coins: 999));

    expect(ThemeController.current.id, lockedId);
    expect(cubit.state.selectedThemeId, ThemeCatalog.starterId);
  });

  test('restoreEquippedTheme drops a locked preview', () {
    cubit.previewHall('moonlight_castle');

    cubit.restoreEquippedTheme();

    expect(ThemeController.current.id, cubit.state.selectedThemeId);
    expect(ThemeController.current.id, ThemeCatalog.starterId);
  });

  test('confirmHall ignores unowned halls', () async {
    const lockedId = 'frozen_kingdom';

    final result = await cubit.confirmHall(lockedId);

    expect(result, ThemeActionResult.locked);
    expect(cubit.state.selectedThemeId, isNot(lockedId));
    expect(saves.loadSave().selectedThemeId, isNot(lockedId));
  });

  test('confirmHall persists an owned hall as the selection', () async {
    const ownedId = 'moonlight_castle';
    await saves.persistSave(
      saves.loadSave().copyWith(
        ownedThemeIds: [ThemeCatalog.starterId, ownedId],
      ),
    );
    cubit.syncFromSave(saves.loadSave());

    final result = await cubit.confirmHall(ownedId);

    expect(result, ThemeActionResult.equipped);
    expect(cubit.state.selectedThemeId, ownedId);
    expect(saves.loadSave().selectedThemeId, ownedId);
    expect(ThemeController.current.id, ownedId);
  });

  test('preview does not change selectedThemeId until confirmHall', () async {
    const ownedId = 'moonlight_castle';
    await saves.persistSave(
      saves.loadSave().copyWith(
        ownedThemeIds: [ThemeCatalog.starterId, ownedId],
      ),
    );
    cubit.syncFromSave(saves.loadSave());

    cubit.previewHall(ownedId);
    expect(ThemeController.current.id, ownedId);
    expect(cubit.state.selectedThemeId, ThemeCatalog.starterId);
    expect(saves.loadSave().selectedThemeId, ThemeCatalog.starterId);

    await cubit.confirmHall(ownedId);
    expect(cubit.state.selectedThemeId, ownedId);
    expect(saves.loadSave().selectedThemeId, ownedId);
  });
}
