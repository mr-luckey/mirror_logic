import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';

/// What the app should do about the update Play is offering.
enum AppUpdateKind {
  /// Nothing to install, or nothing that can be installed right now.
  none,

  /// Download in the background and let the player keep playing.
  flexible,

  /// Hand the screen to Play and block until it is done.
  immediate,
}

/// The outcome of one check: what to do, and which build it applies to.
///
/// The version code rides along because postponing is keyed on it, and asking
/// Play a second time to find it out would double a call that talks to the
/// network.
@immutable
class AppUpdateCheck {
  const AppUpdateCheck(this.kind, {this.versionCode});

  static const none = AppUpdateCheck(AppUpdateKind.none);

  final AppUpdateKind kind;
  final int? versionCode;
}

/// Wraps Play's in-app update flow.
///
/// Best-effort throughout, for the same reasons as [AdsService]: this is a
/// single-player puzzle game that works fine on an old build, and it ships to
/// devices with no Play Store at all — sideloads, and every emulator the game
/// is developed on. A failed check must never be visible to the player, so no
/// method here throws and all of them are no-ops off Android.
class AppUpdateService {
  AppUpdateService({
    required LocalStorageService storage,
    this.postponeFor = const Duration(days: 1),
    this.immediatePriority = 4,
    this.immediateStalenessDays = 21,
  }) : _storage = storage;

  final LocalStorageService _storage;

  /// How long "Later" buys before the flexible prompt may return. An update the
  /// player has declined once is not worth a dialog on every cold start.
  final Duration postponeFor;

  /// The Play Developer API priority at and above which the update stops being
  /// optional. Priority is set per-release in the Play Console, so a routine
  /// release ships at 0 and only a build worth interrupting for is raised.
  final int immediatePriority;

  /// Fallback for a release that was never given a priority: an update the
  /// device has known about for this many days is stale enough to force.
  final int immediateStalenessDays;

  static const _postponedUntilKey = 'update_postponed_until_ms';
  static const _postponedCodeKey = 'update_postponed_version_code';

  /// Play's install progress, for showing a downloading state. Empty off
  /// Android so callers can listen unconditionally.
  Stream<InstallStatus> get installStatus {
    if (!_supported) return const Stream<InstallStatus>.empty();
    return InAppUpdate.installUpdateListener;
  }

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Asks Play what is available and decides what to do about it.
  ///
  /// Returns [AppUpdateKind.none] on any failure, which covers the common case
  /// of a build that Play has never heard of — a debug or sideloaded APK makes
  /// the native call throw rather than answer.
  Future<AppUpdateCheck> check() async {
    if (!_supported) return AppUpdateCheck.none;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final kind = classify(
        available:
            info.updateAvailability == UpdateAvailability.updateAvailable,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
        priority: info.updatePriority,
        stalenessDays: info.clientVersionStalenessDays,
        immediatePriority: immediatePriority,
        immediateStalenessDays: immediateStalenessDays,
      );
      // A postponement only ever silences the optional prompt. An update that
      // has since been raised to forced is not something "Later" can defer.
      if (kind == AppUpdateKind.flexible &&
          isPostponed(info.availableVersionCode)) {
        return AppUpdateCheck.none;
      }
      return AppUpdateCheck(kind, versionCode: info.availableVersionCode);
    } catch (error, stack) {
      debugPrint('update check failed: $error\n$stack');
      return AppUpdateCheck.none;
    }
  }

  /// The update rules, separated from the plugin so they can be tested.
  ///
  /// `allowed` is Play's own verdict on whether a flow can run at all — it says
  /// no for a device on a metered connection or with too little free space — so
  /// an urgent update falls back to flexible rather than to nothing.
  @visibleForTesting
  static AppUpdateKind classify({
    required bool available,
    required bool immediateAllowed,
    required bool flexibleAllowed,
    required int priority,
    required int? stalenessDays,
    required int immediatePriority,
    required int immediateStalenessDays,
  }) {
    if (!available) return AppUpdateKind.none;

    final urgent =
        priority >= immediatePriority ||
        (stalenessDays ?? 0) >= immediateStalenessDays;
    if (urgent && immediateAllowed) return AppUpdateKind.immediate;
    if (flexibleAllowed) return AppUpdateKind.flexible;
    // Some devices offer only the blocking flow. Better that than never
    // updating, but it stays behind the same prompt the player can decline.
    if (immediateAllowed) return AppUpdateKind.immediate;
    return AppUpdateKind.none;
  }

  /// Whether the player has already declined this particular version.
  ///
  /// Keyed on the version code so that shipping a new build clears the snooze:
  /// declining 1.0.1 says nothing about 1.0.2.
  bool isPostponed(int? versionCode, {DateTime? now}) {
    final until = _storage.readInt(_postponedUntilKey);
    if (until == 0) return false;
    if (_storage.readInt(_postponedCodeKey) != (versionCode ?? 0)) return false;
    final at = now ?? DateTime.now();
    return at.millisecondsSinceEpoch < until;
  }

  Future<void> postpone(int? versionCode) async {
    await _storage.writeInt(
      _postponedUntilKey,
      DateTime.now().add(postponeFor).millisecondsSinceEpoch,
    );
    await _storage.writeInt(_postponedCodeKey, versionCode ?? 0);
  }

  /// Starts the background download. Completes when the download does.
  Future<AppUpdateResult> startFlexibleUpdate() =>
      _guard(InAppUpdate.startFlexibleUpdate);

  /// Restarts into the downloaded update. Only valid once the download landed.
  Future<AppUpdateResult> completeFlexibleUpdate() => _guard(() async {
    await InAppUpdate.completeFlexibleUpdate();
    return AppUpdateResult.success;
  });

  /// Hands the screen to Play until the update is installed.
  Future<AppUpdateResult> performImmediateUpdate() =>
      _guard(InAppUpdate.performImmediateUpdate);

  Future<AppUpdateResult> _guard(Future<AppUpdateResult> Function() run) async {
    if (!_supported) return AppUpdateResult.inAppUpdateFailed;
    try {
      return await run();
    } catch (error, stack) {
      debugPrint('update flow failed: $error\n$stack');
      return AppUpdateResult.inAppUpdateFailed;
    }
  }
}
