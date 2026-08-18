import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin Dart client for the native Meta Audience Network integration.
///
/// Full-screen ads (interstitial / rewarded) go through a [MethodChannel].
/// Banners are rendered as Android PlatformViews (`meta_banner_ad`).
class MetaAdsBridge {
  MetaAdsBridge._();

  static const _channel = MethodChannel('meta_ads');
  static bool _initialized = false;

  /// Initialise the native Meta SDK. Idempotent.
  static Future<bool> initialize({bool testMode = false}) async {
    if (_initialized) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('initialize', {
        'testMode': testMode,
      });
      _initialized = ok == true;
      return _initialized;
    } catch (e) {
      debugPrint('MetaAdsBridge.initialize failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------------

  /// Asks native to load an interstitial for [placementId].
  /// Returns `true` when a cached ad is already available.
  static Future<bool> loadInterstitial(String placementId) async {
    try {
      final result = await _channel.invokeMethod<bool>('loadInterstitial', {
        'placementId': placementId,
      });
      return result == true;
    } catch (e) {
      debugPrint('MetaAdsBridge.loadInterstitial failed: $e');
      return false;
    }
  }

  /// Returns whether a loaded interstitial is ready to show.
  static Future<bool> isInterstitialReady() async {
    try {
      return await _channel.invokeMethod<bool>('isInterstitialReady') == true;
    } catch (_) {
      return false;
    }
  }

  /// Shows the cached interstitial and waits for dismissal.
  ///
  /// Returns `{shown: bool, dismissed: bool}`.
  static Future<Map<String, dynamic>> showInterstitial() async {
    try {
      final raw = await _channel.invokeMethod<Map>('showInterstitial');
      return Map<String, dynamic>.from(raw ?? {'shown': false, 'dismissed': true});
    } catch (e) {
      debugPrint('MetaAdsBridge.showInterstitial failed: $e');
      return {'shown': false, 'dismissed': true};
    }
  }

  static Future<void> disposeInterstitial() async {
    try {
      await _channel.invokeMethod<void>('disposeInterstitial');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Rewarded
  // ---------------------------------------------------------------------------

  /// Asks native to load a rewarded ad for [placementId].
  static Future<bool> loadRewarded(String placementId) async {
    try {
      final result = await _channel.invokeMethod<bool>('loadRewarded', {
        'placementId': placementId,
      });
      return result == true;
    } catch (e) {
      debugPrint('MetaAdsBridge.loadRewarded failed: $e');
      return false;
    }
  }

  static Future<bool> isRewardedReady() async {
    try {
      return await _channel.invokeMethod<bool>('isRewardedReady') == true;
    } catch (_) {
      return false;
    }
  }

  /// Shows the cached rewarded ad and waits for close.
  ///
  /// Returns `{shown: bool, earned: bool, dismissed: bool}`.
  static Future<Map<String, dynamic>> showRewarded() async {
    try {
      final raw = await _channel.invokeMethod<Map>('showRewarded');
      return Map<String, dynamic>.from(
        raw ?? {'shown': false, 'earned': false, 'dismissed': true},
      );
    } catch (e) {
      debugPrint('MetaAdsBridge.showRewarded failed: $e');
      return {'shown': false, 'earned': false, 'dismissed': true};
    }
  }

  static Future<void> disposeRewarded() async {
    try {
      await _channel.invokeMethod<void>('disposeRewarded');
    } catch (_) {}
  }
}
