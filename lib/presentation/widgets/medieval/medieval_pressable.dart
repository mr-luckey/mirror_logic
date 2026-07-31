import 'package:flutter/material.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/widgets/medieval/press_feedback.dart';

/// Scale-down press feedback for medieval bronze controls.
///
/// Routing every control through here is what makes the whole app click and
/// buzz consistently, rather than each screen remembering to do it.
class MedievalPressable extends StatefulWidget {
  const MedievalPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.enabled = true,
    this.sfx = Sfx.tap,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Cue played on press, or null for controls that make their own noise.
  final Sfx? sfx;

  @override
  State<MedievalPressable> createState() => _MedievalPressableState();
}

class _MedievalPressableState extends State<MedievalPressable> {
  /// A notifier rather than `setState` so a press repaints only the scale
  /// wrapper. Some of these wrap whole cards, and rebuilding one on every
  /// touch is wasted work on a slow phone.
  final _pressed = ValueNotifier(false);

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? (_) => _pressed.value = true : null,
      onTapUp: _active
          ? (_) {
              _pressed.value = false;
              if (widget.sfx != null) PressFeedback.fire(context, widget.sfx!);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => _pressed.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _pressed,
        child: widget.child,
        builder: (context, pressed, child) => AnimatedScale(
          scale: pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }
}
