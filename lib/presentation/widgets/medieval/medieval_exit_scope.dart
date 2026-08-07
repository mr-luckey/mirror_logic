import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// Guards the hardware back button on a root screen.
///
/// Without this the system pops the last route and drops the player straight
/// out of the game, which is jarring on Android where back is a reflex.
///
/// Uses both [BackButtonListener] (Android/engine back) and [PopScope]
/// (predictive-back / Navigator pop). A re-entry guard stops the confirm
/// dialog from stacking if both fire for one press.
class MedievalExitScope extends StatefulWidget {
  const MedievalExitScope({super.key, required this.child});

  final Widget child;

  @override
  State<MedievalExitScope> createState() => _MedievalExitScopeState();

  static Future<bool> confirmExit(BuildContext context) async {
    final answer = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => MedievalConfirmDialog(
        icon: Icons.logout_rounded,
        title: 'Leave the Keep?',
        body: 'Your progress is already saved.',
        confirmLabel: 'Leave',
        cancelLabel: 'Stay',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    return answer ?? false;
  }
}

class _MedievalExitScopeState extends State<MedievalExitScope> {
  bool _asking = false;

  Future<bool> _handleBack() async {
    if (_asking || !mounted) return true;
    _asking = true;
    try {
      final leave = await MedievalExitScope.confirmExit(context);
      if (leave && mounted) await SystemNavigator.pop();
    } finally {
      _asking = false;
    }
    // Always consume the event so the route is not popped underneath.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return BackButtonListener(
      onBackButtonPressed: _handleBack,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(_handleBack());
        },
        child: widget.child,
      ),
    );
  }
}

/// Two-choice prompt on a bronze-framed panel.
class MedievalConfirmDialog extends StatelessWidget {
  const MedievalConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.pageGutter(context),
          ),
          child: MedievalPanel(
            glow: danger ? MedievalColors.rejectMid : null,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: danger
                      ? MedievalColors.rejectMid
                      : MedievalColors.textGold,
                ),
                const SizedBox(height: 10),
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 16),
                    weight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: MedievalColors.textGold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: MedievalTextStyles.cinzel(
                    size: Responsive.sp(context, 12.5),
                    height: 1.4,
                    color: MedievalColors.textCream.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MedievalButton(
                        label: cancelLabel,
                        onPressed: onCancel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MedievalButton(
                        label: confirmLabel,
                        style: MedievalButtonStyle.primary,
                        onPressed: onConfirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
