import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';

/// A brief message on a bronze plaque.
///
/// `ScaffoldMessenger` cannot be used here: no screen in the game builds a
/// `Scaffold`, so `showSnackBar` asserts. This rides the root overlay instead.
abstract final class MedievalToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    final entry = OverlayEntry(
      builder: (overlayContext) => _Toast(
        message: message,
        icon: icon,
        bottomInset: MediaQuery.viewPaddingOf(overlayContext).bottom,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.bottomInset,
  });

  final String message;
  final IconData icon;
  final double bottomInset;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);

    return Positioned(
      left: Responsive.pageGutter(context),
      right: Responsive.pageGutter(context),
      bottom: widget.bottomInset + 28,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _in,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(curve),
            child: Center(
              child: MedievalPanel(
                radius: 10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 17,
                      color: MedievalColors.textGold,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: MedievalTextStyles.cinzel(
                          size: Responsive.sp(context, 12.5),
                          color: MedievalColors.textCream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
