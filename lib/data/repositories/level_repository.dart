import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class LevelRepository {
  final Map<String, LevelModel> _cache = {};
  Map<String, List<String>>? _chapterIds;
  List<String> _orderedIds = const [];
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
    _orderedIds = [];
    for (final levelJson in levels) {
      final model = LevelModel.fromJson(levelJson);
      _cache[model.levelId] = model;
      _chapterIds!
          .putIfAbsent(model.chapterId, () => [])
          .add(model.levelId);
      _orderedIds.add(model.levelId);
    }

    for (final entry in _chapterIds!.entries) {
      entry.value.sort(
        (a, b) =>
            _cache[a]!.levelIndex.compareTo(_cache[b]!.levelIndex),
      );
    }
    _orderedIds.sort((a, b) {
      final ca = _cache[a]!.chapterId.compareTo(_cache[b]!.chapterId);
      if (ca != 0) return ca;
      return _cache[a]!.levelIndex.compareTo(_cache[b]!.levelIndex);
    });
    _loaded = true;
  }

  Future<List<String>> allLevelIds() async {
    await _ensureLoaded();
    return List<String>.from(_orderedIds);
  }

  Future<int> totalLevelCount() async {
    await _ensureLoaded();
    return _orderedIds.length;
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
    await _ensureLoaded();
    final idx = _orderedIds.indexOf(currentId);
    if (idx < 0 || idx + 1 >= _orderedIds.length) return null;
    return _orderedIds[idx + 1];
  }

  static const _chapterMeta = <String, (String, String)>{
    GameConstants.chapter1Id: ('Mirror Hall', 'Optical puzzles'),
    GameConstants.chapter2Id: ('Modern House', 'Multi-bounce mastery'),
  };

  Future<List<ChapterInfo>> chapters() async {
    await _ensureLoaded();
    final ids = _chapterIds!.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a.replaceFirst('ch', '')) ?? 0;
        final nb = int.tryParse(b.replaceFirst('ch', '')) ?? 0;
        return na.compareTo(nb);
      });

    return [
      for (final id in ids)
        ChapterInfo(
          id: id,
          title: _chapterMeta[id]?.$1 ?? 'Chapter ${id.replaceFirst('ch', '')}',
          subtitle: _chapterMeta[id]?.$2 ??
              '${_chapterIds![id]!.length} reflection puzzles',
          levelIds: List<String>.from(_chapterIds![id]!),
          levelCount: _chapterIds![id]!.length,
          maxStars: _chapterIds![id]!.length * 3,
        ),
    ];
  }
}

class ChapterInfo {
  const ChapterInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.levelIds,
    required this.levelCount,
    required this.maxStars,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> levelIds;
  final int levelCount;
  final int maxStars;
}
