import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mirror_logic/app/app.dart';
import 'package:mirror_logic/core/di/injection.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';

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
    audioService.init().then((_) => audioService.applySettings(settingsCubit.state)),
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SaveRepository>.value(value: saveRepository),
        RepositoryProvider<EconomyRepository>.value(value: economyRepository),
        RepositoryProvider<LevelRepository>.value(value: levelRepository),
        RepositoryProvider<AudioService>.value(value: audioService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => settingsCubit),
          BlocProvider(
            create: (_) => ProgressBloc(saveRepository: saveRepository)
              ..add(const ProgressStarted()),
          ),
          BlocProvider(
            create: (_) => EconomyBloc(economyRepository: economyRepository)
              ..add(const EconomyStarted()),
          ),
        ],
        child: const MirrorLogicApp(),
      ),
    ),
  );
}
