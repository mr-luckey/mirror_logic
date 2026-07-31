import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/ads_scope.dart';
import 'package:mirror_logic/app/router.dart';
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

class _AdBannerHostState extends State<AdBannerHost> {
  /// Fixed 320x50 rather than an adaptive size, which returns anything from 50
  /// to 90 points tall depending on the device. The strip is a constant height,
  /// and a constant slot can only honestly hold a constant ad.
  static const AdSize _size = AdSize.banner;

  /// Backs off and gives up. A first request can miss simply because the radio
  /// is still waking up, which is worth asking again about; a region with no
  /// fill will keep saying no however many times it is asked.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 15),
    Duration(seconds: 45),
  ];

  late bool _show = AdBannerHost.showsBannerAt(_location);
  BannerAd? _ad;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
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
    AppRouter.router.routerDelegate.removeListener(_sync);
    _ad?.dispose();
    super.dispose();
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
    });
  }

  Future<void> _load(AdsService ads) async {
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryDelays[attempt - 1]);
        if (!mounted) return;
      }
      final ad = await ads.loadBanner(_size);
      if (!mounted) {
        await ad?.dispose();
        return;
      }
      if (ad != null) {
        setState(() => _ad = ad);
        return;
      }
    }
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
