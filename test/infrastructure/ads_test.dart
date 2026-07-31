import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mirror_logic/app/ad_banner_host.dart';
import 'package:mirror_logic/core/constants/ad_unit_ids.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

const MethodChannel _adChannel = MethodChannel(
  'plugins.flutter.io/google_mobile_ads',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No AdMob plugin is registered under a unit test, and the SDK fires one
    // channel call from a getter without awaiting it — so leaving the channel
    // unimplemented throws where nothing can catch it. Answering everything
    // with null instead gives the service exactly the shape of failure a device
    // with no ads behind it produces, which is the case worth pinning down: the
    // game has to stay playable through it.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _adChannel,
      (call) async => null,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_adChannel, null);
  });

  group('ad unit waterfall', () {
    test('every placement carries a full set of slots', () {
      for (final placement in AdPlacement.values) {
        expect(
          AdUnitIds.forPlacement(placement).length,
          greaterThanOrEqualTo(AdUnitIds.minUnitsPerPlacement),
          reason: 'AdPlacement.${placement.name} lost a slot',
        );
      }
    });

    test('no slot is left blank', () {
      for (final placement in AdPlacement.values) {
        for (final unitId in AdUnitIds.forPlacement(placement)) {
          expect(unitId.trim(), isNotEmpty);
          expect(unitId, startsWith('ca-app-pub-'));
        }
      }
    });

    test('the three placements do not share a unit', () {
      final banner = AdUnitIds.forPlacement(AdPlacement.banner).first;
      final interstitial = AdUnitIds.forPlacement(
        AdPlacement.interstitial,
      ).first;
      final rewarded = AdUnitIds.forPlacement(AdPlacement.rewarded).first;
      expect({banner, interstitial, rewarded}, hasLength(3));
    });
  });

  group('one full-screen ad at a time', () {
    test('a second claim is refused while the first still holds', () {
      final ads = AdsService();

      expect(ads.claimFullScreenSlot(), isTrue);
      expect(ads.isFullScreenAdShowing, isTrue);
      // The rewarded hint asking while the level-end interstitial is up.
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

      // The player watched a video for a hint on the way to this clear.
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
