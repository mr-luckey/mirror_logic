import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mirror_logic/app/app_update_scope.dart';
import 'package:mirror_logic/core/constants/app_info.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_exit_scope.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';

/// Checks Play for a new build and runs whichever update flow fits.
///
/// This wraps the main menu rather than the whole app: it is the screen every
/// cold start lands on, it always has a Navigator to hang a dialog from, and it
/// is never the middle of a puzzle. Checking from the splash screen instead
/// would race its animation, and checking above the router would leave the
/// dialog with nowhere to go.
///
/// The check runs once per launch. Nothing here can fail loudly — see
/// [AppUpdateService] — so a device with no Play Store just renders [child].
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  static bool _checkedThisLaunch = false;

  StreamSubscription<InstallStatus>? _install;
  bool _installPromptShown = false;

  @override
  void initState() {
    super.initState();
    // Waits a frame so the menu is painted before anything can cover it, and so
    // the first thing a returning player sees is their game, not a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _install?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    if (_checkedThisLaunch) return;
    final updates = context.updates;
    if (updates == null) return;
    _checkedThisLaunch = true;

    final result = await updates.check();
    if (!mounted) return;

    switch (result.kind) {
      case AppUpdateKind.none:
        return;
      case AppUpdateKind.immediate:
        // Play owns the screen for this one, so there is no dialog of ours to
        // show first — a forced update the player could dismiss is not forced.
        await updates.performImmediateUpdate();
      case AppUpdateKind.flexible:
        await _offerFlexible(result.versionCode);
    }
  }

  Future<void> _offerFlexible(int? versionCode) async {
    final updates = context.updates;
    if (updates == null) return;

    final accept = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => MedievalConfirmDialog(
        icon: Icons.system_update_rounded,
        title: 'Update Available',
        body:
            'A new version of ${AppInfo.name} is ready on Google Play. '
            'It downloads in the background while you play.',
        cancelLabel: 'Later',
        confirmLabel: 'Update',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (!mounted) return;

    if (accept != true) {
      await updates.postpone(versionCode);
      return;
    }

    // Watch the download before starting it: a small update on a fast
    // connection can land before the await below returns.
    _listenForDownload();
    final started = await updates.startFlexibleUpdate();
    if (!mounted) return;
    if (started != AppUpdateResult.success) {
      await _install?.cancel();
      _install = null;
      if (mounted && started == AppUpdateResult.inAppUpdateFailed) {
        MedievalToast.show(context, 'The update could not be started');
      }
      return;
    }
    await _promptInstall();
  }

  void _listenForDownload() {
    _install ??= context.updates?.installStatus.listen((status) {
      if (status == InstallStatus.downloaded) unawaited(_promptInstall());
    });
  }

  /// Offers the restart that finishes a downloaded update.
  ///
  /// Reachable from both the stream and the completed `startFlexibleUpdate`
  /// future, whichever notices first, so it is guarded against asking twice.
  Future<void> _promptInstall() async {
    if (_installPromptShown || !mounted) return;
    _installPromptShown = true;

    final restart = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => MedievalConfirmDialog(
        icon: Icons.download_done_rounded,
        title: 'Update Ready',
        body:
            'The new version is downloaded. '
            '${AppInfo.name} will restart to finish installing.',
        cancelLabel: 'Not Yet',
        confirmLabel: 'Restart',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (restart != true || !mounted) return;
    // Play restarts the app from here, so nothing after this line is expected
    // to run. Progress is already on disk either way.
    await context.updates?.completeFlexibleUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
