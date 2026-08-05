import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mirror_logic/app/app.dart';
import 'package:mirror_logic/core/di/injection.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/art/game_art.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/economy/rewarded_coins_cubit.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/blocs/theme/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      // Matches the darkest wood in MedievalColors so the system bar reads as
      // part of the frame rather than a strip of someone else's app.
      systemNavigationBarColor: Color(0xFF1A1008),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Firebase is optional at runtime: until its platform files are installed,
  // the ads layer continues with the same in-code defaults.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase unavailable; using local defaults: $error');
  }

  await Hive.initFlutter();
  await configureDependencies();

  final saveRepository = sl<SaveRepository>();
  final economyRepository = sl<EconomyRepository>();
  final levelRepository = sl<LevelRepository>();
  final settingsCubit = SettingsCubit(saveRepository: saveRepository);
  await settingsCubit.load();

  final audioService = sl<AudioService>();
  // Never block first paint on the audio stack; a device with no route just
  // leaves the service disabled.
  unawaited(
    audioService.init().then(
      (_) => audioService.applySettings(settingsCubit.state),
    ),
  );

  // Same deal for ads, and for the same reason: the SDK talks to the network on
  // the way up, and the splash screen is not going to wait for it.
  final adsService = sl<AdsService>();
  unawaited(adsService.init());

  unawaited(
    GameArt.loadForTheme(
      // Prefer the saved hall so first paint matches the equipped theme.
      sl<SaveRepository>().loadSave().selectedThemeId,
    ),
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SaveRepository>.value(value: saveRepository),
        RepositoryProvider<EconomyRepository>.value(value: economyRepository),
        RepositoryProvider<LevelRepository>.value(value: levelRepository),
        RepositoryProvider<AudioService>.value(value: audioService),
        RepositoryProvider<AdsService>.value(value: adsService),
        RepositoryProvider<ReviewService>.value(value: sl<ReviewService>()),
        RepositoryProvider<AppUpdateService>.value(
          value: sl<AppUpdateService>(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => settingsCubit),
          BlocProvider(
            create: (_) =>
                ProgressBloc(saveRepository: saveRepository)
                  ..add(const ProgressStarted()),
          ),
          BlocProvider(
            create: (_) =>
                EconomyBloc(economyRepository: economyRepository)
                  ..add(const EconomyStarted()),
          ),
          BlocProvider(
            create: (_) => ThemeCubit(
              saveRepository: saveRepository,
              economyRepository: economyRepository,
            ),
          ),
          BlocProvider(
            create: (_) => RewardedCoinsCubit(
              economyRepository: economyRepository,
              adsService: adsService,
            ),
          ),
        ],
        child: const MirrorLogicApp(),
      ),
    ),
  );
}
