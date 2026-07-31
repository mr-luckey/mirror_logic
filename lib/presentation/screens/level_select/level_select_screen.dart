import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/nav.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/game_constants.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/presentation/blocs/progress/progress_bloc.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_progress.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_star_row.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // Built once: creating the future inside build restarts the load on every
  // ancestor rebuild and flashes the spinner.
  late final Future<List<String>> _levelIds =
      context.read<LevelRepository>().levelIdsForChapter(widget.chapterId);

  /// Resolved so the header names the hall rather than showing a raw id.
  late final Future<String> _chapterTitle = context
      .read<LevelRepository>()
      .chapters()
      .then(
        (all) => all
            .firstWhere(
              (c) => c.id == widget.chapterId,
              orElse: () => ChapterInfo(
                id: widget.chapterId,
                title: widget.chapterId.toUpperCase(),
                subtitle: '',
                levelIds: const [],
                levelCount: 0,
                maxStars: 0,
              ),
            )
            .title,
      );

  String get chapterId => widget.chapterId;

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.pageGutter(context);

    return MedievalWoodBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: FutureBuilder<String>(
                future: _chapterTitle,
                builder: (context, snapshot) => MedievalScreenHeader(
                  title: snapshot.data ?? 'Levels',
                  subtitle: 'Chapter ${chapterId.replaceFirst('ch', '')}',
                  onBack: () => context.backTo('/chapters'),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _levelIds,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'These halls could not be read',
                        style: MedievalTextStyles.cinzel(
                          color: MedievalColors.textMuted,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const MedievalLoader(message: 'LIGHTING THE HALLS');
                  }
                  final ids = snapshot.data!;
                  return BlocBuilder<ProgressBloc, ProgressState>(
                    builder: (context, progress) {
                      final cleared = ids
                          .where(
                            (id) =>
                                progress.save.levelProgress[id]?.completed ??
                                false,
                          )
                          .length;

                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(gutter, 2, gutter, 10),
                            child: _ChapterProgress(
                              cleared: cleared,
                              total: ids.length,
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding:
                                  EdgeInsets.fromLTRB(gutter, 0, gutter, 20),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    Responsive.gridCrossAxisCount(context),
                                mainAxisSpacing: 9,
                                crossAxisSpacing: 9,
                                childAspectRatio:
                                    Responsive.isNarrow(context) ? 0.92 : 1,
                              ),
                              itemCount: ids.length,
                              itemBuilder: (context, index) {
                                final id = ids[index];
                                final unlocked =
                                    GameConstants.unlockAllLevelsForTesting ||
                                        progress.save.unlockedLevelIds
                                            .contains(id) ||
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
                                                            e
                                                                .split('_')
                                                                .first ==
                                                            chapterId)
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
                            ),
                          ),
                        ],
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

class _ChapterProgress extends StatelessWidget {
  const _ChapterProgress({required this.cleared, required this.total});

  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'CLEARED',
          style: MedievalTextStyles.cinzel(
            size: 9,
            letterSpacing: 1.6,
            color: MedievalColors.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MedievalProgressBar(
            value: total == 0 ? 0 : cleared / total,
            height: 5,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$cleared/$total',
          style: MedievalTextStyles.cinzel(
            size: 11,
            weight: FontWeight.w700,
            color: MedievalColors.textGold,
          ),
        ),
      ],
    );
  }
}

/// One level as a carved stone tablet set into the wall.
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
    final narrow = Responsive.isNarrow(context);

    return MedievalPressable(
      onPressed: onTap,
      enabled: unlocked,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocked
                ? const [
                    MedievalColors.stoneLight,
                    MedievalColors.stone,
                    MedievalColors.stoneDark,
                  ]
                : [
                    MedievalColors.stoneDark,
                    MedievalColors.stoneGrout,
                  ],
          ),
          border: Border.all(
            color: highlighted
                ? MedievalColors.bronzeHighlight
                : unlocked
                    ? MedievalColors.bronzeDark.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.5),
            width: highlighted ? 2.2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            if (highlighted)
              BoxShadow(
                color: MedievalColors.bronzeHighlight.withValues(alpha: 0.45),
                blurRadius: 14,
              ),
          ],
        ),
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
                        style: MedievalTextStyles.cinzelDecorative(
                          weight: FontWeight.w700,
                          size: Responsive.sp(context, 17),
                          color: highlighted
                              ? MedievalColors.bronzeHighlight
                              : MedievalColors.textCream,
                        ).copyWith(
                          shadows: const [
                            // Carved into the stone rather than sitting on it.
                            Shadow(
                              color: Colors.black,
                              blurRadius: 0,
                              offset: Offset(0, 1.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      MedievalStarRow(
                        filled: stars,
                        size: narrow ? 10 : 11,
                        spacing: 0.5,
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Opacity(
                  opacity: 0.55,
                  child: Image.asset(
                    MedievalArt.padlock,
                    width: narrow ? 20 : 24,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.lock_rounded,
                      color: MedievalColors.textMuted,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
