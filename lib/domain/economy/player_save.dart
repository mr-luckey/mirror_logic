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
    this.walkthroughSeen = false,
    this.coins = 0,
    this.unlockedLevelIds = const [GameConstants.firstLevelId],
    this.levelProgress = const {},
    this.lastPlayedLevelId,
    this.hintsUsedTotal = 0,
  });

  final int saveSchemaVersion;
  final bool onboardingComplete;

  /// Whether the hand has already played the first board for this player.
  final bool walkthroughSeen;

  final int coins;
  final List<String> unlockedLevelIds;
  final Map<String, LevelProgress> levelProgress;
  final String? lastPlayedLevelId;
  final int hintsUsedTotal;

  PlayerSave copyWith({
    bool? onboardingComplete,
    bool? walkthroughSeen,
    int? coins,
    List<String>? unlockedLevelIds,
    Map<String, LevelProgress>? levelProgress,
    String? lastPlayedLevelId,
    int? hintsUsedTotal,
  }) {
    return PlayerSave(
      saveSchemaVersion: saveSchemaVersion,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      walkthroughSeen: walkthroughSeen ?? this.walkthroughSeen,
      coins: coins ?? this.coins,
      unlockedLevelIds: unlockedLevelIds ?? this.unlockedLevelIds,
      levelProgress: levelProgress ?? this.levelProgress,
      lastPlayedLevelId: lastPlayedLevelId ?? this.lastPlayedLevelId,
      hintsUsedTotal: hintsUsedTotal ?? this.hintsUsedTotal,
    );
  }

  /// `startsWith` would make `ch1` swallow every `ch10_*` level, so fall back to
  /// matching the id's chapter segment exactly.
  static bool _belongsTo(String levelId, String chapterId) =>
      levelId.split('_').first == chapterId;

  int starsForChapter(String chapterId, {Iterable<String>? levelIds}) {
    final ids = levelIds?.toSet();
    return levelProgress.values
        .where(
          (p) => ids != null
              ? ids.contains(p.levelId)
              : _belongsTo(p.levelId, chapterId),
        )
        .fold<int>(0, (sum, p) => sum + p.stars);
  }

  int completedCountForChapter(String chapterId, {Iterable<String>? levelIds}) {
    final ids = levelIds?.toSet();
    return levelProgress.values
        .where(
          (p) =>
              (ids != null
                  ? ids.contains(p.levelId)
                  : _belongsTo(p.levelId, chapterId)) &&
              p.completed,
        )
        .length;
  }

  /// Stars still owed on the previous chapter before [chapterId] opens.
  ///
  /// Zero means the chapter is unlocked. The first chapter is never sealed.
  int starsMissingToUnlock(String chapterId) {
    if (GameConstants.unlockAllLevelsForTesting) return 0;
    final n = int.tryParse(chapterId.replaceFirst('ch', '')) ?? 0;
    if (n <= 1) return 0;
    final earned = starsForChapter('ch${n - 1}');
    return (GameConstants.starsToUnlockNextChapter - earned).clamp(
      0,
      GameConstants.starsToUnlockNextChapter,
    );
  }

  bool isChapterUnlocked(String chapterId) =>
      starsMissingToUnlock(chapterId) == 0;

  Map<String, dynamic> toJson() => {
    'saveSchemaVersion': saveSchemaVersion,
    'onboardingComplete': onboardingComplete,
    'walkthroughSeen': walkthroughSeen,
    'coins': coins,
    'unlockedLevelIds': unlockedLevelIds,
    'levelProgress': levelProgress.map((k, v) => MapEntry(k, v.toJson())),
    'lastPlayedLevelId': lastPlayedLevelId,
    'hintsUsedTotal': hintsUsedTotal,
  };

  factory PlayerSave.fromJson(Map<String, dynamic> json) {
    final progressRaw = json['levelProgress'] as Map<String, dynamic>? ?? {};
    return PlayerSave(
      saveSchemaVersion: json['saveSchemaVersion'] as int? ?? 1,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      walkthroughSeen: json['walkthroughSeen'] as bool? ?? false,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      unlockedLevelIds:
          (json['unlockedLevelIds'] as List<dynamic>? ??
                  [GameConstants.firstLevelId])
              .whereType<String>()
              .toList(),
      levelProgress: {
        for (final entry in progressRaw.entries)
          if (entry.value is Map)
            entry.key: LevelProgress.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      },
      lastPlayedLevelId: json['lastPlayedLevelId'] as String?,
      hintsUsedTotal: (json['hintsUsedTotal'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    saveSchemaVersion,
    onboardingComplete,
    walkthroughSeen,
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
  List<Object?> get props => [
    musicVolume,
    sfxVolume,
    haptics,
    assistMode,
    angleReadout,
  ];
}
