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
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _active
          ? (_) {
              setState(() => _pressed = false);
              if (widget.sfx != null) PressFeedback.fire(context, widget.sfx!);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
