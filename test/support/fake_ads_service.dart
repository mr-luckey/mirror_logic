import 'dart:async';

import 'package:mirror_logic/infrastructure/ads/ads_service.dart';

/// Lightweight ad double for unit tests.
class FakeAdsService extends AdsService {
  FakeAdsService({
    this.outcome = RewardedAdOutcome.earned,
    this.cached = true,
    this.showDelay = Duration.zero,
  });

  RewardedAdOutcome outcome;
  bool cached;
  Duration showDelay;

  @override
  bool get hasRewardedAd => cached;

  @override
  bool hasRewardedFor(String placement) => cached;

  @override
  void warmUp({
    String interstitialPlacement = 'level_break',
    String rewardedPlacement = 'hint',
  }) {}

  @override
  Future<void> preloadRewarded({String placement = 'hint'}) async {}

  @override
  Future<RewardedAdOutcome> showRewarded({String placement = 'hint'}) async {
    if (showDelay > Duration.zero) {
      await Future<void>.delayed(showDelay);
    }
    return outcome;
  }
}
