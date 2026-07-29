import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/star_row.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    return AtmosphericBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/chapters'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'LEVELS',
                    style: AppTextStyles.orbitron(
                      weight: FontWeight.w700,
                      letterSpacing: 2,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: context
                    .read<LevelRepository>()
                    .levelIdsForChapter(chapterId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentBright),
                    );
                  }
                  final ids = snapshot.data!;
                  return BlocBuilder<ProgressBloc, ProgressState>(
                    builder: (context, progress) {
                      return GridView.builder(
                        padding:
                            EdgeInsets.all(Responsive.pageGutter(context)),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              Responsive.gridCrossAxisCount(context),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio:
                              Responsive.isNarrow(context) ? 0.92 : 1,
                        ),
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final unlocked =
                              progress.save.unlockedLevelIds.contains(id) ||
                                  index == 0;
                          final stars =
                              progress.save.levelProgress[id]?.stars ?? 0;
                          final isCurrent =
                              progress.save.lastPlayedLevelId == id ||
                                  (!progress.save.levelProgress
                                          .containsKey(id) &&
                                      unlocked &&
                                      index ==
                                          progress.save.unlockedLevelIds
                                                  .where((e) =>
                                                      e.startsWith(chapterId))
                                                  .length
                                                  .clamp(0, ids.length) -
                                              1);

                          return _LevelCell(
                            index: index + 1,
                            unlocked: unlocked,
                            stars: stars,
                            highlighted: isCurrent && unlocked,
                            onTap: unlocked
                                ? () => context.push('/play/$id')
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.index,
    required this.unlocked,
    required this.stars,
    required this.highlighted,
    required this.onTap,
  });

  final int index;
  final bool unlocked;
  final int stars;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: unlocked ? AppColors.cardGradient : null,
        color: unlocked ? null : AppColors.panel.withValues(alpha: 0.4),
        border: Border.all(
          color: highlighted
              ? AppColors.accentBright
              : unlocked
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : Colors.transparent,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.accentBright.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: unlocked
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$index',
                          style: AppTextStyles.orbitron(
                            weight: FontWeight.w700,
                            size: Responsive.sp(context, 16),
                            color: highlighted
                                ? AppColors.accentBright
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        StarRow(
                          filled: stars,
                          size: Responsive.isNarrow(context) ? 10 : 12,
                        ),
                      ],
                    ),
                  ),
                )
              : const Icon(Icons.lock_rounded, color: AppColors.muted),
        ),
      ),
    );
  }
}
