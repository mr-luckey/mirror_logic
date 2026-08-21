import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/ad_banner_host.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

part 'ad_banner_state.dart';

/// Keeps a banner on screen whenever the route allows it.
///
/// Continuous loop: Meta → Unity → wrap. Once loaded, keep mounted (SDK
/// auto-refresh). Tear down only for full-screen ads, real background, or
/// splash/onboarding.
///
/// IVT-safe: no requests offline/backgrounded; 2s gap between failed attempts;
/// never remount a filled banner on a timer.
class AdBannerCubit extends Cubit<AdBannerState> with WidgetsBindingObserver {
  AdBannerCubit({required AdsService ads})
    : _ads = ads,
      super(AdBannerState(show: _showsBannerAt(_currentLocation))) {
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_onRouteChanged);
    unawaited(_ads.init());
    unawaited(_serveLoop());
  }

  static const Duration _poll = Duration(seconds: 1);
  static const Duration _perCandidateTimeout = Duration(seconds: 10);
  static const Duration _betweenAttempts = Duration(seconds: 2);

  final AdsService _ads;
  bool _appInForeground = true;
  int _candidateIndex = 0;
  int _failToken = 0;

  static bool _showsBannerAt(String location) =>
      AdBannerHost.showsBannerAt(location);

  static String get _currentLocation =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.path;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_appInForeground) {
          _appInForeground = true;
          unawaited(_refreshRemoteConfig());
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_appInForeground) {
          _appInForeground = false;
          _resetBanner();
        }
        break;
    }
  }

  Future<void> _refreshRemoteConfig() async {
    await _ads.refreshRemoteConfig();
    if (!isClosed && !_ads.bannerAdsEnabled) _resetBanner();
  }

  void _onRouteChanged() {
    final show = _showsBannerAt(_currentLocation);
    if (show == state.show) return;
    emit(state.copyWith(show: show));
    if (!show) _resetBanner();
  }

  void onBannerLoaded() {
    if (isClosed || state.bannerLoaded) return;
    debugPrint(
      'Banner loaded: ${state.selection?.network.name} '
      '${state.selection?.placementId}',
    );
    emit(state.copyWith(bannerLoaded: true));
  }

  void onBannerFailed() {
    if (isClosed) return;
    debugPrint(
      'Banner failed: ${state.selection?.network.name} '
      '${state.selection?.placementId}',
    );
    _failToken++;
    if (state.bannerLoaded) {
      emit(state.copyWith(bannerLoaded: false));
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final status = await Connectivity().checkConnectivity();
      return status.any((s) => s != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  bool _mustHide() =>
      !_ads.bannerAdsEnabled ||
      !_appInForeground ||
      !state.show ||
      _ads.isFullScreenAdShowing;

  void _beginCandidate(BannerAdSelection selection) {
    debugPrint(
      'Banner trying: ${selection.network.name} ${selection.placementId}',
    );
    emit(
      state.copyWith(
        selection: selection,
        bannerLoaded: false,
        mountGeneration: state.mountGeneration + 1,
      ),
    );
  }

  void _resetBanner() {
    if (isClosed) return;
    if (state.selection == null && !state.bannerLoaded) return;
    emit(
      state.copyWith(
        clearSelection: true,
        bannerLoaded: false,
        mountGeneration: state.mountGeneration + 1,
      ),
    );
  }

  Future<void> _serveLoop() async {
    while (!isClosed) {
      if (_mustHide()) {
        _resetBanner();
        await Future<void>.delayed(_poll);
        continue;
      }

      if (state.bannerLoaded && state.selection != null) {
        await Future<void>.delayed(_poll);
        continue;
      }

      if (!_ads.isReady) {
        unawaited(_ads.init());
        await Future<void>.delayed(_poll);
        continue;
      }

      if (!await _hasInternet()) {
        await Future<void>.delayed(_poll);
        continue;
      }

      final candidates = _ads.bannerCandidates();
      if (candidates.isEmpty) {
        await Future<void>.delayed(_poll);
        continue;
      }

      if (_candidateIndex >= candidates.length) _candidateIndex = 0;
      final wanted = candidates[_candidateIndex];
      if (state.selection != wanted) {
        _beginCandidate(wanted);
      }

      final failAt = _failToken;
      final gen = state.mountGeneration;
      final loaded = await _waitUntilLoaded(gen, failAt);
      if (isClosed) return;
      if (loaded) continue;
      if (_mustHide()) continue;

      _candidateIndex = (_candidateIndex + 1) % candidates.length;
      await Future<void>.delayed(_betweenAttempts);
    }
  }

  Future<bool> _waitUntilLoaded(int mountGeneration, int failToken) async {
    final deadline = DateTime.now().add(_perCandidateTimeout);
    while (!isClosed && DateTime.now().isBefore(deadline)) {
      if (_mustHide()) return false;
      if (state.bannerLoaded) return true;
      if (state.mountGeneration != mountGeneration) return state.bannerLoaded;
      if (_failToken != failToken) return false;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return state.bannerLoaded;
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    AppRouter.router.routerDelegate.removeListener(_onRouteChanged);
    return super.close();
  }
}
