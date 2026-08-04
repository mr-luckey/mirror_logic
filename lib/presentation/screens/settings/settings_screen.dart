import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/audio_scope.dart';
import 'package:mirror_logic/app/review_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_exit_scope.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_option_rows.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toggle.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    // Slider still asserts on a Material ancestor, and the wood backdrop is
    // only painted, not a Material surface.
    return Material(type: MaterialType.transparency, child: _body(context));
  }

  Widget _body(BuildContext context) {
    final gutter = Responsive.pageGutter(context);

    return MedievalWoodBackground(
      child: SafeArea(
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            final cubit = context.read<SettingsCubit>();

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: MedievalScreenHeader(
                    title: 'Settings',
                    subtitle: 'Tune the keep',
                    onBack: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
                    children: [
                      MedievalSection(
                        title: 'Audio',
                        icon: Icons.music_note_rounded,
                        children: [
                          _SliderRow(
                            label: 'Music',
                            value: settings.musicVolume,
                            onChanged: cubit.setMusicVolume,
                          ),
                          const MedievalDivider(),
                          _SliderRow(
                            label: 'Sound Effects',
                            value: settings.sfxVolume,
                            onChanged: cubit.setSfxVolume,
                            // Let the player hear what they just set.
                            onChangeEnd: (_) => context.playSfx(Sfx.coin),
                          ),
                          const MedievalDivider(),
                          _ToggleRow(
                            label: 'Vibration',
                            note: 'Taps back when the beam locks on',
                            value: settings.haptics,
                            onChanged: cubit.setHaptics,
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      MedievalSection(
                        title: 'Game',
                        icon: Icons.tune_rounded,
                        children: [
                          _ToggleRow(
                            label: 'Assist Mode',
                            note: 'Larger mirror hit targets',
                            value: settings.assistMode,
                            onChanged: cubit.setAssistMode,
                          ),
                          const MedievalDivider(),
                          _ToggleRow(
                            label: 'Angle Readout',
                            note: 'Show the angle while you turn a mirror',
                            value: settings.angleReadout,
                            onChanged: cubit.setAngleReadout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      MedievalSection(
                        title: 'About',
                        icon: Icons.auto_stories_rounded,
                        children: [
                          MedievalLinkRow(
                            label: 'About Us',
                            note: 'Version, credits and contact',
                            onTap: () => context.push('/about'),
                          ),
                          const MedievalDivider(),
                          MedievalLinkRow(
                            label: 'Rate Us',
                            note: 'Leave a review on Google Play',
                            onTap: () => _rate(context),
                          ),
                          const MedievalDivider(),
                          MedievalLinkRow(
                            label: 'Reset Progress',
                            danger: true,
                            onTap: () => _confirmReset(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Sends the player straight to the Play listing rather than through Play's
  /// in-app sheet, which shows nothing once the device quota is spent — see
  /// [ReviewService.openStoreListing]. Tapping here also retires the random
  /// prompt, since the player has clearly already found the button.
  Future<void> _rate(BuildContext context) async {
    final review = context.review;
    if (review == null) return;
    await review.markSettled();
    final opened = await review.openStoreListing();
    if (!opened && context.mounted) {
      MedievalToast.show(context, 'Could not open the Play Store');
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => MedievalConfirmDialog(
        danger: true,
        icon: Icons.warning_amber_rounded,
        title: 'Reset Progress?',
        body:
            'Every star and unlocked hall is lost. '
            'Your coin is kept. This cannot be undone.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Reset',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<SaveRepository>().resetProgress();
    if (!context.mounted) return;
    context.read<ProgressBloc>().add(const ProgressRefresh());
    context.read<EconomyBloc>().add(const EconomyStarted());
    context.go('/menu');
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: MedievalRowLabel(label: label, note: note),
            ),
            const SizedBox(width: 12),
            MedievalToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: MedievalRowLabel(label: label)),
              Text(
                '${(value * 100).round()}%',
                style: MedievalTextStyles.cinzelDecorative(
                  size: Responsive.sp(context, 12),
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: MedievalColors.bronzeLight,
              inactiveTrackColor: Colors.black.withValues(alpha: 0.5),
              thumbColor: MedievalColors.bronzeHighlight,
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
