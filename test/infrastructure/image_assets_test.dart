import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/infrastructure/art/game_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';

void main() {
  // The artwork ships as WebP converted from the PNG masters, and pubspec lists
  // each file rather than the folder so the masters stay out of the APK. Both
  // the board painter and the menu widgets treat a missing image as a soft
  // failure, so nothing but these checks would catch a file left unbundled.
  final assets = [...GameArt.assetPaths, ...MedievalArt.all];

  group('image assets', () {
    test('there is something to check', () {
      // Guards the loops below from passing on an empty list.
      expect(
        assets,
        hasLength(GameArt.assetPaths.length + MedievalArt.all.length),
      );
      expect(assets.length, greaterThan(20));
    });

    test('every referenced image exists', () {
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: 'missing $asset');
      }
    });

    test('every referenced image is declared in the bundle', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in assets) {
        expect(
          pubspec,
          contains(asset),
          reason: 'pubspec.yaml does not bundle $asset',
        );
      }
    });

    test('the uncompressed masters stay out of the bundle', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      // A bare folder entry would sweep the PNG/WAV masters back in, which is
      // what previously cost ~45 MB of download.
      for (final folder in const [
        'assets/images/medieval/',
        'assets/images/ui/',
        'assets/audio/sfx/',
        'assets/audio/music/',
      ]) {
        expect(
          pubspec,
          isNot(contains('- $folder\n')),
          reason: '$folder is globbed; list its shipped files instead',
        );
      }
      expect(pubspec, isNot(contains('.png')));
      expect(pubspec, isNot(contains('.wav')));
    });
  });
}
