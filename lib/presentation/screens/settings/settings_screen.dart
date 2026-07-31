import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_button.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toggle.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Slider still asserts on a Material ancestor, and the wood backdrop is
    // only painted, not a Material surface.
    return Material(
      type: MaterialType.transparency,
      child: _body(context),
    );
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
                      _Section(
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
                      _Section(
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
                      _Section(
                        title: 'About',
                        icon: Icons.auto_stories_rounded,
                        children: [
                          _LinkRow(label: 'Privacy Policy', onTap: () {}),
                          const MedievalDivider(),
                          _LinkRow(label: 'Rate Us', onTap: () {}),
                          const MedievalDivider(),
                          _LinkRow(
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

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pageGutter(dialogContext),
            ),
            child: MedievalPanel(
              glow: MedievalColors.rejectMid,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: MedievalColors.rejectMid,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RESET PROGRESS?',
                    style: MedievalTextStyles.cinzel(
                      size: Responsive.sp(dialogContext, 17),
                      weight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: MedievalColors.textGold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Every star, coin and unlocked hall is lost. '
                    'This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: MedievalTextStyles.cinzel(
                      size: Responsive.sp(dialogContext, 12.5),
                      height: 1.4,
                      color: MedievalColors.textCream.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: MedievalButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(dialogContext, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MedievalButton(
                          label: 'Reset',
                          style: MedievalButtonStyle.primary,
                          onPressed: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MedievalPanel(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MedievalColors.bronzeLight),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: MedievalTextStyles.cinzel(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: MedievalColors.textGold,
                ),
              ),
            ],
          ),
          const MedievalDivider(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, this.note, this.danger = false});

  final String label;
  final String? note;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MedievalTextStyles.cinzel(
            size: Responsive.sp(context, 13.5),
            weight: FontWeight.w600,
            color: danger
                ? MedievalColors.rejectMid
                : MedievalColors.textCream,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(
            note!,
            style: MedievalTextStyles.cinzel(
              size: Responsive.sp(context, 10.5),
              height: 1.3,
              color: MedievalColors.textMuted,
            ),
          ),
        ],
      ],
    );
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: _RowLabel(label: label, note: note)),
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
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _RowLabel(label: label)),
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
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return MedievalPressable(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(child: _RowLabel(label: label, danger: danger)),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: danger
                  ? MedievalColors.rejectMid.withValues(alpha: 0.8)
                  : MedievalColors.bronzeLight.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
