import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/rewarded_coins_cubit.dart';

import '../support/fake_ads_service.dart';
import '../support/memory_box.dart';

void main() {
  late SaveRepository saves;
  late EconomyRepository economy;

  setUp(() {
    saves = SaveRepository(LocalStorageService(MemoryBox()));
    economy = EconomyRepository(saves);
  });

  RewardedCoinsCubit buildCubit({AdsService? ads}) {
    return RewardedCoinsCubit(
      economyRepository: economy,
      adsService: ads,
    );
  }

  test('bootstrap loads persisted quota and coins', () async {
    final windowStart = DateTime.now().subtract(const Duration(hours: 2));
    await saves.persistSave(
      PlayerSave(
        coins: 33,
        rewardedAdsWatched: 4,
        rewardedAdsWindowStartMs: windowStart.millisecondsSinceEpoch,
      ),
    );

    final cubit = buildCubit();
    await cubit.refresh();

    expect(cubit.state.coins, 33);
    expect(cubit.state.adsWatched, 4);
    expect(cubit.state.quotaLabel, '4/${GameConstants.maxRewardedAdsPerWindow}');
    expect(cubit.state.canWatchAd, isTrue);

    await cubit.close();
  });

  test('watchAdForCoins grants coins when the ad is earned', () async {
    final ads = FakeAdsService(outcome: RewardedAdOutcome.earned);
    final cubit = buildCubit(ads: ads);
    await cubit.refresh();

    await cubit.watchAdForCoins();

    expect(cubit.state.lastFeedback, RewardedCoinsFeedback.earned);
    expect(cubit.state.coins, GameConstants.coinsPerRewardedAd);
    expect(cubit.state.adsWatched, 1);
    expect(saves.loadSave().coins, GameConstants.coinsPerRewardedAd);

    await cubit.close();
  });

  test('watchAdForCoins reports skipped ads without granting coins', () async {
    final ads = FakeAdsService(outcome: RewardedAdOutcome.skipped);
    final cubit = buildCubit(ads: ads);
    await cubit.refresh();

    await cubit.watchAdForCoins();

    expect(cubit.state.lastFeedback, RewardedCoinsFeedback.skipped);
    expect(cubit.state.coins, 0);
    expect(cubit.state.adsWatched, 0);

    await cubit.close();
  });

  test('watchAdForCoins ignores duplicate taps while in progress', () async {
    final ads = FakeAdsService(
      outcome: RewardedAdOutcome.earned,
      showDelay: const Duration(milliseconds: 40),
    );
    final cubit = buildCubit(ads: ads);
    await cubit.refresh();

    final first = cubit.watchAdForCoins();
    expect(cubit.state.adInProgress, isTrue);
    await cubit.watchAdForCoins();
    await first;

    expect(cubit.state.adsWatched, 1);
    expect(cubit.state.coins, GameConstants.coinsPerRewardedAd);

    await cubit.close();
  });

  test('watchAdForCoins blocks when quota is exhausted', () async {
    final windowStart = DateTime.now().subtract(const Duration(hours: 1));
    await saves.persistSave(
      PlayerSave(
        rewardedAdsWatched: GameConstants.maxRewardedAdsPerWindow,
        rewardedAdsWindowStartMs: windowStart.millisecondsSinceEpoch,
      ),
    );
    final ads = FakeAdsService(outcome: RewardedAdOutcome.earned);
    final cubit = buildCubit(ads: ads);
    await cubit.refresh();

    await cubit.watchAdForCoins();

    expect(cubit.state.adsWatched, GameConstants.maxRewardedAdsPerWindow);
    expect(cubit.state.coins, 0);
    expect(cubit.state.canWatchAd, isFalse);

    await cubit.close();
  });
}
