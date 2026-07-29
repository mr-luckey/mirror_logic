import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/atmospheric_background.dart';
import 'package:mirror_logic/presentation/widgets/glass_panel.dart';
import 'package:mirror_logic/presentation/widgets/star_row.dart';

class ChapterSelectScreen extends StatelessWidget {
  const ChapterSelectScreen({super.key});

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
                    onPressed: () => context.go('/menu'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'CHAPTERS',
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
              child: FutureBuilder<List<ChapterInfo>>(
                future: context.read<LevelRepository>().chapters(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentBright),
                    );
                  }
                  final chapters = snapshot.data!;
                  return BlocBuilder<ProgressBloc, ProgressState>(
                    builder: (context, progress) {
                      return ListView.separated(
                        padding:
                            EdgeInsets.all(Responsive.pageGutter(context)),
                        itemCount: chapters.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final ch = chapters[index];
                          final stars =
                              progress.save.starsForChapter(ch.id);
                          final completed =
                              progress.save.completedCountForChapter(ch.id);
                          final unlocked =
                              ch.id == GameConstants.chapter1Id ||
                                  progress.save.completedCountForChapter(
                                        GameConstants.chapter1Id,
                                      ) >=
                                      16;

                          return _ChapterCard(
                            chapter: ch,
                            stars: stars,
                            completed: completed,
                            unlocked: unlocked,
                            onTap: unlocked
                                ? () => context.push('/levels/${ch.id}')
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

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.stars,
    required this.completed,
    required this.unlocked,
    required this.onTap,
  });

  final ChapterInfo chapter;
  final int stars;
  final int completed;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = Responsive.isNarrow(context) ? 56.0 : 72.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: GlassPanel(
          glow: unlocked,
          padding: EdgeInsets.all(Responsive.isNarrow(context) ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: thumb,
                height: thumb,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: unlocked
                      ? const LinearGradient(
                          colors: [AppColors.panel, AppColors.surface],
                        )
                      : null,
                  color: unlocked ? null : AppColors.panel,
                  border: Border.all(
                    color: unlocked
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : AppColors.glassBorder,
                  ),
                ),
                child: Icon(
                  unlocked ? Icons.science_outlined : Icons.lock_rounded,
                  color: unlocked ? AppColors.accentBright : AppColors.muted,
                  size: thumb * 0.42,
                ),
              ),
              SizedBox(width: Responsive.isNarrow(context) ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.orbitron(
                        weight: FontWeight.w700,
                        size: Responsive.sp(context, 13),
                        letterSpacing: 0.8,
                        color: unlocked
                            ? AppColors.textPrimary
                            : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chapter.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.exo2(
                        color: AppColors.muted,
                        size: Responsive.sp(context, 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const StarRow(filled: 3, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$stars/${chapter.maxStars}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.exo2(
                              weight: FontWeight.w600,
                              size: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$completed/${chapter.levelCount}',
                          style: AppTextStyles.exo2(
                            color: AppColors.muted,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: chapter.maxStars == 0
                            ? 0
                            : stars / chapter.maxStars,
                        minHeight: 4,
                        backgroundColor: AppColors.panel,
                        color: AppColors.accentBright,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
