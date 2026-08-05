import 'package:equatable/equatable.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';

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
    this.saveSchemaVersion = 2,
    this.onboardingComplete = false,
    this.walkthroughSeen = false,
    this.coins = 0,
    this.unlockedLevelIds = const [GameConstants.firstLevelId],
    this.levelProgress = const {},
    this.lastPlayedLevelId,
    this.hintsUsedTotal = 0,
    this.ownedThemeIds = const [ThemeCatalog.starterId],
    this.selectedThemeId = ThemeCatalog.starterId,
    this.rewardedAdsWatched = 0,
    this.rewardedAdsWindowStartMs = 0,
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

  /// Theme packs the player has purchased (starter is always included).
  final List<String> ownedThemeIds;

  /// Currently equipped visual hall.
  final String selectedThemeId;

  /// Rewarded ads watched in the current rolling 24-hour window.
  final int rewardedAdsWatched;

  /// Epoch ms when the current rewarded-ad window started. Zero means idle.
  final int rewardedAdsWindowStartMs;

  PlayerSave copyWith({
    int? saveSchemaVersion,
    bool? onboardingComplete,
    bool? walkthroughSeen,
    int? coins,
    List<String>? unlockedLevelIds,
    Map<String, LevelProgress>? levelProgress,
    String? lastPlayedLevelId,
    int? hintsUsedTotal,
    List<String>? ownedThemeIds,
    String? selectedThemeId,
    int? rewardedAdsWatched,
    int? rewardedAdsWindowStartMs,
  }) {
    return PlayerSave(
      saveSchemaVersion: saveSchemaVersion ?? this.saveSchemaVersion,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      walkthroughSeen: walkthroughSeen ?? this.walkthroughSeen,
      coins: coins ?? this.coins,
      unlockedLevelIds: unlockedLevelIds ?? this.unlockedLevelIds,
      levelProgress: levelProgress ?? this.levelProgress,
      lastPlayedLevelId: lastPlayedLevelId ?? this.lastPlayedLevelId,
      hintsUsedTotal: hintsUsedTotal ?? this.hintsUsedTotal,
      ownedThemeIds: ownedThemeIds ?? this.ownedThemeIds,
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      rewardedAdsWatched: rewardedAdsWatched ?? this.rewardedAdsWatched,
      rewardedAdsWindowStartMs:
          rewardedAdsWindowStartMs ?? this.rewardedAdsWindowStartMs,
    );
  }

  /// Highest continuous level number the player has opened (ch2_014 → 114).
  int get highestDisplayLevel {
    var best = 1;
    for (final id in unlockedLevelIds) {
      final n = displayLevelForId(id);
      if (n > best) best = n;
    }
    return best;
  }

  /// Where Continue should land: the furthest board the player has opened.
  ///
  /// Not [lastPlayedLevelId] — that is whatever they touched last, so it points
  /// at a cleared board after a win and at an old one after a replay.
  String get continueLevelId {
    var best = GameConstants.firstLevelId;
    var bestNumber = displayLevelForId(best);
    for (final id in unlockedLevelIds) {
      final number = displayLevelForId(id);
      if (number > bestNumber) {
        bestNumber = number;
        best = id;
      }
    }
    return best;
  }

  static int displayLevelForId(String levelId) {
    final match = RegExp(r'^ch(\d+)_(\d+)$').firstMatch(levelId);
    if (match == null) return 1;
    final chapter = int.parse(match.group(1)!);
    final index = int.parse(match.group(2)!);
    return (chapter - 1) * 100 + index;
  }

  bool ownsTheme(String themeId) => ownedThemeIds.contains(themeId);

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
    'ownedThemeIds': ownedThemeIds,
    'selectedThemeId': selectedThemeId,
    'rewardedAdsWatched': rewardedAdsWatched,
    'rewardedAdsWindowStartMs': rewardedAdsWindowStartMs,
  };

  factory PlayerSave.fromJson(Map<String, dynamic> json) {
    final progressRaw = json['levelProgress'] as Map<String, dynamic>? ?? {};
    final ownedRaw =
        (json['ownedThemeIds'] as List<dynamic>? ??
                const [ThemeCatalog.starterId])
            .whereType<String>()
            .where(ThemeCatalog.allIds.contains)
            .toList();
    if (!ownedRaw.contains(ThemeCatalog.starterId)) {
      ownedRaw.insert(0, ThemeCatalog.starterId);
    }

    var schema = json['saveSchemaVersion'] as int? ?? 1;
    var owned = List<String>.from(ownedRaw);
    var selectedRaw =
        json['selectedThemeId'] as String? ?? ThemeCatalog.starterId;

    // v2: stop auto-granting every hall. Testing saves that owned the full
    // catalog are reset to the free starter — paid halls must be bought.
    if (schema < 2) {
      owned = [ThemeCatalog.starterId];
      selectedRaw = ThemeCatalog.starterId;
      schema = 2;
    }

    final selected = owned.contains(selectedRaw)
        ? selectedRaw
        : ThemeCatalog.starterId;

    return PlayerSave(
      saveSchemaVersion: schema,
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
      ownedThemeIds: owned,
      selectedThemeId: selected,
      rewardedAdsWatched: (json['rewardedAdsWatched'] as num?)?.toInt() ?? 0,
      rewardedAdsWindowStartMs:
          (json['rewardedAdsWindowStartMs'] as num?)?.toInt() ?? 0,
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
    ownedThemeIds,
    selectedThemeId,
    rewardedAdsWatched,
    rewardedAdsWindowStartMs,
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
