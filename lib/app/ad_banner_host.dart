import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/presentation/widgets/ads/ad_banner_slot.dart';

/// Lays the bottom banner under whichever screen is on top.
///
/// One strip for the whole app rather than one per screen. Banner candidates
/// are tried Unity-first, Meta-second per slot, and the strip hides while a
/// full-screen ad holds the screen so two ads never overlap.
class AdBannerHost extends StatefulWidget {
  const AdBannerHost({super.key, required this.child});

  final Widget child;

  /// Whether the route at [location] carries a banner.
  static bool showsBannerAt(String location) =>
      !location.startsWith('/splash') && !location.startsWith('/onboarding');

  @override
  State<AdBannerHost> createState() => _AdBannerHostState();
}

class _AdBannerHostState extends State<AdBannerHost>
    with WidgetsBindingObserver {
  /// How long a filled banner stays up before it is replaced.
  ///
  /// Unity and Meta both auto-refresh while visible; remounting faster than
  /// 60 seconds risks invalid-traffic flags.
  static const Duration _refreshInterval = Duration(seconds: 60);

  /// How long to wait before asking again after every candidate failed.
  static const Duration _retryDelay = Duration(seconds: 15);

  late bool _show = AdBannerHost.showsBannerAt(_location);
  BannerAdSelection? _selection;
  int _candidateIndex = 0;
  int _mountGeneration = 0;
  bool _bannerLoaded = false;
  bool _requested = false;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.ads;
    if (_requested || ads == null) return;
    _requested = true;
    unawaited(_serveLoop(ads));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRouter.router.routerDelegate.removeListener(_sync);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    if (foreground) {
      unawaited(_refreshRemoteConfig());
    } else {
      _resetBanner();
    }
  }

  Future<void> _refreshRemoteConfig() async {
    final ads = context.ads;
    if (ads == null) return;
    await ads.refreshRemoteConfig();
    if (mounted && !ads.bannerAdsEnabled) _resetBanner();
  }

  static String get _location =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.path;

  void _sync() {
    final show = AdBannerHost.showsBannerAt(_location);
    if (!mounted || show == _show) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _show == show) return;
      setState(() => _show = show);
      if (!show) _resetBanner();
    });
  }

  Future<void> _serveLoop(AdsService ads) async {
    while (mounted) {
      if (!_shouldRequest(ads)) {
        _resetBanner();
        await Future<void>.delayed(_retryDelay);
        continue;
      }

      final candidates = ads.bannerCandidates();
      if (candidates.isEmpty) {
        _resetBanner();
        await Future<void>.delayed(_retryDelay);
        continue;
      }

      _candidateIndex = 0;
      _beginCandidate(candidates.first);

      final loaded = await _waitForLoadOrExhaust(ads, candidates);
      if (!mounted) return;

      if (loaded) {
        await Future<void>.delayed(_refreshInterval);
        if (!mounted) return;
        _resetBanner(keepServing: true);
        continue;
      }

      await Future<void>.delayed(_retryDelay);
    }
  }

  bool _shouldRequest(AdsService ads) =>
      ads.bannerAdsEnabled &&
      _appInForeground &&
      _show &&
      !ads.isFullScreenAdShowing;

  void _beginCandidate(BannerAdSelection selection) {
    setState(() {
      _selection = selection;
      _bannerLoaded = false;
      _mountGeneration++;
    });
  }

  Future<bool> _waitForLoadOrExhaust(
    AdsService ads,
    List<BannerAdSelection> candidates,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (_bannerLoaded) return true;
      if (!_shouldRequest(ads)) return false;

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (_bannerLoaded) return true;

      if (_candidateIndex + 1 >= candidates.length) return false;
      _candidateIndex++;
      _beginCandidate(candidates[_candidateIndex]);
    }
    return _bannerLoaded;
  }

  void _onBannerLoaded() {
    if (!mounted || _bannerLoaded) return;
    setState(() => _bannerLoaded = true);
  }

  void _onBannerFailed() {
    if (!mounted || _bannerLoaded) return;
    final ads = context.ads;
    if (ads == null) return;

    final candidates = ads.bannerCandidates();
    if (_candidateIndex + 1 >= candidates.length) return;

    _candidateIndex++;
    _beginCandidate(candidates[_candidateIndex]);
  }

  void _resetBanner({bool keepServing = false}) {
    if (!mounted) return;
    setState(() {
      _selection = null;
      _bannerLoaded = false;
      _candidateIndex = 0;
      if (!keepServing) _mountGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.ads;
    final selection = _selection;
    final loading =
        _show &&
        selection != null &&
        ads != null &&
        _shouldRequest(ads) &&
        !_bannerLoaded;
    final visible =
        _show &&
        selection != null &&
        _bannerLoaded &&
        ads != null &&
        !ads.isFullScreenAdShowing;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (visible)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: widget.child,
                ),
              ),
              AdBannerSlot(
                key: ValueKey('${selection.mountKey}-$_mountGeneration'),
                selection: selection,
                onLoaded: _onBannerLoaded,
                onFailed: _onBannerFailed,
              ),
            ],
          )
        else
          widget.child,
        if (loading)
          Offstage(
            child: AdBannerSlot(
              key: ValueKey('load-${selection.mountKey}-$_mountGeneration'),
              selection: selection,
              onLoaded: _onBannerLoaded,
              onFailed: _onBannerFailed,
            ),
          ),
      ],
    );
  }
}
