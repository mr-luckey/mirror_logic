import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class LevelRepository {
  final Map<String, LevelModel> _cache = {};
  List<String>? _ch1Ids;
  List<String>? _ch2Ids;

  Future<void> preloadCatalog() async {
    _ch1Ids = await _loadManifest(GameConstants.chapter1Id);
    _ch2Ids = await _loadManifest(GameConstants.chapter2Id);
  }

  Future<List<String>> _loadManifest(String chapterId) async {
    try {
      final raw =
          await rootBundle.loadString('assets/levels/$chapterId/manifest.json');
      final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
      return list;
    } catch (_) {
      // Fallback: generate ids if manifest missing during early bootstrap.
      final count = chapterId == GameConstants.chapter1Id ? 20 : 30;
      return List.generate(
        count,
        (i) => '${chapterId}_${(i + 1).toString().padLeft(3, '0')}',
      );
    }
  }

  Future<List<String>> levelIdsForChapter(String chapterId) async {
    if (chapterId == GameConstants.chapter1Id) {
      _ch1Ids ??= await _loadManifest(chapterId);
      return _ch1Ids!;
    }
    if (chapterId == GameConstants.chapter2Id) {
      _ch2Ids ??= await _loadManifest(chapterId);
      return _ch2Ids!;
    }
    return [];
  }

  Future<int> chapterLevelCount(String chapterId) async {
    return (await levelIdsForChapter(chapterId)).length;
  }

  Future<LevelModel> loadLevel(String levelId) async {
    if (_cache.containsKey(levelId)) return _cache[levelId]!;
    final chapterId = levelId.split('_').first;
    final raw =
        await rootBundle.loadString('assets/levels/$chapterId/$levelId.json');
    final model = LevelModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cache[levelId] = model;
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
    return [
      ChapterInfo(
        id: GameConstants.chapter1Id,
        title: 'Training Lab',
        subtitle: 'Learn the beam',
        levelCount: ch1Count,
        maxStars: ch1Count * 3,
      ),
      ChapterInfo(
        id: GameConstants.chapter2Id,
        title: 'Modern House',
        subtitle: 'Multi-bounce mastery',
        levelCount: ch2Count,
        maxStars: ch2Count * 3,
      ),
    ];
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
