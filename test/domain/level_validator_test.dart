import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level pack solvability', () {
    late List<LevelModel> ch1Levels;
    late List<LevelModel> ch2Levels;
    final validator = LevelValidator();

    setUpAll(() {
      final raw = File('assets/levels/levels.json').readAsStringSync();
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final all = (root['levels'] as List)
          .map((e) => LevelModel.fromJson(e as Map<String, dynamic>))
          .toList();
      ch1Levels =
          all.where((l) => l.chapterId == 'ch1').toList()
            ..sort((a, b) => a.levelIndex.compareTo(b.levelIndex));
      ch2Levels =
          all.where((l) => l.chapterId == 'ch2').toList()
            ..sort((a, b) => a.levelIndex.compareTo(b.levelIndex));
    });

    test('all chapter 1 intended solutions are solvable', () {
      expect(ch1Levels.length, 20);
      final failures = <String>[];
      for (final level in ch1Levels) {
        if (!validator.isSolvable(level)) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });

    test('all chapter 2 intended solutions are solvable', () {
      expect(ch2Levels.length, 30);
      final failures = <String>[];
      for (final level in ch2Levels) {
        if (!validator.isSolvable(level)) failures.add(level.levelId);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });
  });
}
