import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

/// Runs on a background isolate — the catalog is several megabytes and
/// decoding it on the UI thread drops a second of frames on a slow phone.
List<Map<String, dynamic>> _decodeCatalog(String raw) {
  final root = jsonDecode(raw) as Map<String, dynamic>;
  return (root['levels'] as List<dynamic>).cast<Map<String, dynamic>>();
}

class LevelRepository {
  /// Models are built the first time a level is actually opened. Constructing
  /// all thousand up front cost far more than it saved, since a session only
  /// ever touches a handful.
  final Map<String, LevelModel> _cache = {};

  final Map<String, Map<String, dynamic>> _raw = {};
  final Map<String, List<String>> _chapterIds = {};
  List<String> _orderedIds = const [];

  /// Memoised so two screens asking at once cannot both parse the catalog.
  Future<void>? _loading;

  Future<void> preloadCatalog() => _ensureLoaded();

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/levels/levels.json');
    final levels = await compute(_decodeCatalog, raw);

    final indexOf = <String, int>{};
    final ordered = <String>[];

    for (final json in levels) {
      final id = json['levelId'] as String;
      final chapterId = json['chapterId'] as String;
      _raw[id] = json;
      _chapterIds.putIfAbsent(chapterId, () => []).add(id);
      indexOf[id] = _levelIndexOf(json);
      ordered.add(id);
    }

    for (final ids in _chapterIds.values) {
      ids.sort((a, b) => indexOf[a]!.compareTo(indexOf[b]!));
    }
    ordered.sort((a, b) {
      // Compare chapters numerically, otherwise `ch10` would sort before `ch2`
      // and `nextLevelId` would jump the player across chapters.
      final ca = _chapterOrder(_raw[a]!['chapterId'] as String)
          .compareTo(_chapterOrder(_raw[b]!['chapterId'] as String));
      if (ca != 0) return ca;
      return indexOf[a]!.compareTo(indexOf[b]!);
    });
    _orderedIds = ordered;
  }

  static int _levelIndexOf(Map<String, dynamic> json) =>
      (json['levelIndex'] as num?)?.toInt() ??
      int.tryParse((json['levelId'] as String).split('_').last) ??
      1;

  static int _chapterOrder(String chapterId) =>
      int.tryParse(chapterId.replaceFirst('ch', '')) ?? 1 << 30;

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
    return List<String>.from(_chapterIds[chapterId] ?? const []);
  }

  Future<int> chapterLevelCount(String chapterId) async {
    return (await levelIdsForChapter(chapterId)).length;
  }

  Future<LevelModel> loadLevel(String levelId) async {
    await _ensureLoaded();
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final json = _raw[levelId];
    if (json == null) {
      throw StateError('Level not found: $levelId');
    }
    return _cache[levelId] = LevelModel.fromJson(json);
  }

  Future<String?> nextLevelId(String currentId) async {
    await _ensureLoaded();
    final idx = _orderedIds.indexOf(currentId);
    if (idx < 0 || idx + 1 >= _orderedIds.length) return null;
    return _orderedIds[idx + 1];
  }

  static const _chapterMeta = <String, (String, String)>{
    'ch1': ('Mirror Hall', 'First light, first bounce'),
    'ch2': ('Stone Corridors', 'Walls close the easy turns'),
    'ch3': ('The Long Gallery', 'Longer chains, tighter angles'),
    'ch4': ('Vaulted Cellars', 'Cramped rooms, sharp reflections'),
    'ch5': ('Torchlit Keep', 'Every mirror earns its place'),
    'ch6': ('Prism Workshop', 'Split beams and stubborn posts'),
    'ch7': ('The Labyrinth', 'Corridors that fold back on you'),
    'ch8': ('Obsidian Halls', 'Dark stone, unforgiving tilts'),
    'ch9': ('Astral Observatory', 'Precision above all'),
    'ch10': ('The Final Beacon', 'Everything the keep taught you'),
  };

  Future<List<ChapterInfo>> chapters() async {
    await _ensureLoaded();
    final ids = _chapterIds.keys.toList()
      ..sort((a, b) => _chapterOrder(a).compareTo(_chapterOrder(b)));

    return [
      for (final id in ids)
        ChapterInfo(
          id: id,
          title: _chapterMeta[id]?.$1 ?? 'Chapter ${id.replaceFirst('ch', '')}',
          subtitle: _chapterMeta[id]?.$2 ??
              '${_chapterIds[id]!.length} reflection puzzles',
          levelIds: List<String>.from(_chapterIds[id]!),
          levelCount: _chapterIds[id]!.length,
          maxStars: _chapterIds[id]!.length * 3,
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
