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
  void warmUp() {}

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    if (showDelay > Duration.zero) {
      await Future<void>.delayed(showDelay);
    }
    return outcome;
  }
}
