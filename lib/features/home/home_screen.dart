import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../domain/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/lesson_illustration.dart';
import '../../shared/widgets/trail_icon.dart';
import '../settings/settings_screen.dart';
import 'world_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onPlay,
    this.onOpenSettings,
    this.startTourTarget,
    this.chapterTourTarget,
  });
  final GameController controller;
  final ValueChanged<LevelDefinition> onPlay;
  final VoidCallback? onOpenSettings;
  final GlobalKey? startTourTarget;
  final GlobalKey? chapterTourTarget;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  GameController get controller => widget.controller;
  ValueChanged<LevelDefinition> get onPlay => widget.onPlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final lang = controller.language;
        final wide = box.maxWidth >= 700;
        return SingleChildScrollView(
          key: const PageStorageKey('home-scroll'),
          padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 12, wide ? 32 : 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Entrance(
                disabled: controller.reducedMotion,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            box.maxWidth < 360
                                ? textFor(
                                    lang,
                                    'Маленькие\nоткрытия',
                                    'Кішкентай\nжаңалықтар',
                                    'Little\ndiscoveries',
                                  )
                                : textFor(
                                    lang,
                                    'Радость маленьких\nоткрытий',
                                    'Кішкентай жаңалықтар\nқуанышы',
                                    'Little discoveries.\nBig smiles.',
                                  ),
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(fontSize: wide ? 36 : 28),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          key: const Key('home-age-settings'),
                          avatar: const TrailIcon(TrailIconKind.fox, size: 18),
                          label: Text(ageLabel(controller.childAge, lang)),
                          onPressed:
                              widget.onOpenSettings ??
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SettingsScreen(controller: controller),
                                ),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ContinueCard(
                      controller: controller,
                      onPlay: onPlay,
                      startTourTarget: widget.startTourTarget,
                    ),
                    SectionTitle(
                      textFor(
                        lang,
                        'Выбирай свой путь',
                        'Өз жолыңды таңда',
                        'Choose your own trail',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        textFor(
                          lang,
                          '${worlds.length} глав · ${levels.length} приключений. Все открыты!',
                          '${worlds.length} тарау · ${levels.length} шытырман. Бәрі ашық!',
                          '${worlds.length} chapters · ${levels.length} adventures. All yours to explore!',
                        ),
                        key: const Key('home-catalog-count'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, gridBox) {
                        final columns = gridBox.maxWidth >= 650 ? 2 : 1;
                        final width =
                            (gridBox.maxWidth - (columns - 1) * 16) / columns;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final world in worlds)
                              SizedBox(
                                width: width,
                                child: _WorldCard(
                                  world: world,
                                  controller: controller,
                                  tourTarget: world == worlds.first
                                      ? widget.chapterTourTarget
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SectionTitle(
                      textFor(
                        lang,
                        'Идеи на сегодня',
                        'Бүгінгі идеялар',
                        'A little inspiration',
                      ),
                    ),
                    Text(
                      textFor(
                        lang,
                        'Можно выбрать любое — или отправиться в другую игру.',
                        'Кез келгенін таңдауға немесе басқа ойынды ойнауға болады.',
                        'Choose any idea, or play something else you love.',
                      ),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    for (final quest in controller.dailyQuests) ...[
                      _QuestCard(
                        quest: quest,
                        controller: controller,
                        onPlay: onPlay,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        textFor(
                          lang,
                          'В своём темпе, с любопытством и улыбкой ♡',
                          'Өз қарқыныңмен, қызығушылықпен және күлімдеп ♡',
                          'At your own pace, with a curious heart ♡',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.controller,
    required this.onPlay,
    this.startTourTarget,
  });
  final GameController controller;
  final ValueChanged<LevelDefinition> onPlay;
  final GlobalKey? startTourTarget;

  @override
  Widget build(BuildContext context) {
    final lang = controller.language;
    final level = controller.nextLevel;
    final finished = controller.completedCount == levels.length;
    return SurfaceCard(
      color: AppColors.lime,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final imageSide = box.maxWidth >= 600
                  ? 180.0
                  : box.maxWidth < 290
                  ? 90.0
                  : 125.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textFor(
                            lang,
                            'ВМЕСТЕ С ФИНИ',
                            'ФИНИМЕН БІРГЕ',
                            'EXPLORE WITH FINI',
                          ),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.completedCount == 0
                              ? box.maxWidth < 290
                                    ? textFor(
                                        lang,
                                        'Привет!\nЯ Фини',
                                        'Сәлем!\nМен Фини',
                                        'Hello!\nI’m Fini',
                                      )
                                    : textFor(
                                        lang,
                                        'Привет!\nПоиграем?',
                                        'Сәлем!\nОйнаймыз ба?',
                                        'Hello, friend!\nLet’s play.',
                                      )
                              : finished
                              ? textFor(
                                  lang,
                                  'Столько открытий!\nПоиграем ещё?',
                                  'Қанша жаңалық!\nТағы ойнаймыз ба?',
                                  'So many discoveries!\nPlay again?',
                                )
                              : textFor(
                                  lang,
                                  'Нас ждёт\nновое открытие!',
                                  'Бізді жаңа\nжаңалық күтеді!',
                                  'A new discovery\nis waiting!',
                                ),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: box.maxWidth >= 600
                                    ? 34
                                    : box.maxWidth < 290
                                    ? 24
                                    : 27,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          textFor(
                            lang,
                            '${controller.completedCount} из ${levels.length} приключений',
                            '${levels.length} шытырманның ${controller.completedCount}-ы',
                            '${controller.completedCount} of ${levels.length} adventures',
                          ),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  _FiniPortrait(side: imageSide, language: lang),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('continue-adventure'),
              onPressed: () => onPlay(level),
              icon: KeyedSubtree(
                key: startTourTarget,
                child: const Icon(Icons.play_arrow_rounded),
              ),
              label: Text(
                textFor(
                  lang,
                  controller.completedCount == 0
                      ? 'Начать приключение'
                      : finished
                      ? 'Играть ещё'
                      : 'Продолжить',
                  controller.completedCount == 0
                      ? 'Шытырманды бастау'
                      : finished
                      ? 'Тағы ойнау'
                      : 'Жалғастыру',
                  controller.completedCount == 0
                      ? 'Let’s begin'
                      : finished
                      ? 'Play again'
                      : 'Continue',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox.square(
                    dimension: 56,
                    child: LessonIllustration(level: level, language: lang),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.title.resolve(lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        activityName(level.kind, lang),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.controller,
    this.tourTarget,
  });
  final WorldDefinition world;
  final GameController controller;
  final GlobalKey? tourTarget;

  @override
  Widget build(BuildContext context) {
    final lang = controller.language;
    final items = levels.where((level) => level.worldId == world.id).toList();
    final completed = items
        .where((level) => controller.progress.containsKey(level.id))
        .length;
    return SurfaceCard(
      key: ValueKey('world-card-${world.id}'),
      padding: EdgeInsets.zero,
      color: Color.alphaBlend(
        Color(world.color).withValues(alpha: .11),
        Colors.white,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorldScreen(world: world, controller: controller),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth < 350 ? 104.0 : 138.0;
          return Row(
            children: [
              SizedBox(
                width: side,
                height: side + 28,
                child: LessonIllustration(
                  level: items.first,
                  language: lang,
                  fit: BoxFit.contain,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textFor(
                          lang,
                          'ГЛАВА ${world.order + 1}',
                          '${world.order + 1}-ТАРАУ',
                          'CHAPTER ${world.order + 1}',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.green,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        world.title.resolve(lang),
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              textFor(
                                lang,
                                '$completed из ${items.length} открытий',
                                '${items.length} жаңалықтың $completed-і',
                                '$completed of ${items.length} explored',
                              ),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          KeyedSubtree(
                            key: tourTarget,
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                            ),
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
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.controller,
    required this.onPlay,
  });
  final DailyQuestDefinition quest;
  final GameController controller;
  final ValueChanged<LevelDefinition> onPlay;

  @override
  Widget build(BuildContext context) {
    final done = controller.dailyQuestProgress(quest) >= quest.target;
    final choices = levels.where((level) => level.kind == quest.kind);
    final level = choices.firstWhere(
      (level) => !controller.progress.containsKey(level.id),
      orElse: () => choices.first,
    );
    return SurfaceCard(
      key: ValueKey('daily-quest-${quest.id}'),
      border: true,
      padding: const EdgeInsets.all(14),
      onTap: () => onPlay(level),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: activityColor(quest.kind),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TrailIcon(
              done ? TrailIconKind.check : trailActivityKind(quest.kind),
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title.resolve(controller.language),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                if (done)
                  Text(
                    textFor(
                      controller.language,
                      'Получилось! Можно повторить',
                      'Жарайсың! Қайта ойнауға болады',
                      'You did it! Play again anytime',
                    ),
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _FiniPortrait extends StatefulWidget {
  const _FiniPortrait({required this.side, required this.language});
  final double side;
  final String language;
  @override
  State<_FiniPortrait> createState() => _FiniPortraitState();
}

class _FiniPortraitState extends State<_FiniPortrait> {
  int _attempt = 0;
  Future<void> _retry() async {
    await ResizeImage(
      const AssetImage('assets/images/fini.png'),
      width: 420,
    ).evict(configuration: createLocalImageConfiguration(context));
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/fini.png',
    key: ValueKey('fini-$_attempt'),
    width: widget.side,
    height: widget.side * 1.2,
    fit: BoxFit.contain,
    cacheWidth: 420,
    semanticLabel: textFor(
      widget.language,
      'Лисёнок Фини',
      'Түлкі Фини',
      'Fini the fox',
    ),
    errorBuilder: (_, error, stack) => SizedBox(
      width: widget.side,
      height: widget.side * 1.2,
      child: Center(
        child: TextButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            textFor(widget.language, 'Ещё раз', 'Қайталау', 'Try again'),
          ),
        ),
      ),
    ),
  );
}
