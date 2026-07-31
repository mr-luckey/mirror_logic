import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/app/theme/app_theme.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';

class MirrorLogicApp extends StatelessWidget {
  const MirrorLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The save record is the single source of truth for coins, and ProgressBloc
    // is its only writer on level completion. Mirroring its balance here means
    // the HUD can never read a stale total mid-write.
    return BlocListener<ProgressBloc, ProgressState>(
      listenWhen: (p, c) => p.save.coins != c.save.coins,
      listener: (context, state) => context
          .read<EconomyBloc>()
          .add(EconomyCoinsChanged(state.save.coins)),
      child: AudioScope(
        audio: context.read<AudioService>(),
        child: _Router(),
      ),
    );
  }
}

class _Router extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mirror Logic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Keep typography stable on accessibility extreme scales for puzzle UI.
        final clamped = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.2,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
