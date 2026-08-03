import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mirror_logic/domain/level/level_model.dart';

class LevelRepository {
  /// Models are built the first time a level is actually opened.
  final Map<String, LevelModel> _cache = {};

  /// Lazy-loaded raw JSON keyed by levelId.
  final Map<String, Map<String, dynamic>> _raw = {};

  /// levelId → asset filename (e.g. ch1_001.json).
  final Map<String, String> _files = {};

  final Map<String, List<String>> _chapterIds = {};
  List<String> _orderedIds = const [];

  /// Memoised so two screens asking at once cannot both parse the catalog.
  Future<void>? _loading;

  Future<void> preloadCatalog() => _ensureLoaded();

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    // One JSON file per level (ch1_001.json …). Catalog lives in manifest.json
    // so startup only parses the index — level bodies load on open.
    final manifestRaw = await rootBundle.loadString(
      'assets/levels/manifest.json',
    );
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final entries = (manifest['levels'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final indexOf = <String, int>{};
    final chapterOf = <String, String>{};
    final ordered = <String>[];

    for (final entry in entries) {
      final id = entry['levelId'] as String;
      final chapterId = entry['chapterId'] as String;
      final file = entry['file'] as String;
      final levelIndex =
          (entry['levelIndex'] as num?)?.toInt() ??
          int.tryParse(id.split('_').last) ??
          1;

      _files[id] = file;
      chapterOf[id] = chapterId;
      _chapterIds.putIfAbsent(chapterId, () => []).add(id);
      indexOf[id] = levelIndex;
      ordered.add(id);
    }

    for (final ids in _chapterIds.values) {
      ids.sort((a, b) => indexOf[a]!.compareTo(indexOf[b]!));
    }
    ordered.sort((a, b) {
      // Compare chapters numerically, otherwise `ch10` would sort before `ch2`
      // and `nextLevelId` would jump the player across chapters.
      final ca = _chapterOrder(
        chapterOf[a]!,
      ).compareTo(_chapterOrder(chapterOf[b]!));
      if (ca != 0) return ca;
      return indexOf[a]!.compareTo(indexOf[b]!);
    });
    _orderedIds = ordered;
  }

  static int _chapterOrder(String chapterId) =>
      int.tryParse(chapterId.replaceFirst('ch', '')) ?? 1 << 30;

  Future<Map<String, dynamic>> _loadRaw(String levelId) async {
    final cached = _raw[levelId];
    if (cached != null) return cached;

    final file = _files[levelId];
    if (file == null) {
      throw StateError('Level not found: $levelId');
    }
    final raw = await rootBundle.loadString('assets/levels/$file');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _raw[levelId] = json;
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
    return List<String>.from(_chapterIds[chapterId] ?? const []);
  }

  Future<int> chapterLevelCount(String chapterId) async {
    return (await levelIdsForChapter(chapterId)).length;
  }

  Future<LevelModel> loadLevel(String levelId) async {
    await _ensureLoaded();
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final json = await _loadRaw(levelId);
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
          subtitle:
              _chapterMeta[id]?.$2 ??
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
