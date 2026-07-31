import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level pack solvability', () {
    late List<LevelModel> levels;
    final validator = LevelValidator();

    setUpAll(() {
      final raw = File('assets/levels/levels.json').readAsStringSync();
      final root = jsonDecode(raw) as Map<String, dynamic>;
      levels = (root['levels'] as List)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.levelIndex.compareTo(b.levelIndex));
    });

    test('catalog has 1000 levels in one chapter', () {
      expect(levels.length, 1000);
      expect(levels.every((l) => l.chapterId == 'ch1'), isTrue);
      expect(levels.first.levelId, 'ch1_001');
      expect(levels.last.levelId, 'ch1_1000');
    });

    test('mirror count follows 5-level bands (2,4,6,...)', () {
      expect(levels[0].mirrors.length, 2); // 1-5
      expect(levels[4].mirrors.length, 2);
      expect(levels[5].mirrors.length, 4); // 6-10
      expect(levels[9].mirrors.length, 4);
      expect(levels[10].mirrors.length, 6); // 11-15
      expect(levels[14].mirrors.length, 6);
    });

    test('sampled intended solutions are solvable', () {
      final sample = [
        ...levels.take(20),
        levels[49],
        levels[99],
        levels[499],
        levels[999],
      ];
      final failures = <String>[];
      for (final level in sample) {
        if (!validator.isSolvable(level)) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });
  });
}
