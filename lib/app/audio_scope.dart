import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/app/router.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';

/// Keeps the soundtrack in step with the app: the right track for the current
/// route, the volumes the player chose, and silence in the background.
///
/// Also publishes the service to the widget tree. Lookup is deliberately
/// nullable so widget tests and previews can pump a control without standing
/// up the whole audio stack.
class AudioScope extends StatefulWidget {
  const AudioScope({super.key, required this.audio, required this.child});

  final AudioService audio;
  final Widget child;

  static AudioService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AudioProvider>()?.audio;

  /// Which loop belongs to a route, or null to leave the current one playing.
  static MusicTrack? trackForLocation(String location) {
    // Splash stays quiet so the first note lands on the menu.
    if (location.startsWith('/splash')) return null;
    if (location.startsWith('/play')) return MusicTrack.gameplay;
    if (location.startsWith('/complete')) return MusicTrack.gameplay;
    return MusicTrack.menu;
  }

  @override
  State<AudioScope> createState() => _AudioScopeState();
}

class _AudioScopeState extends State<AudioScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppRouter.router.routerDelegate.addListener(_syncTrack);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTrack());
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_syncTrack);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.audio.setMuted(state != AppLifecycleState.resumed);
  }

  void _syncTrack() {
    if (!mounted) return;
    final location =
        AppRouter.router.routerDelegate.currentConfiguration.uri.path;
    // The results screen sits on top of gameplay, so soften rather than swap.
    widget.audio.duckMusic(location.startsWith('/complete'));
    final track = AudioScope.trackForLocation(location);
    if (track == null) return;
    widget.audio.playMusic(track);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, AppSettings>(
      listenWhen: (p, c) =>
          p.musicVolume != c.musicVolume ||
          p.sfxVolume != c.sfxVolume ||
          p.haptics != c.haptics,
      listener: (_, settings) => widget.audio.applySettings(settings),
      child: _AudioProvider(audio: widget.audio, child: widget.child),
    );
  }
}

class _AudioProvider extends InheritedWidget {
  const _AudioProvider({required this.audio, required super.child});

  final AudioService audio;

  @override
  bool updateShouldNotify(_AudioProvider oldWidget) => audio != oldWidget.audio;
}

extension AudioContext on BuildContext {
  /// The app-wide audio service, or null outside [AudioScope].
  AudioService? get audio => AudioScope.maybeOf(this);

  /// Shorthand for the common "play a cue" call.
  void playSfx(Sfx sfx, {double volumeScale = 1.0}) =>
      AudioScope.maybeOf(this)?.play(sfx, volumeScale: volumeScale);
}
