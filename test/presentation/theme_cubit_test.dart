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

  test('equipFromCarousel ignores unowned halls', () async {
    const lockedId = 'frozen_kingdom';

    await cubit.equipFromCarousel(lockedId);

    expect(cubit.state.selectedThemeId, isNot(lockedId));
    expect(saves.loadSave().selectedThemeId, isNot(lockedId));
  });
}
