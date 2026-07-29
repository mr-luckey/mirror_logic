import 'package:flutter/material.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/app/theme/app_theme.dart';

class MirrorLogicApp extends StatelessWidget {
  const MirrorLogicApp({super.key});

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
