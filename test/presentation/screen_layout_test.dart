import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_theme.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/economy/rewarded_coins_cubit.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';
import 'package:mirror_logic/presentation/screens/about/about_screen.dart';
import 'package:mirror_logic/presentation/screens/chapter_select/chapter_select_screen.dart';
import 'package:mirror_logic/presentation/screens/level_complete/level_complete_screen.dart';
import 'package:mirror_logic/presentation/screens/level_select/level_select_screen.dart';
import 'package:mirror_logic/presentation/screens/main_menu/main_menu_screen.dart';
import 'package:mirror_logic/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mirror_logic/presentation/screens/settings/settings_screen.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_gameplay_hud.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

import '../support/memory_box.dart';

void _noop() {}

/// The range the design is expected to survive: a small old phone through a
/// large modern one. A `RenderFlex` overflow at any of these fails the test,
/// because the framework reports it as an exception during paint.
const _sizes = <String, Size>{
  'small 320x568': Size(320, 568),
  'compact 360x640': Size(360, 640),
  'design 390x844': Size(390, 844),
  'large 430x932': Size(430, 932),
};

void main() {
  final saves = SaveRepository(LocalStorageService(MemoryBox()));
  final levels = LevelRepository();

  setUpAll(() {
    // Without this, every text style tries to fetch a font over the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: saves),
          RepositoryProvider.value(value: levels),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ProgressBloc(saveRepository: saves)),
            BlocProvider(
              create: (_) =>
                  EconomyBloc(economyRepository: EconomyRepository(saves)),
            ),
            BlocProvider(create: (_) => SettingsCubit(saveRepository: saves)),
            BlocProvider(
              create: (_) => ThemeCubit(
                saveRepository: saves,
                economyRepository: EconomyRepository(saves),
              ),
            ),
            BlocProvider(
              create: (_) => RewardedCoinsCubit(
                economyRepository: EconomyRepository(saves),
              ),
            ),
          ],
          child: MaterialApp(theme: AppTheme.dark, home: screen),
        ),
      ),
    );
    // Entrance animations are staggered up to a second; settle the ones that
    // finish and leave the looping ones alone.
    await tester.pump(const Duration(seconds: 2));
  }

  const completeArgs = LevelCompleteArgs(
    levelId: 'ch1_001',
    chapterId: 'ch1',
    levelIndex: 1,
    stars: 3,
    moves: 12,
    timeSeconds: 95,
    coinsEarned: 40,
    nextLevelId: 'ch1_002',
  );

  // SplashScreen is left out on purpose: it boots by parsing the whole level
  // catalog, which takes minutes under the test VM, and its layout is a plain
  // column of spacers. The two select screens are in, but only their loading
  // state renders within the pump window, for the same reason.
  final screens = <String, Widget>{
    'onboarding': const OnboardingScreen(),
    'chapter select': const ChapterSelectScreen(),
    'level select': const LevelSelectScreen(chapterId: 'ch1'),
    'main menu': const MainMenuScreen(),
    'level complete': const LevelCompleteScreen(args: completeArgs),
    'settings': const SettingsScreen(),
    'about': const AboutScreen(),
  };

  for (final entry in screens.entries) {
    group(entry.key, () {
      for (final size in _sizes.entries) {
        testWidgets('lays out on a ${size.key} screen', (tester) async {
          await pumpAt(tester, size.value, entry.value);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  group('level complete', () {
    testWidgets('renders with no stars and no next level', (tester) async {
      await pumpAt(
        tester,
        const Size(320, 568),
        const LevelCompleteScreen(
          args: LevelCompleteArgs(
            levelId: 'ch1_999',
            chapterId: 'ch1',
            levelIndex: 999,
            stars: 0,
            moves: 0,
            timeSeconds: 0,
            coinsEarned: 0,
          ),
        ),
      );
      expect(find.text('CLEARED'), findsOneWidget);
      expect(find.text('Next Level'), findsNothing);
    });
  });

  group('gameplay hud', () {
    // The bar is a bare row over the board rather than a panel, so it is the
    // first thing to overflow if a control grows.
    for (final size in _sizes.entries) {
      testWidgets('lays out on a ${size.key} screen', (tester) async {
        await pumpAt(
          tester,
          size.value,
          const MedievalWoodBackground(
            child: SafeArea(
              child: MedievalGameplayHud(
                levelIndex: 1000,
                stars: 3,
                coins: 99999,
                onPause: _noop,
                onAddCoins: _noop,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('1000'), findsOneWidget);
      });
    }

    testWidgets('carries the pause, level and coins on one line', (
      tester,
    ) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        const MedievalWoodBackground(
          child: SafeArea(
            child: MedievalGameplayHud(
              levelIndex: 4,
              stars: 0,
              coins: 10,
              onPause: _noop,
              onAddCoins: _noop,
            ),
          ),
        ),
      );

      double centreY(Finder f) => tester.getCenter(f).dy;
      final pause = centreY(find.byIcon(Icons.pause_rounded));
      expect(centreY(find.text('4')), closeTo(pause, 6));
      expect(centreY(find.text('10')), closeTo(pause, 6));

      // The hint moved down to the board, and it is never free.
      expect(find.byIcon(Icons.lightbulb), findsNothing);
      expect(find.text('FREE'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('a toggle flips and is written back', (tester) async {
      await pumpAt(tester, const Size(390, 844), const SettingsScreen());

      final cubit = tester
          .element(find.byType(SettingsScreen))
          .read<SettingsCubit>();
      final before = cubit.state.assistMode;

      await tester.tap(find.text('Assist Mode'));
      await tester.pump();

      expect(cubit.state.assistMode, !before);
    });
  });
}
