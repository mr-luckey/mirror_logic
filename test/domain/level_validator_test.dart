import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/domain/level/level_model.dart';
import 'package:mirror_logic/domain/level/win_condition_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level pack solvability', () {
    Future<List<String>> loadManifest(String chapter) async {
      final raw =
          await rootBundle.loadString('assets/levels/$chapter/manifest.json');
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    }

    Future<LevelModel> loadLevel(String chapter, String id) async {
      final raw =
          await rootBundle.loadString('assets/levels/$chapter/$id.json');
      return LevelModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    test('all chapter 1 intended solutions are solvable', () async {
      final validator = LevelValidator();
      final ids = await loadManifest('ch1');
      expect(ids.length, 20);
      final failures = <String>[];
      for (final id in ids) {
        final level = await loadLevel('ch1', id);
        if (!validator.isSolvable(level)) failures.add(id);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });

    test('all chapter 2 intended solutions are solvable', () async {
      final validator = LevelValidator();
      final ids = await loadManifest('ch2');
      expect(ids.length, 30);
      final failures = <String>[];
      for (final id in ids) {
        final level = await loadLevel('ch2', id);
        if (!validator.isSolvable(level)) failures.add(id);
      }
      expect(failures, isEmpty, reason: 'Unsolvable: $failures');
    });
  });
}
