import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';

/// Every one-shot the game can play.
///
/// Each entry maps to `assets/audio/sfx/<file>.ogg`.
enum Sfx {
  /// Finger lands on a mirror.
  mirrorGrab('mirror_grab', HapticStrength.selection, minGapMs: 60),

  /// Mirror rotates past a notch.
  mirrorDetent('mirror_detent', HapticStrength.selection, minGapMs: 45),

  /// Beam locks onto a mirror or crystal centre.
  mirrorLock('mirror_lock', HapticStrength.medium, minGapMs: 140),

  /// Beam glances off a mirror face.
  beamHit('beam_hit', HapticStrength.none, minGapMs: 70),

  /// A target crystal takes the beam.
  crystalLit('crystal_lit', HapticStrength.light, minGapMs: 120),

  /// Beam reaches a crystal without meeting the objective.
  reject('reject', HapticStrength.heavy, minGapMs: 260),

  /// Level cleared.
  win('win', HapticStrength.heavy),

  /// One star landing on the results plaque.
  star('star', HapticStrength.light, minGapMs: 0),

  /// Coin reward.
  coin('coin', HapticStrength.light),

  /// Any button press.
  tap('tap', HapticStrength.selection, minGapMs: 40),

  /// Leaving a screen.
  back('back', HapticStrength.selection, minGapMs: 40),

  /// A chapter or level opening up.
  unlock('unlock', HapticStrength.medium),

  /// Hint appearing on the board.
  hint('hint', HapticStrength.light),

  /// Undo.
  undo('undo', HapticStrength.selection);

  const Sfx(this.file, this.haptic, {this.minGapMs = 0});

  final String file;
  final HapticStrength haptic;

  /// Shortest spacing between two plays of this cue. Rotation fires detents
  /// far faster than a speaker or a vibration motor can articulate them.
  final int minGapMs;

  String get asset => 'audio/sfx/$file.ogg';
}

enum HapticStrength { none, selection, light, medium, heavy }

enum MusicTrack {
  menu('audio/music/menu.ogg'),
  gameplay('audio/music/gameplay.ogg');

  const MusicTrack(this.asset);

  final String asset;
}

/// Plays the game's music and sound effects.
///
/// Sound effects share a small pool of players so overlapping cues (a detent
/// while a crystal is still ringing) do not cut each other off, and so the
/// game never allocates a player mid-gesture.
class AudioService {
  AudioService({int poolSize = 6}) : _poolSize = poolSize;

  static const double _duckedMusicScale = 0.55;

  final int _poolSize;
  final List<AudioPlayer> _pool = [];
  final Map<Sfx, DateTime> _lastPlayed = {};
  AudioPlayer? _music;

  int _next = 0;
  bool _ready = false;
  bool _muted = false;
  bool _ducked = false;
  MusicTrack? _track;
  AppSettings _settings = const AppSettings();

  bool get isReady => _ready;
  MusicTrack? get currentTrack => _track;

  @visibleForTesting
  double get musicGain => _musicGain;

  double get _musicGain => _muted
      ? 0.0
      : _settings.musicVolume * (_ducked ? _duckedMusicScale : 1.0);

  Future<void> init() async {
    if (_ready) return;
    try {
      // USAGE_GAME / MEDIA so Android screen recorders can capture playback.
      // respectSilence used to force USAGE_NOTIFICATION_RINGTONE, which the
      // AudioPlaybackCapture API deliberately excludes — recorders heard silence.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            // Mix under whatever the player already has going.
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );

      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer(playerId: 'sfx_$i')
          ..setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(player);
      }

      _music = AudioPlayer(playerId: 'music')..setReleaseMode(ReleaseMode.loop);
      _ready = true;
    } catch (error, stack) {
      // A device with no working audio route must not take the game down.
      _ready = false;
      debugPrint('AudioService disabled: $error\n$stack');
    }
  }

  void applySettings(AppSettings settings) {
    _settings = settings;
    unawaited(_music?.setVolume(_musicGain));
  }

  /// Drops the music under a pause sheet or a results screen.
  void duckMusic(bool ducked) {
    if (_ducked == ducked) return;
    _ducked = ducked;
    unawaited(_music?.setVolume(_musicGain));
  }

  Future<void> playMusic(MusicTrack track) async {
    if (!_ready || _music == null) return;
    if (_track == track && _music!.state == PlayerState.playing) {
      await _music!.setVolume(_musicGain);
      return;
    }
    _track = track;
    try {
      await _music!.stop();
      await _music!.setVolume(_musicGain);
      await _music!.play(AssetSource(track.asset), volume: _musicGain);
    } catch (error) {
      debugPrint('music failed: $error');
    }
  }

  Future<void> stopMusic() async {
    _track = null;
    await _music?.stop();
  }

  /// Fires the cue's sound and its matching haptic together.
  void play(Sfx sfx, {double volumeScale = 1.0, bool haptic = true}) {
    if (throttled(sfx)) return;
    if (haptic) _vibrate(sfx.haptic);
    unawaited(_playSound(sfx, volumeScale));
  }

  /// Haptic only, for continuous gestures where a sound would chatter.
  void vibrate(HapticStrength strength) => _vibrate(strength);

  /// Whether this cue fired too recently to fire again. Consuming: calling it
  /// is what starts the next gap.
  @visibleForTesting
  bool throttled(Sfx sfx) {
    if (sfx.minGapMs <= 0) return false;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last).inMilliseconds < sfx.minGapMs) {
      return true;
    }
    _lastPlayed[sfx] = now;
    return false;
  }

  Future<void> _playSound(Sfx sfx, double volumeScale) async {
    if (!_ready || _muted) return;
    final volume = (_settings.sfxVolume * volumeScale).clamp(0.0, 1.0);
    if (volume <= 0.001) return;

    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.stop();
      await player.play(AssetSource(sfx.asset), volume: volume);
    } catch (error) {
      debugPrint('sfx ${sfx.file} failed: $error');
    }
  }

  void _vibrate(HapticStrength strength) {
    if (!_settings.haptics || strength == HapticStrength.none) return;
    switch (strength) {
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
      case HapticStrength.none:
        break;
    }
  }

  /// Silences everything while the app is in the background.
  Future<void> setMuted(bool muted) async {
    if (_muted == muted) return;
    _muted = muted;
    if (!_ready) return;
    if (muted) {
      await _music?.pause();
    } else {
      await _music?.setVolume(_musicGain);
      if (_track != null) await _music?.resume();
    }
  }

  Future<void> dispose() async {
    for (final player in _pool) {
      await player.dispose();
    }
    _pool.clear();
    await _music?.dispose();
    _music = null;
    _ready = false;
  }
}
