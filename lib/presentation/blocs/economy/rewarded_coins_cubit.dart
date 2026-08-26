import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/analytics/analytics_service.dart';

enum RewardedCoinsFeedback { earned, skipped, unavailable, quotaReached }

class RewardedCoinsState extends Equatable {
  const RewardedCoinsState({
    required this.adsWatched,
    required this.adsLimit,
    required this.coins,
    required this.canWatchAd,
    this.adInProgress = false,
    this.lastFeedback,
  });

  final int adsWatched;
  final int adsLimit;
  final int coins;
  final bool canWatchAd;
  final bool adInProgress;
  final RewardedCoinsFeedback? lastFeedback;

  String get quotaLabel => '$adsWatched/$adsLimit';

  RewardedCoinsState copyWith({
    int? adsWatched,
    int? adsLimit,
    int? coins,
    bool? canWatchAd,
    bool? adInProgress,
    RewardedCoinsFeedback? lastFeedback,
    bool clearFeedback = false,
  }) {
    return RewardedCoinsState(
      adsWatched: adsWatched ?? this.adsWatched,
      adsLimit: adsLimit ?? this.adsLimit,
      coins: coins ?? this.coins,
      canWatchAd: canWatchAd ?? this.canWatchAd,
      adInProgress: adInProgress ?? this.adInProgress,
      lastFeedback: clearFeedback ? null : (lastFeedback ?? this.lastFeedback),
    );
  }

  @override
  List<Object?> get props => [
    adsWatched,
    adsLimit,
    coins,
    canWatchAd,
    adInProgress,
    lastFeedback,
  ];
}

class RewardedCoinsCubit extends Cubit<RewardedCoinsState> {
  RewardedCoinsCubit({
    required EconomyRepository economyRepository,
    AdsService? adsService,
    AnalyticsService? analytics,
  }) : _economyRepository = economyRepository,
       _adsService = adsService,
       _analytics = analytics,
       super(
         const RewardedCoinsState(
           adsWatched: 0,
           adsLimit: GameConstants.maxRewardedAdsPerWindow,
           coins: 0,
           canWatchAd: true,
         ),
       ) {
    unawaited(_bootstrap());
  }

  final EconomyRepository _economyRepository;
  final AdsService? _adsService;
  final AnalyticsService? _analytics;

  static RewardedCoinsState _fromSave(PlayerSave save) {
    final watched = save.rewardedAdsWatched;
    final limit = GameConstants.maxRewardedAdsPerWindow;
    return RewardedCoinsState(
      adsWatched: watched,
      adsLimit: limit,
      coins: save.coins,
      canWatchAd: watched < limit,
    );
  }

  Future<void> _bootstrap() async {
    final save = await _economyRepository.loadNormalizedSave();
    emit(_fromSave(save));
  }

  Future<void> refresh() async {
    final save = await _economyRepository.loadNormalizedSave();
    emit(_fromSave(save).copyWith(clearFeedback: true));
  }

  void syncCoins(int coins) {
    if (coins == state.coins) return;
    emit(state.copyWith(coins: coins, clearFeedback: true));
  }

  Future<void> watchAdForCoins() async {
    if (state.adInProgress || !state.canWatchAd) return;

    emit(state.copyWith(adInProgress: true, clearFeedback: true));

    final ads = _adsService;
    if (ads == null) {
      emit(
        state.copyWith(
          adInProgress: false,
          lastFeedback: RewardedCoinsFeedback.unavailable,
        ),
      );
      return;
    }

    ads.warmUp(rewardedPlacement: 'coins');
    await ads.preloadRewarded(placement: 'coins');
    if (!ads.hasRewardedFor('coins')) {
      emit(
        state.copyWith(
          adInProgress: false,
          lastFeedback: RewardedCoinsFeedback.unavailable,
        ),
      );
      return;
    }

    final outcome = await ads.showRewarded(placement: 'coins');
    switch (outcome) {
      case RewardedAdOutcome.earned:
        final grant = await _economyRepository.grantRewardedAdCoins();
        if (grant.result == RewardedAdGrantResult.quotaExceeded) {
          emit(
            _fromSave(grant.save).copyWith(
              adInProgress: false,
              lastFeedback: RewardedCoinsFeedback.quotaReached,
            ),
          );
          return;
        }
        unawaited(
          _analytics?.logRewardedAdCompleted(
            placement: 'coins',
            source: 'economy',
          ),
        );
        unawaited(
          _analytics?.logRewardClaimed(
            rewardType: 'coins',
            source: 'rewarded_ad',
          ),
        );
        emit(
          _fromSave(grant.save).copyWith(
            adInProgress: false,
            lastFeedback: RewardedCoinsFeedback.earned,
          ),
        );
      case RewardedAdOutcome.skipped:
        emit(
          state.copyWith(
            adInProgress: false,
            lastFeedback: RewardedCoinsFeedback.skipped,
          ),
        );
      case RewardedAdOutcome.unavailable:
        emit(
          state.copyWith(
            adInProgress: false,
            lastFeedback: RewardedCoinsFeedback.unavailable,
          ),
        );
    }
  }
}
