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

  /// How long a filled banner stays up before it is replaced.
  ///
  /// The refresh is driven from here rather than by AdMob, so server-side
  /// auto-refresh must stay **off** for the banner units — the two together
  /// would refresh the same strip twice over. Note that AdMob's own floor for a
  /// refresh interval is 30 seconds; anything shorter is out of policy and can
  /// have the units limited for invalid traffic.
  static const Duration _refreshInterval = Duration(seconds: 40);

  /// How long to wait before asking again after a round of requests came back
  /// empty. Unlike the refresh, this never gives up: a launch that landed with
  /// the radio still waking up, or in a tunnel, should still get its banner
  /// whenever the network comes back rather than staying blank for the session.
  static const Duration _retryDelay = Duration(seconds: 15);

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

  /// Keeps a live banner in the strip for as long as this host is mounted.
  ///
  /// One loop covers both jobs, because they are the same job: ask for a banner,
  /// put up whatever comes back, wait, ask again. A round that fills waits out
  /// [_refreshInterval]; a round that comes back empty waits [_retryDelay] and
  /// tries again, without limit.
  Future<void> _load(AdsService ads) async {
    while (mounted) {
      final ad = await ads.loadBanner(_size);
      if (!mounted) {
        await ad?.dispose();
        return;
      }
      if (ad == null) {
        await Future<void>.delayed(_retryDelay);
        continue;
      }
      _swapIn(ad);
      await Future<void>.delayed(_refreshInterval);
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
