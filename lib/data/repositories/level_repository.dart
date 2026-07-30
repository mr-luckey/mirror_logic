import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class LevelRepository {
  final Map<String, LevelModel> _cache = {};
  Map<String, List<String>>? _chapterIds;
  bool _loaded = false;

  Future<void> preloadCatalog() async {
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/levels/levels.json');
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final levels =
        (root['levels'] as List<dynamic>).cast<Map<String, dynamic>>();

    _chapterIds = {};
    for (final levelJson in levels) {
      final model = LevelModel.fromJson(levelJson);
      _cache[model.levelId] = model;
      _chapterIds!
          .putIfAbsent(model.chapterId, () => [])
          .add(model.levelId);
    }

    for (final entry in _chapterIds!.entries) {
      entry.value.sort(
        (a, b) =>
            _cache[a]!.levelIndex.compareTo(_cache[b]!.levelIndex),
      );
    }
    _loaded = true;
  }

  Future<List<String>> levelIdsForChapter(String chapterId) async {
    await _ensureLoaded();
    return List<String>.from(_chapterIds![chapterId] ?? []);
  }

  Future<int> chapterLevelCount(String chapterId) async {
    return (await levelIdsForChapter(chapterId)).length;
  }

  Future<LevelModel> loadLevel(String levelId) async {
    await _ensureLoaded();
    final model = _cache[levelId];
    if (model == null) {
      throw StateError('Level not found: $levelId');
    }
    return model;
  }

  Future<String?> nextLevelId(String currentId) async {
    final chapterId = currentId.split('_').first;
    final ids = await levelIdsForChapter(chapterId);
    final idx = ids.indexOf(currentId);
    if (idx < 0) return null;
    if (idx + 1 < ids.length) return ids[idx + 1];
    if (chapterId == GameConstants.chapter1Id) {
      final ch2 = await levelIdsForChapter(GameConstants.chapter2Id);
      return ch2.isEmpty ? null : ch2.first;
    }
    return null;
  }

  Future<List<ChapterInfo>> chapters() async {
    final ch1Count = await chapterLevelCount(GameConstants.chapter1Id);
    final ch2Count = await chapterLevelCount(GameConstants.chapter2Id);
    final list = <ChapterInfo>[
      ChapterInfo(
        id: GameConstants.chapter1Id,
        title: 'Training Lab',
        subtitle: 'Stone Castle puzzles',
        levelCount: ch1Count,
        maxStars: ch1Count * 3,
      ),
    ];
    if (ch2Count > 0) {
      list.add(
        ChapterInfo(
          id: GameConstants.chapter2Id,
          title: 'Modern House',
          subtitle: 'Multi-bounce mastery',
          levelCount: ch2Count,
          maxStars: ch2Count * 3,
        ),
      );
    }
    return list;
  }
}

class ChapterInfo {
  const ChapterInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.levelCount,
    required this.maxStars,
  });

  final String id;
  final String title;
  final String subtitle;
  final int levelCount;
  final int maxStars;
}
