import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/ad_banner_host.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';
import 'package:mirror_logic/infrastructure/ads/ads_remote_config.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

const MethodChannel _adChannel = MethodChannel(
  'plugins.flutter.io/google_mobile_ads',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _adChannel,
      (call) async => null,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_adChannel, null);
  });

  group('ad unit placements', () {
    test('every format carries five named slots', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(AppAdsConfig.bannerAdUnits, hasLength(AppAdsConfig.maxUnitsPerFormat));
      expect(
        AppAdsConfig.interstitialAdUnits,
        hasLength(AppAdsConfig.maxUnitsPerFormat),
      );
      expect(
        AppAdsConfig.rewardedAdUnits,
        hasLength(AppAdsConfig.maxUnitsPerFormat),
      );
    });

    test('named placements resolve without waterfall', () {
      // Debug builds always use Google test IDs (testMode).
      expect(AppAdsConfig.bannerUnitId('app'), isNotNull);
      expect(AppAdsConfig.interstitialUnitId('level_break'), isNotNull);
      expect(AppAdsConfig.rewardedUnitId('hint'), isNotNull);
      expect(AppAdsConfig.bannerUnitId('missing'), isNull);
    });

    test('android production lists use unique units per format', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      // Skip when testMode forces samples — still verify lists themselves.
      expect(AppAdsConfig.bannerAdUnits.toSet().length, 5);
      expect(AppAdsConfig.interstitialAdUnits.toSet().length, 5);
      expect(AppAdsConfig.rewardedAdUnits.toSet().length, 5);
    });
  });

  group('one full-screen ad at a time', () {
    test('a second claim is refused while the first still holds', () {
      final ads = AdsService();

      expect(ads.claimFullScreenSlot(), isTrue);
      expect(ads.isFullScreenAdShowing, isTrue);
      expect(ads.claimFullScreenSlot(), isFalse);

      ads.releaseFullScreenSlot(shown: true);
      expect(ads.isFullScreenAdShowing, isFalse);
      expect(ads.claimFullScreenSlot(), isTrue);
    });

    test('nothing can be shown before the SDK is up', () async {
      final ads = AdsService();
      expect(ads.isReady, isFalse);
      expect(ads.hasRewardedAd, isFalse);
      expect(await ads.showInterstitial(), isFalse);
      expect(await ads.showRewarded(), RewardedAdOutcome.unavailable);
      expect(await ads.loadBanner(AdSize.banner), isNull);
    });
  });

  group('interstitial cadence', () {
    test('the opening levels of a session are quiet', () {
      final ads = AdsService(levelsBetweenInterstitials: 3);

      ads.registerLevelCleared();
      expect(ads.interstitialDue, isFalse);
      ads.registerLevelCleared();
      expect(ads.interstitialDue, isFalse);
      ads.registerLevelCleared();
      expect(ads.interstitialDue, isTrue);
    });

    test('a rewarded video buys quiet from the next interstitial', () {
      final ads = AdsService(
        levelsBetweenInterstitials: 1,
        minGapBetweenFullScreenAds: const Duration(minutes: 1),
      );

      ads.registerLevelCleared();
      expect(ads.interstitialDue, isTrue);

      ads.claimFullScreenSlot();
      ads.releaseFullScreenSlot(shown: true);
      expect(ads.interstitialDue, isFalse);
    });

    test('an ad that failed to show does not start the quiet period', () {
      final ads = AdsService(
        levelsBetweenInterstitials: 1,
        minGapBetweenFullScreenAds: const Duration(minutes: 1),
      );
      ads.registerLevelCleared();

      ads.claimFullScreenSlot();
      ads.releaseFullScreenSlot(shown: false);
      expect(ads.interstitialDue, isTrue);
    });

    test('Remote Config can allow the first clear to show', () {
      final ads = AdsService(
        remoteConfig: _FakeAdsConfig(interstitialSkipFirst: false),
        levelsBetweenInterstitials: 3,
      );

      ads.registerLevelCleared();
      expect(ads.interstitialDue, isTrue);
    });

    test('Remote Config supplies the quiet period', () {
      final ads = AdsService(
        remoteConfig: _FakeAdsConfig(
          interstitialMinInterval: const Duration(minutes: 1),
        ),
        levelsBetweenInterstitials: 1,
      );
      ads.registerLevelCleared();
      expect(ads.interstitialDue, isTrue);

      ads.claimFullScreenSlot();
      ads.releaseFullScreenSlot(shown: true);
      expect(ads.interstitialDue, isFalse);
    });
  });

  group('Remote Config ad gates', () {
    test('banner and interstitial controls can be disabled independently', () {
      final ads = AdsService(
        remoteConfig: _FakeAdsConfig(
          bannerAdsEnabled: false,
          interstitialAdsEnabled: false,
        ),
      );

      expect(ads.bannerAdsEnabled, isFalse);
      expect(ads.interstitialAdsEnabled, isFalse);
      expect(
        ads.interstitialAllowed(policy: InterstitialPolicy.always),
        isFalse,
      );
    });
  });

  group('leaving the board from the pause menu', () {
    test('does not wait for the level cadence', () {
      final ads = AdsService(levelsBetweenInterstitials: 3);

      expect(ads.interstitialDue, isFalse);
      expect(
        ads.interstitialAllowed(policy: InterstitialPolicy.quietPeriod),
        isTrue,
      );
    });

    test('still honours the quiet period', () {
      final ads = AdsService(
        minGapBetweenFullScreenAds: const Duration(minutes: 1),
      );

      ads.claimFullScreenSlot();
      ads.releaseFullScreenSlot(shown: true);
      expect(
        ads.interstitialAllowed(policy: InterstitialPolicy.quietPeriod),
        isFalse,
      );
    });
  });

  group('the exits that always charge', () {
    test('wait for neither the cadence nor the quiet period', () {
      final ads = AdsService(
        levelsBetweenInterstitials: 3,
        minGapBetweenFullScreenAds: const Duration(minutes: 1),
      );

      ads.claimFullScreenSlot();
      ads.releaseFullScreenSlot(shown: true);

      expect(ads.interstitialDue, isFalse);
      expect(
        ads.interstitialAllowed(policy: InterstitialPolicy.quietPeriod),
        isFalse,
      );
      expect(
        ads.interstitialAllowed(policy: InterstitialPolicy.always),
        isTrue,
      );
    });

    test('still show nothing while the SDK is down', () async {
      final ads = AdsService(forcedFillWait: Duration.zero);

      expect(
        await ads.showInterstitial(policy: InterstitialPolicy.always),
        isFalse,
      );
    });
  });

  group('banner routes', () {
    test('the screens the player lives on carry a banner', () {
      for (final location in [
        '/menu',
        '/chapters',
        '/levels/ch2',
        '/play/ch1_004',
        '/complete',
        '/settings',
      ]) {
        expect(AdBannerHost.showsBannerAt(location), isTrue, reason: location);
      }
    });

    test('the launch and first-run screens stay clean', () {
      expect(AdBannerHost.showsBannerAt('/splash'), isFalse);
      expect(AdBannerHost.showsBannerAt('/onboarding'), isFalse);
    });
  });
}

class _FakeAdsConfig implements AdsConfig {
  _FakeAdsConfig({
    this.bannerAdsEnabled = true,
    this.interstitialAdsEnabled = true,
    this.interstitialMinInterval = const Duration(seconds: 45),
    this.interstitialSkipFirst = true,
  });

  @override
  final bool bannerAdsEnabled;

  @override
  final bool interstitialAdsEnabled;

  @override
  final Duration interstitialMinInterval;

  @override
  final bool interstitialSkipFirst;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> refreshIfNeeded() async {}
}
