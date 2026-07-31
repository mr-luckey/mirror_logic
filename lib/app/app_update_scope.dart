import 'package:flutter/material.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';

/// Publishes the update service to the widget tree.
///
/// Nullable lookup for the same reason as [ReviewScope]: there is no Play Store
/// behind a widget test, and an absent service means the same thing as a check
/// that found nothing.
class AppUpdateScope extends StatelessWidget {
  const AppUpdateScope({super.key, required this.updates, required this.child});

  final AppUpdateService updates;
  final Widget child;

  static AppUpdateService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppUpdateProvider>()?.updates;

  @override
  Widget build(BuildContext context) =>
      _AppUpdateProvider(updates: updates, child: child);
}

class _AppUpdateProvider extends InheritedWidget {
  const _AppUpdateProvider({required this.updates, required super.child});

  final AppUpdateService updates;

  @override
  bool updateShouldNotify(_AppUpdateProvider oldWidget) =>
      updates != oldWidget.updates;
}

extension AppUpdateContext on BuildContext {
  /// The app-wide update service, or null outside [AppUpdateScope].
  AppUpdateService? get updates => AppUpdateScope.maybeOf(this);
}
