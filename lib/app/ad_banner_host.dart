import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';
import 'package:mirror_logic/infrastructure/ads/ad_placement_load_state.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/presentation/widgets/ads/ad_banner_slot.dart';

/// Lays the bottom banner under whichever screen is on top.
///
/// One strip for the whole app rather than one per screen: the banner then
/// outlives every navigation, so walking from the menu into a chapter and back
/// costs a single ad request instead of one per screen the player passes
/// through. It also means one owner for the question of whether the strip is
/// there at all, which the screens above have to agree with — they give up their
/// bottom inset to it, and only while it is actually serving.
class AdBannerHost extends StatefulWidget {
  const AdBannerHost({super.key, required this.child});

  final Widget child;

  /// Whether the route at [location] carries a banner.
  ///
  /// Splash is on screen for a second and a half, and onboarding is the first
  /// thing a new player ever sees — neither is worth the impression. Everywhere
  /// else earns.
  static bool showsBannerAt(String location) =>
      !location.startsWith('/splash') && !location.startsWith('/onboarding');

  @override
  State<AdBannerHost> createState() => _AdBannerHostState();
}

class _AdBannerHostState extends State<AdBannerHost>
    with WidgetsBindingObserver {
  /// Fixed 320x50 rather than an adaptive size, which returns anything from 50
  /// to 90 points tall depending on the device. The strip is a constant height,
  /// and a constant slot can only honestly hold a constant ad.
  static const AdSize _size = AdSize.banner;

  /// How long a filled banner stays up before it is replaced.
  ///
  /// Client-driven refresh; keep AdMob console auto-refresh **off**. The floor
  /// is 30 seconds — shorter intervals are invalid traffic.
  static const Duration _refreshInterval = Duration(seconds: 45);

  late bool _show = AdBannerHost.showsBannerAt(_location);
  BannerAd? _ad;
  bool _requested = false;
  bool _foreground = true;
  int _wake = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The service comes from the scope, so the request cannot go in initState.
    final ads = context.ads;
    if (_requested || ads == null) return;
    _requested = true;
    _load(ads);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRouter.router.routerDelegate.removeListener(_sync);
    _ad?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ads = context.ads;
    final foreground = state == AppLifecycleState.resumed;
    _foreground = foreground;
    ads?.setAppForeground(foreground);
    _wake++;
    if (foreground) unawaited(_refreshRemoteConfig());
  }

  Future<void> _refreshRemoteConfig() async {
    final ads = context.ads;
    if (ads == null) return;
    await ads.refreshRemoteConfig();
    if (mounted && !ads.bannerAdsEnabled) _clearBanner();
  }

  static String get _location =>
      AppRouter.router.routerDelegate.currentConfiguration.uri.path;

  void _sync() {
    final show = AdBannerHost.showsBannerAt(_location);
    if (!mounted || show == _show) return;
    // This host sits above the router, and the delegate can notify while the
    // router below it is building. Marking an ancestor dirty mid-build throws,
    // so the strip changes on the frame after the route does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _show == show) return;
      setState(() => _show = show);
      _wake++;
    });
  }

  /// Loads a banner only while it can actually be shown.
  ///
  /// One unit per attempt (rotation + backoff live in [AdsService]). Never
  /// request on splash/onboarding, in the background, or while ads are off.
  Future<void> _load(AdsService ads) async {
    while (mounted) {
      await _waitUntilVisible(ads);
      if (!mounted) return;
      final ad = await ads.loadBanner(_size);
      if (!mounted) {
        await ad?.dispose();
        return;
      }
      if (!_canShow(ads)) {
        await ad?.dispose();
        _clearBanner();
        continue;
      }
      if (ad == null) {
        var delay = ads.retryDelayFor(AdPlacement.banner);
        if (delay < AdPlacementLoadState.nextUnitGap) {
          delay = AdPlacementLoadState.nextUnitGap;
        }
        await _sleep(delay);
        continue;
      }
      _swapIn(ad);
      await _sleep(_refreshInterval);
    }
  }

  bool _canShow(AdsService ads) =>
      ads.bannerAdsEnabled && _show && _foreground;

  Future<void> _waitUntilVisible(AdsService ads) async {
    while (mounted && !_canShow(ads)) {
      _clearBanner();
      await _sleep(const Duration(seconds: 1));
    }
  }

  Future<void> _sleep(Duration duration) async {
    final token = _wake;
    final until = DateTime.now().add(duration);
    while (mounted && DateTime.now().isBefore(until)) {
      if (_wake != token) return;
      final left = until.difference(DateTime.now());
      final slice = left > const Duration(milliseconds: 400)
          ? const Duration(milliseconds: 400)
          : left;
      if (slice <= Duration.zero) return;
      await Future<void>.delayed(slice);
    }
  }

  /// Puts [ad] in the strip and retires the one it replaces.
  ///
  /// The outgoing ad is disposed a frame late, on purpose: its `AdWidget` is
  /// still mounted until the build this setState schedules, and tearing the
  /// native ad out from under a live platform view leaves an empty hole in the
  /// strip. Swapping this way — new ad in first, old one released after — also
  /// means the strip never collapses between two banners.
  void _swapIn(BannerAd ad) {
    final outgoing = _ad;
    setState(() => _ad = ad);
    if (outgoing == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => outgoing.dispose());
  }

  void _clearBanner() {
    final outgoing = _ad;
    if (outgoing == null || !mounted) return;
    setState(() => _ad = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => outgoing.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // An empty strip is 56 points of wood taken off the puzzle for nothing, so
    // until an ad is actually in hand the screens get the whole window.
    if (!_show || ad == null) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The strip has taken over the bottom inset, so the screens above must
        // not reserve room for it a second time in their own SafeArea.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: widget.child,
          ),
        ),
        AdBannerSlot(ad: ad),
      ],
    );
  }
}
