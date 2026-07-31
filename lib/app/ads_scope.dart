import 'package:flutter/material.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

/// Publishes the ad stack to the widget tree.
///
/// Lookup is deliberately nullable, matching `AudioScope`: a screen pumped in a
/// widget test has no AdMob under it, and every ad in the game is optional, so
/// "no service" and "no fill" collapse into the same quiet branch.
class AdsScope extends StatelessWidget {
  const AdsScope({super.key, required this.ads, required this.child});

  final AdsService ads;
  final Widget child;

  static AdsService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AdsProvider>()?.ads;

  @override
  Widget build(BuildContext context) => _AdsProvider(ads: ads, child: child);
}

class _AdsProvider extends InheritedWidget {
  const _AdsProvider({required this.ads, required super.child});

  final AdsService ads;

  @override
  bool updateShouldNotify(_AdsProvider oldWidget) => ads != oldWidget.ads;
}

extension AdsContext on BuildContext {
  /// The app-wide ad service, or null outside [AdsScope].
  AdsService? get ads => AdsScope.maybeOf(this);
}
