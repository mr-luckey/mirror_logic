import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';

void main() {
  group('audio assets', () {
    test('every sound effect has a file to play', () {
      for (final sfx in Sfx.values) {
        expect(
          File('assets/${sfx.asset}').existsSync(),
          isTrue,
          reason: 'missing assets/${sfx.asset} for Sfx.${sfx.name}',
        );
      }
    });

    test('every music track has a file to play', () {
      for (final track in MusicTrack.values) {
        expect(
          File('assets/${track.asset}').existsSync(),
          isTrue,
          reason: 'missing assets/${track.asset}',
        );
      }
    });

    test('the assets are declared in the bundle', () {
      // pubspec lists audio file by file rather than by folder, so that the
      // uncompressed WAV masters sitting beside them stay out of the APK. That
      // makes a missing line a silent runtime failure, hence the per-cue check.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in [
        ...Sfx.values.map((sfx) => sfx.asset),
        ...MusicTrack.values.map((track) => track.asset),
      ]) {
        expect(
          pubspec,
          contains('assets/$asset'),
          reason: 'pubspec.yaml does not bundle assets/$asset',
        );
      }
    });
  });

  group('AudioService throttling', () {
    test('a rapid cue is dropped until its gap has passed', () async {
      final audio = AudioService();

      // mirrorDetent fires on every frame of a drag; without a gap it would
      // machine-gun both the speaker and the vibration motor.
      expect(audio.throttled(Sfx.mirrorDetent), isFalse);
      expect(audio.throttled(Sfx.mirrorDetent), isTrue);

      await Future<void>.delayed(
        Duration(milliseconds: Sfx.mirrorDetent.minGapMs + 20),
      );
      expect(audio.throttled(Sfx.mirrorDetent), isFalse);
    });

    test('cues with no gap always fire', () {
      final audio = AudioService();
      expect(Sfx.win.minGapMs, 0);
      expect(audio.throttled(Sfx.win), isFalse);
      expect(audio.throttled(Sfx.win), isFalse);
    });

    test('one cue being throttled does not silence another', () {
      final audio = AudioService();
      audio.throttled(Sfx.mirrorDetent);
      expect(audio.throttled(Sfx.mirrorLock), isFalse);
    });
  });

  group('AudioService volume', () {
    test('follows the music slider', () {
      final audio = AudioService()
        ..applySettings(const AppSettings(musicVolume: 0.4));
      expect(audio.musicGain, closeTo(0.4, 1e-9));
    });

    test('ducking pulls the track down without losing the setting', () {
      final audio = AudioService()
        ..applySettings(const AppSettings(musicVolume: 1))
        ..duckMusic(true);
      expect(audio.musicGain, lessThan(1));
      expect(audio.musicGain, greaterThan(0));

      audio.duckMusic(false);
      expect(audio.musicGain, 1);
    });

    test('a muted service is silent whatever the slider says', () async {
      final audio = AudioService()
        ..applySettings(const AppSettings(musicVolume: 1));
      await audio.setMuted(true);
      expect(audio.musicGain, 0);
    });
  });

  group('music routing', () {
    test('the board and its results screen share one loop', () {
      expect(AudioScope.trackForLocation('/play/ch1_004'), MusicTrack.gameplay);
      expect(AudioScope.trackForLocation('/complete'), MusicTrack.gameplay);
    });

    test('every other screen gets the menu loop', () {
      for (final location in [
        '/menu',
        '/chapters',
        '/levels/ch2',
        '/settings',
      ]) {
        expect(
          AudioScope.trackForLocation(location),
          MusicTrack.menu,
          reason: location,
        );
      }
    });

    test('splash asks for nothing so the first note lands on the menu', () {
      expect(AudioScope.trackForLocation('/splash'), isNull);
    });
  });
}
