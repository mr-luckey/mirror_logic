import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/domain/economy/player_save.dart';
import 'package:mirror_logic/presentation/blocs/economy/economy_bloc.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/blocs/settings/settings_cubit.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AtmosphericBackground(
      child: SafeArea(
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) {
            return ListView(
              padding: EdgeInsets.all(Responsive.pageGutter(context)),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                    ),
                    Expanded(
                      child: Text(
                        'SETTINGS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.orbitron(
                          weight: FontWeight.w700,
                          letterSpacing: 2,
                          size: Responsive.sp(context, 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDIO',
                        style: AppTextStyles.orbitron(
                          size: 12,
                          letterSpacing: 1.5,
                          color: AppColors.accentBright,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Music', style: AppTextStyles.exo2()),
                      Slider(
                        value: settings.musicVolume,
                        onChanged: (v) =>
                            context.read<SettingsCubit>().setMusicVolume(v),
                      ),
                      Text('Sound Effects', style: AppTextStyles.exo2()),
                      Slider(
                        value: settings.sfxVolume,
                        onChanged: (v) =>
                            context.read<SettingsCubit>().setSfxVolume(v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text('Vibration', style: AppTextStyles.exo2()),
                        value: settings.haptics,
                        onChanged: (v) =>
                            context.read<SettingsCubit>().setHaptics(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GAME',
                        style: AppTextStyles.orbitron(
                          size: 12,
                          letterSpacing: 1.5,
                          color: AppColors.accentBright,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Assist Mode',
                            style: AppTextStyles.exo2()),
                        subtitle: Text(
                          'Larger mirror hit targets',
                          style: AppTextStyles.exo2(
                              color: AppColors.muted, size: 12),
                        ),
                        value: settings.assistMode,
                        onChanged: (v) =>
                            context.read<SettingsCubit>().setAssistMode(v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Angle Readout',
                            style: AppTextStyles.exo2()),
                        value: settings.angleReadout,
                        onChanged: (v) => context
                            .read<SettingsCubit>()
                            .setAngleReadout(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ABOUT',
                        style: AppTextStyles.orbitron(
                          size: 12,
                          letterSpacing: 1.5,
                          color: AppColors.accentBright,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Privacy Policy',
                            style: AppTextStyles.exo2()),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.muted),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text('Rate Us', style: AppTextStyles.exo2()),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.muted),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Reset Progress',
                          style: AppTextStyles.exo2(
                              color: AppColors.laserRed),
                        ),
                        onTap: () => _confirmReset(context),
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
      builder: (_) => AlertDialog(
        title: Text('Reset Progress?', style: AppTextStyles.orbitron()),
        content: Text(
          'This clears all stars, coins, and unlocked levels. This cannot be undone.',
          style: AppTextStyles.exo2(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reset',
              style: AppTextStyles.exo2(color: AppColors.laserRed),
            ),
          ),
        ],
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
