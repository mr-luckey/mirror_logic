import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/presentation/widgets/ads/ad_banner_slot.dart';

/// Lays the bottom banner under whichever screen is on top.
///
/// One strip for the whole app. Loads the single `app` placement unit — never
/// a multi-ID waterfall. Collapses when empty. No infinite retry storm.
class AdBannerHost extends StatefulWidget {
  const AdBannerHost({super.key, required this.child});

  final Widget child;

  static bool showsBannerAt(String location) =>
      !location.startsWith('/splash') && !location.startsWith('/onboarding');

  @override
  State<AdBannerHost> createState() => _AdBannerHostState();
}

class _AdBannerHostState extends State<AdBannerHost>
    with WidgetsBindingObserver {
  static const AdSize _size = AdSize.banner;

  /// Client refresh; keep AdMob console auto-refresh off. Floor is 30s.
  static const Duration _refreshInterval = Duration(seconds: 45);
  static const Duration _retryBackoff = Duration(seconds: 30);
  static const int _maxRetries = 2;

  late bool _show = AdBannerHost.showsBannerAt(_location);
  BannerAd? _ad;
  bool _requested = false;
  bool _foreground = true;
  int _wake = 0;
  int _failStreak = 0;

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
    unawaited(_load(ads));
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _show == show) return;
      setState(() => _show = show);
      _wake++;
      if (show) _failStreak = 0;
    });
  }

  Future<void> _load(AdsService ads) async {
    while (mounted) {
      await _waitUntilVisible(ads);
      if (!mounted) return;

      final ad = await ads.loadBanner(_size, placement: 'app');
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
        _failStreak++;
        if (_failStreak > _maxRetries) {
          // Stop hammering. Wait a full refresh window before one more try.
          _failStreak = 0;
          await _sleep(_refreshInterval);
          continue;
        }
        await _sleep(_retryBackoff * _failStreak);
        continue;
      }
      _failStreak = 0;
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
    if (!_show || ad == null) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
