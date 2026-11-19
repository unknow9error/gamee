import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../domain/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/lesson_illustration.dart';
import '../../shared/widgets/trail_icon.dart';
import '../play/play_screen.dart';

class WorldScreen extends StatelessWidget {
  const WorldScreen({super.key, required this.world, required this.controller});
  final WorldDefinition world;
  final GameController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final lang = controller.language;
      final items = levels.where((level) => level.worldId == world.id).toList();
      final completed = items
          .where((level) => controller.progress.containsKey(level.id))
          .length;
      final tint = Color.alphaBlend(
        Color(world.color).withValues(alpha: .15),
        AppColors.paper,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(
            world.title.resolve(lang),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        body: SingleChildScrollView(
          key: ValueKey('world-scroll-${world.id}'),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SurfaceCard(
                    color: tint,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textFor(
                            lang,
                            'ГЛАВА ${world.order + 1} ИЗ ${worlds.length}',
                            '${worlds.length} ТАРАУДЫҢ ${world.order + 1}-СІ',
                            'CHAPTER ${world.order + 1} OF ${worlds.length}',
                          ),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          world.subtitle.resolve(lang),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const TrailIcon(TrailIconKind.check, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                textFor(
                                  lang,
                                  '$completed из ${items.length} приключений пройдено',
                                  '${items.length} шытырманның $completed-і аяқталды',
                                  '$completed of ${items.length} adventures explored',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: items.isEmpty ? 0 : completed / items.length,
                            minHeight: 7,
                            backgroundColor: Colors.white,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    textFor(
                      lang,
                      'Начни с того, что тебе интересно',
                      'Өзіңе қызықты ойыннан баста',
                      'Start wherever curiosity takes you',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    textFor(
                      lang,
                      'Все приключения открыты. К любимым можно возвращаться.',
                      'Барлық шытырман ашық. Сүйікті ойынға қайта оралуға болады.',
                      'Every adventure is open. Come back to your favorites anytime.',
                    ),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0; index < items.length; index++) ...[
                    _LevelCard(level: items[index], controller: controller),
                    if (index != items.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 27),
                        child: Container(
                          height: 22,
                          width: 3,
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: .20),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.controller});
  final LevelDefinition level;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final lang = controller.language;
    final progress = controller.progress[level.id];
    final globalNumber = levels.indexWhere((item) => item.id == level.id) + 1;
    return Semantics(
      button: true,
      label: '${level.title.resolve(lang)}, $globalNumber / ${levels.length}',
      child: SurfaceCard(
        key: ValueKey('level-card-${level.id}'),
        border: true,
        color: Colors.white,
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayScreen(controller: controller, level: level),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final side = box.maxWidth >= 600
                ? 175.0
                : box.maxWidth < 340
                ? 102.0
                : 124.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: side,
                      height: side + 35,
                      child: LessonIllustration(
                        level: level,
                        language: lang,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$globalNumber / ${levels.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.title.resolve(lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activityName(level.kind, lang),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (progress != null)
                          Wrap(
                            spacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (var star = 0; star < 3; star++)
                                TrailIcon(
                                  TrailIconKind.star,
                                  size: 19,
                                  selected: star < progress.stars,
                                  color: star < progress.stars
                                      ? null
                                      : AppColors.line,
                                ),
                              const SizedBox(width: 3),
                              Text(
                                textFor(
                                  lang,
                                  'Ещё раз',
                                  'Қайталау',
                                  'Play again',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  textFor(
                                    lang,
                                    'Играть',
                                    'Ойнау',
                                    'Let’s play',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: AppColors.green,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
