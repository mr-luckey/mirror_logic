import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

sealed class ProgressEvent extends Equatable {
  const ProgressEvent();
  @override
  List<Object?> get props => [];
}

class ProgressStarted extends ProgressEvent {
  const ProgressStarted();
}

class ProgressOnboardingCompleted extends ProgressEvent {
  const ProgressOnboardingCompleted();
}

class ProgressLevelCompleted extends ProgressEvent {
  const ProgressLevelCompleted({
    required this.levelId,
    required this.stars,
    required this.timeSeconds,
    required this.coinsEarned,
    this.nextLevelId,
  });

  final String levelId;
  final int stars;
  final double timeSeconds;
  final int coinsEarned;
  final String? nextLevelId;

  @override
  List<Object?> get props =>
      [levelId, stars, timeSeconds, coinsEarned, nextLevelId];
}

class ProgressRefresh extends ProgressEvent {
  const ProgressRefresh();
}

class ProgressState extends Equatable {
  const ProgressState({
    required this.save,
    this.loading = false,
  });

  final PlayerSave save;
  final bool loading;

  ProgressState copyWith({PlayerSave? save, bool? loading}) {
    return ProgressState(
      save: save ?? this.save,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [save, loading];
}

class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  ProgressBloc({required SaveRepository saveRepository})
      : _saveRepository = saveRepository,
        super(ProgressState(save: saveRepository.loadSave(), loading: true)) {
    on<ProgressStarted>(_onStarted);
    on<ProgressOnboardingCompleted>(_onOnboarding);
    on<ProgressLevelCompleted>(_onLevelCompleted);
    on<ProgressRefresh>(_onRefresh);
  }

  final SaveRepository _saveRepository;

  Future<void> _onStarted(
    ProgressStarted event,
    Emitter<ProgressState> emit,
  ) async {
    emit(state.copyWith(save: _saveRepository.loadSave(), loading: false));
  }

  Future<void> _onOnboarding(
    ProgressOnboardingCompleted event,
    Emitter<ProgressState> emit,
  ) async {
    final next = state.save.copyWith(onboardingComplete: true);
    await _saveRepository.persistSave(next);
    emit(state.copyWith(save: next));
  }

  Future<void> _onLevelCompleted(
    ProgressLevelCompleted event,
    Emitter<ProgressState> emit,
  ) async {
    // Read through to storage: EconomyRepository writes the same record, so the
    // in-memory copy can be stale after a hint purchase.
    final save = _saveRepository.loadSave();
    final existing = save.levelProgress[event.levelId];
    // Replaying a cleared level shouldn't pay out again.
    final alreadyCleared = existing?.completed ?? false;
    final bestStars =
        existing == null ? event.stars : (event.stars > existing.stars ? event.stars : existing.stars);
    final bestTime = existing?.bestTimeSeconds == null
        ? event.timeSeconds
        : (event.timeSeconds < existing!.bestTimeSeconds!
            ? event.timeSeconds
            : existing.bestTimeSeconds);

    final progress = Map<String, LevelProgress>.from(save.levelProgress);
    progress[event.levelId] = LevelProgress(
      levelId: event.levelId,
      stars: bestStars,
      bestTimeSeconds: bestTime,
      completed: true,
    );

    // Only the catalog knows what actually comes next; deriving an id from the
    // string used to invent levels like `ch1_1001` that do not exist.
    final unlocked = List<String>.from(save.unlockedLevelIds);
    final nextId = event.nextLevelId;
    if (nextId != null && !unlocked.contains(nextId)) {
      unlocked.add(nextId);
    }

    final next = save.copyWith(
      levelProgress: progress,
      unlockedLevelIds: unlocked,
      lastPlayedLevelId: event.levelId,
      coins: alreadyCleared ? save.coins : save.coins + event.coinsEarned,
    );
    await _saveRepository.persistSave(next);
    emit(state.copyWith(save: next));
  }

  Future<void> _onRefresh(
    ProgressRefresh event,
    Emitter<ProgressState> emit,
  ) async {
    emit(state.copyWith(save: _saveRepository.loadSave()));
  }
}
