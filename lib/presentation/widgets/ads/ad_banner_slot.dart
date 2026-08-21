import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';
import 'package:mirror_logic/infrastructure/ads/ad_network.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// The wooden strip along the bottom of the app carrying a loaded banner.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({
    super.key,
    required this.selection,
    required this.onLoaded,
    required this.onFailed,
  });

  final BannerAdSelection selection;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MedievalColors.woodDeep,
        border: Border(
          top: BorderSide(
            color: MedievalColors.bronzeDark.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: GameConstants.adBannerHeight,
          child: Center(
            child: _BannerBody(
              selection: selection,
              onLoaded: onLoaded,
              onFailed: onFailed,
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({
    required this.selection,
    required this.onLoaded,
    required this.onFailed,
  });

  final BannerAdSelection selection;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    switch (selection.network) {
      case AdNetwork.unity:
        return SizedBox(
          width: 320,
          height: 50,
          child: UnityBannerAd(
            placementId: selection.placementId,
            size: BannerSize.standard,
            onLoad: (_) => onLoaded(),
            onFailed: (_, e, m) => onFailed(),
          ),
        );
      case AdNetwork.meta:
        return SizedBox(
          width: 320,
          height: 50,
          child: _MetaBannerPlatformView(
            placementId: selection.placementId,
            onLoaded: onLoaded,
            onFailed: onFailed,
          ),
        );
    }
  }
}

class _MetaBannerPlatformView extends StatefulWidget {
  const _MetaBannerPlatformView({
    required this.placementId,
    required this.onLoaded,
    required this.onFailed,
  });

  final String placementId;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  State<_MetaBannerPlatformView> createState() =>
      _MetaBannerPlatformViewState();
}

class _MetaBannerPlatformViewState extends State<_MetaBannerPlatformView> {
  bool _callbackFired = false;

  void _handlePlatformCall(MethodCall call) {
    if (_callbackFired) return;
    switch (call.method) {
      case 'onLoaded':
        _callbackFired = true;
        widget.onLoaded();
        break;
      case 'onError':
        _callbackFired = true;
        widget.onFailed();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      // iOS not yet implemented; report failure so the waterfall advances.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_callbackFired) {
          _callbackFired = true;
          widget.onFailed();
        }
      });
      return const SizedBox.shrink();
    }
    return AndroidView(
      viewType: 'meta_banner_ad',
      creationParams: {'placementId': widget.placementId, 'height': 50},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        final channel = MethodChannel('meta_banner_ad_$id');
        channel.setMethodCallHandler((call) async {
          _handlePlatformCall(call);
        });
      },
    );
  }
}
