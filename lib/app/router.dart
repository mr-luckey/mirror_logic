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
      GoRoute(
        path: '/levels/:chapterId',
        builder: (_, state) {
          final chapterId = state.pathParameters['chapterId']!;
          return LevelSelectScreen(chapterId: chapterId);
        },
      ),
      GoRoute(
        path: '/play/:levelId',
        builder: (_, state) {
          final levelId = state.pathParameters['levelId']!;
          return GameplayScreen(levelId: levelId);
        },
      ),
      GoRoute(
        path: '/complete',
        builder: (_, state) {
          final extra = state.extra! as LevelCompleteArgs;
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
