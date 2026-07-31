import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/presentation/screens/chapter_select/chapter_select_screen.dart';
import 'package:mirror_logic/presentation/screens/gameplay/gameplay_screen.dart';
import 'package:mirror_logic/presentation/screens/level_complete/level_complete_screen.dart';
import 'package:mirror_logic/presentation/screens/level_select/level_select_screen.dart';
import 'package:mirror_logic/presentation/screens/main_menu/main_menu_screen.dart';
import 'package:mirror_logic/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:mirror_logic/presentation/screens/settings/settings_screen.dart';
import 'package:mirror_logic/presentation/screens/splash/splash_screen.dart';

abstract final class AppRouter {
  static final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/menu',
        builder: (_, _) => const MainMenuScreen(),
      ),
      GoRoute(
        path: '/chapters',
        builder: (_, _) => const ChapterSelectScreen(),
      ),
      // go_router keys pages by route *pattern*, so without an explicit key
      // Flutter reuses the same element when only the parameter changes and
      // the screen keeps serving the previous chapter/level.
      GoRoute(
        path: '/levels/:chapterId',
        builder: (_, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return LevelSelectScreen(
            key: ValueKey('levels_$chapterId'),
            chapterId: chapterId,
          );
        },
      ),
      GoRoute(
        path: '/play/:levelId',
        builder: (_, state) {
          final levelId = state.pathParameters['levelId']!;
          return GameplayScreen(
            key: ValueKey('play_$levelId'),
            levelId: levelId,
          );
        },
      ),
      GoRoute(
        path: '/complete',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is! LevelCompleteArgs) return const MainMenuScreen();
          return LevelCompleteScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
}
