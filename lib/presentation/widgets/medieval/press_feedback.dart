import 'package:flutter/widgets.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';

/// Plays a UI cue if the app has an audio service in scope.
///
/// Widget tests and previews pump these controls without the app's providers,
/// so a missing service must be a silent no-op rather than a lookup failure.
abstract final class PressFeedback {
  static void fire(BuildContext context, Sfx sfx) =>
      AudioScope.maybeOf(context)?.play(sfx);
}
