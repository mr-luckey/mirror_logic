import 'package:equatable/equatable.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';

class LevelProgress extends Equatable {
  const LevelProgress({
    required this.levelId,
    this.stars = 0,
    this.bestTimeSeconds,
    this.completed = false,
  });

  final String levelId;
  final int stars;
  final double? bestTimeSeconds;
  final bool completed;

  LevelProgress copyWith({
    int? stars,
    double? bestTimeSeconds,
    bool? completed,
  }) {
    return LevelProgress(
      levelId: levelId,
      stars: stars ?? this.stars,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'stars': stars,
        'bestTimeSeconds': bestTimeSeconds,
        'completed': completed,
      };

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      levelId: json['levelId'] as String,
      stars: json['stars'] as int? ?? 0,
      bestTimeSeconds: (json['bestTimeSeconds'] as num?)?.toDouble(),
      completed: json['completed'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [levelId, stars, bestTimeSeconds, completed];
}

class PlayerSave extends Equatable {
  const PlayerSave({
    this.saveSchemaVersion = 1,
    this.onboardingComplete = false,
    this.coins = 50,
    this.unlockedLevelIds = const ['ch1_001'],
    this.levelProgress = const {},
    this.lastPlayedLevelId,
    this.hintsUsedTotal = 0,
  });

  final int saveSchemaVersion;
  final bool onboardingComplete;
  final int coins;
  final List<String> unlockedLevelIds;
  final Map<String, LevelProgress> levelProgress;
  final String? lastPlayedLevelId;
  final int hintsUsedTotal;

  PlayerSave copyWith({
    bool? onboardingComplete,
    int? coins,
    List<String>? unlockedLevelIds,
    Map<String, LevelProgress>? levelProgress,
    String? lastPlayedLevelId,
    int? hintsUsedTotal,
  }) {
    return PlayerSave(
      saveSchemaVersion: saveSchemaVersion,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      coins: coins ?? this.coins,
      unlockedLevelIds: unlockedLevelIds ?? this.unlockedLevelIds,
      levelProgress: levelProgress ?? this.levelProgress,
      lastPlayedLevelId: lastPlayedLevelId ?? this.lastPlayedLevelId,
      hintsUsedTotal: hintsUsedTotal ?? this.hintsUsedTotal,
    );
  }

  int starsForChapter(String chapterId) {
    return levelProgress.values
        .where((p) => p.levelId.startsWith(chapterId))
        .fold<int>(0, (sum, p) => sum + p.stars);
  }

  int completedCountForChapter(String chapterId) {
    return levelProgress.values
        .where((p) => p.levelId.startsWith(chapterId) && p.completed)
        .length;
  }

  bool isChapterUnlocked(String chapterId, int chapterLevelCount) {
    if (GameConstants.unlockAllLevelsForTesting) return true;
    if (chapterId == GameConstants.chapter1Id) return true;
    // Later chapters unlock after 80% of the previous chapter is complete.
    final n = int.tryParse(chapterId.replaceFirst('ch', '')) ?? 0;
    if (n <= 1) return true;
    final prevId = 'ch${n - 1}';
    final completed = completedCountForChapter(prevId);
    final need = (chapterLevelCount * GameConstants.chapterUnlockRatio).ceil();
    return completed >= need;
  }

  Map<String, dynamic> toJson() => {
        'saveSchemaVersion': saveSchemaVersion,
        'onboardingComplete': onboardingComplete,
        'coins': coins,
        'unlockedLevelIds': unlockedLevelIds,
        'levelProgress': levelProgress.map((k, v) => MapEntry(k, v.toJson())),
        'lastPlayedLevelId': lastPlayedLevelId,
        'hintsUsedTotal': hintsUsedTotal,
      };

  factory PlayerSave.fromJson(Map<String, dynamic> json) {
    final progressRaw =
        json['levelProgress'] as Map<String, dynamic>? ?? {};
    return PlayerSave(
      saveSchemaVersion: json['saveSchemaVersion'] as int? ?? 1,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      coins: json['coins'] as int? ?? 50,
      unlockedLevelIds: (json['unlockedLevelIds'] as List<dynamic>? ??
              ['ch1_001'])
          .cast<String>(),
      levelProgress: progressRaw.map(
        (k, v) => MapEntry(k, LevelProgress.fromJson(v as Map<String, dynamic>)),
      ),
      lastPlayedLevelId: json['lastPlayedLevelId'] as String?,
      hintsUsedTotal: json['hintsUsedTotal'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        saveSchemaVersion,
        onboardingComplete,
        coins,
        unlockedLevelIds,
        levelProgress,
        lastPlayedLevelId,
        hintsUsedTotal,
      ];
}

class AppSettings extends Equatable {
  const AppSettings({
    this.musicVolume = 0.7,
    this.sfxVolume = 1.0,
    this.haptics = true,
    this.assistMode = false,
    this.angleReadout = false,
  });

  final double musicVolume;
  final double sfxVolume;
  final bool haptics;
  final bool assistMode;
  final bool angleReadout;

  AppSettings copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? haptics,
    bool? assistMode,
    bool? angleReadout,
  }) {
    return AppSettings(
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      haptics: haptics ?? this.haptics,
      assistMode: assistMode ?? this.assistMode,
      angleReadout: angleReadout ?? this.angleReadout,
    );
  }

  Map<String, dynamic> toJson() => {
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'haptics': haptics,
        'assistMode': assistMode,
        'angleReadout': angleReadout,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.7,
      sfxVolume: (json['sfxVolume'] as num?)?.toDouble() ?? 1.0,
      haptics: json['haptics'] as bool? ?? true,
      assistMode: json['assistMode'] as bool? ?? false,
      angleReadout: json['angleReadout'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [musicVolume, sfxVolume, haptics, assistMode, angleReadout];
}
