import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/nav.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_progress.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_star_row.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class ChapterSelectScreen extends StatefulWidget {
  const ChapterSelectScreen({super.key});

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  // Built once: creating the future inside build restarts the load on every
  // ancestor rebuild and flashes the spinner.
  late final Future<List<ChapterInfo>> _chapters =
      context.read<LevelRepository>().chapters();

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);

    return MedievalWoodBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: MedievalScreenHeader(
                title: 'Chapters',
                subtitle: 'Choose your trial',
                onBack: () => context.backTo('/menu'),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ChapterInfo>>(
                future: _chapters,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'The archive could not be opened',
                        style: MedievalTextStyles.cinzel(
                          color: MedievalColors.textMuted,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const MedievalLoader(message: 'UNSEALING ARCHIVE');
                  }
                  final chapters = snapshot.data!;
                  return BlocBuilder<ProgressBloc, ProgressState>(
                    builder: (context, progress) {
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 20),
                        itemCount: chapters.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 13),
                        itemBuilder: (context, index) {
                          final ch = chapters[index];
                          final stars = progress.save.starsForChapter(
                            ch.id,
                            levelIds: ch.levelIds,
                          );
                          final completed =
                              progress.save.completedCountForChapter(
                            ch.id,
                            levelIds: ch.levelIds,
                          );
                          final unlocked =
                              GameConstants.unlockAllLevelsForTesting ||
                                  progress.save.isChapterUnlocked(
                                    ch.id,
                                    ch.levelCount,
                                  );

                          return _ChapterCard(
                            chapter: ch,
                            index: index,
                            stars: stars,
                            completed: completed,
                            unlocked: unlocked,
                            onTap: unlocked
                                ? () => context.push('/levels/${ch.id}')
                                : null,
                          ).animate().fadeIn(
                                delay: (index * 55).ms,
                                duration: 320.ms,
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
    required this.index,
    required this.stars,
    required this.completed,
    required this.unlocked,
    required this.onTap,
  });

  final ChapterInfo chapter;
  final int index;
  final int stars;
  final int completed;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = Responsive.isNarrow(context);
    final thumb = narrow ? 58.0 : 70.0;
    final ratio = chapter.maxStars == 0 ? 0.0 : stars / chapter.maxStars;

    return MedievalPressable(
      onPressed: onTap,
      enabled: unlocked,
      // A chapter opening is a heavier moment than a button press.
      sfx: Sfx.unlock,
      child: Opacity(
        opacity: unlocked ? 1 : 0.62,
        child: MedievalPanel(
          padding: EdgeInsets.all(narrow ? 11 : 14),
          glow: unlocked && ratio >= 1 ? MedievalColors.bronzeHighlight : null,
          child: Row(
            children: [
              _Thumb(
                size: thumb,
                unlocked: unlocked,
                chapterId: chapter.id,
                index: index,
              ),
              SizedBox(width: narrow ? 11 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MedievalTextStyles.cinzel(
                        weight: FontWeight.w700,
                        size: Responsive.sp(context, 13),
                        letterSpacing: 1.2,
                        color: unlocked
                            ? MedievalColors.textGold
                            : MedievalColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chapter.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MedievalTextStyles.cinzel(
                        color: MedievalColors.textMuted,
                        size: Responsive.sp(context, 11),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const MedievalStarRow(filled: 3, size: 12, spacing: 1),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$stars/${chapter.maxStars}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MedievalTextStyles.cinzel(
                              weight: FontWeight.w700,
                              size: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$completed/${chapter.levelCount}',
                          style: MedievalTextStyles.cinzel(
                            color: MedievalColors.textMuted,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    MedievalProgressBar(value: ratio),
                  ],
                ),
              ),
              if (unlocked)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: MedievalColors.bronzeLight.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter emblem: a unique tome for each hall, a padlock for a sealed one.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.size,
    required this.unlocked,
    required this.chapterId,
    required this.index,
  });

  final double size;
  final bool unlocked;
  final String chapterId;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MedievalPanel(
            style: MedievalPanelStyle.inset,
            radius: 10,
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              unlocked
                  ? MedievalArt.tomeForChapter(chapterId)
                  : MedievalArt.padlock,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              color: unlocked ? null : Colors.black.withValues(alpha: 0.35),
              colorBlendMode: unlocked ? null : BlendMode.srcATop,
              errorBuilder: (_, _, _) => Icon(
                unlocked ? Icons.menu_book_rounded : Icons.lock_rounded,
                color: MedievalColors.textGold,
                size: size * 0.4,
              ),
            ),
          ),
          if (unlocked)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: MedievalColors.bronzeMetal,
                  border: Border.all(
                    color: MedievalColors.bronzeDark,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: MedievalTextStyles.cinzelDecorative(
                    size: 10,
                    weight: FontWeight.w700,
                    color: MedievalColors.woodDeep,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
