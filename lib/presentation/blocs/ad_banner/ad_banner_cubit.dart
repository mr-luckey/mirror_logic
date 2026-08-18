import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/app/ad_banner_host.dart';
import 'package:mirror_logic/infrastructure/ads/ad_network.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

part 'ad_banner_state.dart';

class AdBannerCubit extends Cubit<AdBannerState> with WidgetsBindingObserver {
  AdBannerCubit({required AdsService ads})
      : _ads = ads,
        super(AdBannerState(
          show: _showsBannerAt(_currentLocation),
        )) {
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_onRouteChanged);
    unawaited(_serveLoop());
  }

  static const Duration _refreshInterval = Duration(seconds: 60);
  static const Duration _retryDelay = Duration(seconds: 15);
  static const Duration _perCandidateTimeout = Duration(seconds: 8);

  final AdsService _ads;
  bool _appInForeground = true;
  int _candidateIndex = 0;

  static bool _showsBannerAt(String location) =>
      AdBannerHost.showsBannerAt(location);

  static String get _currentLocation =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.path;

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    final foreground = appState == AppLifecycleState.resumed;
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    if (foreground) {
      unawaited(_refreshRemoteConfig());
    } else {
      _resetBanner();
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
    emit(state.copyWith(bannerLoaded: true));
  }

  void onBannerFailed() {
    if (isClosed || state.bannerLoaded) return;
    final candidates = _ads.bannerCandidates();
    if (_candidateIndex + 1 >= candidates.length) return;
    _candidateIndex++;
    _beginCandidate(candidates[_candidateIndex]);
  }

  bool _shouldRequest() =>
      _ads.bannerAdsEnabled &&
      _appInForeground &&
      state.show &&
      !_ads.isFullScreenAdShowing;

  void _beginCandidate(BannerAdSelection selection) {
    if (state.selection == selection && !state.bannerLoaded) return;
    emit(state.copyWith(
      selection: selection,
      bannerLoaded: false,
      mountGeneration: state.mountGeneration + 1,
    ));
  }

  void _resetBanner() {
    if (isClosed) return;
    if (state.selection == null &&
        !state.bannerLoaded &&
        _candidateIndex == 0) {
      return;
    }
    _candidateIndex = 0;
    emit(state.copyWith(
      clearSelection: true,
      bannerLoaded: false,
      mountGeneration: state.mountGeneration + 1,
    ));
  }

  Future<void> _serveLoop() async {
    while (!isClosed) {
      if (!_shouldRequest()) {
        _resetBanner();
        await Future<void>.delayed(_retryDelay);
        continue;
      }

      final candidates = _ads.bannerCandidates();
      if (candidates.isEmpty) {
        _resetBanner();
        await Future<void>.delayed(_retryDelay);
        continue;
      }

      _candidateIndex = 0;
      _beginCandidate(candidates.first);

      final loaded = await _waitForLoadOrExhaust(candidates);
      if (isClosed) return;

      if (loaded) {
        await Future<void>.delayed(_refreshInterval);
        if (isClosed) return;
        _resetBanner();
        continue;
      }

      await Future<void>.delayed(_retryDelay);
    }
  }

  Future<bool> _waitForLoadOrExhaust(
    List<BannerAdSelection> candidates,
  ) async {
    for (var i = _candidateIndex; i < candidates.length; i++) {
      if (isClosed || !_shouldRequest()) return false;
      if (i != _candidateIndex) {
        _candidateIndex = i;
        _beginCandidate(candidates[i]);
      }

      final deadline = DateTime.now().add(_perCandidateTimeout);
      while (!isClosed && DateTime.now().isBefore(deadline)) {
        if (state.bannerLoaded) return true;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
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
