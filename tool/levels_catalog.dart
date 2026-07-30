import 'dart:convert';
import 'dart:io';

const levelsCatalogPath = 'assets/levels/levels.json';

/// Read all levels from the single catalog file.
Map<String, dynamic> readLevelsCatalog() {
  final file = File(levelsCatalogPath);
  if (!file.existsSync()) {
    return {
      'schemaVersion': 1,
      'levels': <Map<String, dynamic>>[],
    };
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Replace one chapter's levels in [levels.json] and write the file.
void writeChapterLevels(
  String chapterId,
  List<Map<String, dynamic>> chapterLevels,
) {
  final root = readLevelsCatalog();
  final all = (root['levels'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((l) => l['chapterId'] != chapterId)
      .toList();
  all.addAll(chapterLevels);
  all.sort((a, b) {
    final chapterCmp =
        (a['chapterId'] as String).compareTo(b['chapterId'] as String);
    if (chapterCmp != 0) return chapterCmp;
    return ((a['levelIndex'] as num?) ?? 0)
        .compareTo((b['levelIndex'] as num?) ?? 0);
  });
  root['levels'] = all;
  File(levelsCatalogPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(root),
  );
}

List<Map<String, dynamic>> chapterLevels(String chapterId) {
  final root = readLevelsCatalog();
  return (root['levels'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .where((l) => l['chapterId'] == chapterId)
      .toList();
}
