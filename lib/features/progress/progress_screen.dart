import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../domain/calendar.dart';
import '../../domain/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/trail_icon.dart';

/// Learning rewards follow saved activity completion, never a timer or a streak.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.controller,
    required this.onPlay,
  });

  final GameController controller;
  final ValueChanged<LevelDefinition> onPlay;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  bool _showMastery = false;
  AchievementDefinition? _recentMilestone;
  late Set<String> _knownMilestones;
  late int _lastSessionCompletions;
  late int _previousCompletedCount;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observeController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // The tab can stay mounted overnight. Read the controller's local-day
      // queries again on return, without treating that refresh as a reward.
      setState(() {});
    }
  }

  void _observeController() {
    _knownMilestones = _earnedMilestones.map((item) => item.id).toSet();
    _lastSessionCompletions = controller.sessionCompletedCount;
    _previousCompletedCount = controller.completedCount;
    controller.addListener(_onProgressChanged);
  }

  List<AchievementDefinition> get _earnedMilestones => controller
      .earnedAchievements
      .where((achievement) => achievement.kind == null)
      .toList();

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onProgressChanged);
      _recentMilestone = null;
      _observeController();
    }
  }

  void _onProgressChanged() {
    if (!mounted) {
      return;
    }
    // completeLevel publishes optimistic state before saving. The session count
    // advances only after a committed completion, so failed saves do not cheer.
    if (controller.completedCount < _previousCompletedCount) {
      _knownMilestones = _earnedMilestones.map((item) => item.id).toSet();
      _recentMilestone = null;
    }
    if (controller.sessionCompletedCount > _lastSessionCompletions) {
      final earned = _earnedMilestones;
      final newMilestones =
          earned.where((item) => !_knownMilestones.contains(item.id)).toList()
            ..sort((a, b) => a.target.compareTo(b.target));
      if (newMilestones.isNotEmpty) {
        _recentMilestone = newMilestones.last;
      }
      _knownMilestones = earned.map((item) => item.id).toSet();
    }
    _lastSessionCompletions = controller.sessionCompletedCount;
    _previousCompletedCount = controller.completedCount;
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onProgressChanged);
    super.dispose();
  }

  LevelDefinition? _levelForQuest(DailyQuestDefinition quest) {
    final available = levels
        .where(
          (level) => level.kind == quest.kind && controller.isUnlocked(level),
        )
        .toList();
    for (final level in available) {
      if (!controller.progress.containsKey(level.id)) {
        return level;
      }
    }
    final today = controller.activityCalendar[quest.dayKey] ?? const <String>{};
    for (final level in available) {
      if (!today.contains(level.id)) {
        return level;
      }
    }
    if (available.isNotEmpty) {
      return available.first;
    }
    for (final level in levels) {
      if (controller.isUnlocked(level) &&
          !controller.progress.containsKey(level.id)) {
        return level;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final language = controller.language;
    final mastery = achievements.where((item) => item.kind != null).toList();
    final milestones = achievements.where((item) => item.kind == null).toList();
    final earnedMastery = controller.earnedAchievements
        .where((item) => item.kind != null)
        .length;
    final earnedStickerIds = controller.earnedStickers
        .map((sticker) => sticker.id)
        .toSet();
    final quests = controller.dailyQuests;
    final finishedQuests = quests
        .where((quest) => controller.dailyQuestProgress(quest) >= quest.target)
        .length;

    return SingleChildScrollView(
      key: const PageStorageKey('discoveries-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CollectionHeader(
                language: language,
                stickerCount: earnedStickerIds.length,
                masteryCount: earnedMastery,
                totalPlayDays: controller.playedDates.length,
              ),
              const SizedBox(height: 18),
              if (_recentMilestone != null) ...[
                _MilestoneCelebration(
                  achievement: _recentMilestone!,
                  language: language,
                  reducedMotion:
                      controller.reducedMotion ||
                      MediaQuery.disableAnimationsOf(context),
                  onDismiss: () => setState(() => _recentMilestone = null),
                ),
                const SizedBox(height: 18),
              ],
              _WeekCalendar(
                language: language,
                days: controller.currentWeek,
                weeklyPlayDays: controller.weeklyPlayDays,
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: textFor(
                  language,
                  'Идеи на сегодня',
                  'Бүгінгі идеялар',
                  'Ideas for today',
                ),
                subtitle: textFor(
                  language,
                  'Выбери любую. Остальное может подождать.',
                  'Кез келгенін таңда. Қалғаны күте алады.',
                  'Pick any idea. The others can wait.',
                ),
                count: '$finishedQuests / ${quests.length}',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 840 ? 3 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var index = 0; index < quests.length; index++)
                        SizedBox(
                          width: width,
                          child: _QuestCard(
                            quest: quests[index],
                            language: language,
                            ordinal: index + 1,
                            completed: controller.dailyQuestProgress(
                              quests[index],
                            ),
                            level: _levelForQuest(quests[index]),
                            onPlay: widget.onPlay,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: textFor(
                  language,
                  'Твоя коллекция',
                  'Сенің жинағың',
                  'Your collection',
                ),
                subtitle: textFor(
                  language,
                  'У каждого задания своя наклейка.',
                  'Әр тапсырманың өз жапсырмасы бар.',
                  'Every activity has its own sticker.',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CollectionTab(
                      key: const ValueKey('collection-tab-stickers'),
                      title: textFor(
                        language,
                        'Наклейки',
                        'Жапсырмалар',
                        'Stickers',
                      ),
                      count: '${earnedStickerIds.length} / ${stickers.length}',
                      selected: !_showMastery,
                      onTap: () => setState(() => _showMastery = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CollectionTab(
                      key: const ValueKey('collection-tab-badges'),
                      title: textFor(language, 'Значки', 'Белгілер', 'Badges'),
                      count: '$earnedMastery / ${mastery.length}',
                      selected: _showMastery,
                      onTap: () => setState(() => _showMastery = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_showMastery)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 880
                        ? 5
                        : constraints.maxWidth >= 580
                        ? 4
                        : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: [
                        for (var index = 0; index < stickers.length; index++)
                          SizedBox(
                            width: width,
                            child: _StickerCard(
                              sticker: stickers[index],
                              number: index + 1,
                              language: language,
                              earned: earnedStickerIds.contains(
                                stickers[index].id,
                              ),
                              onPlay:
                                  controller.isUnlocked(
                                    levelIndex[stickers[index].levelId]!,
                                  )
                                  ? () => widget.onPlay(
                                      levelIndex[stickers[index].levelId]!,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    );
                  },
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 680 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final achievement in mastery)
                          SizedBox(
                            width: width,
                            child: _MasteryCard(
                              achievement: achievement,
                              language: language,
                              completed: controller.achievementProgress(
                                achievement,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 26),
              _MilestonePath(
                language: language,
                milestones: milestones,
                completedCount: controller.completedCount,
              ),
              const SizedBox(height: 20),
              Text(
                textFor(
                  language,
                  'Расти в своём темпе. Все находки останутся с тобой.',
                  'Өз қарқыныңмен өс. Барлық жетістігің өзіңде қалады.',
                  'Grow at your own pace. Your discoveries are yours to keep.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.language,
    required this.stickerCount,
    required this.masteryCount,
    required this.totalPlayDays,
  });
  final String language;
  final int stickerCount, masteryCount, totalPlayDays;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textFor(
            language,
            'Мои открытия',
            'Менің жаңалықтарым',
            'My discoveries',
          ),
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 9),
        Text(
          textFor(
            language,
            'Маленькие шаги. Удивительные находки.',
            'Кішкентай қадамдар. Ғажайып жаңалықтар.',
            'Little steps. Wonderful discoveries.',
          ),
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: const Color(0xFFE5EEDD)),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatPill(
              value: '$stickerCount',
              label: textFor(
                language,
                russianPlural(stickerCount, 'наклейка', 'наклейки', 'наклеек'),
                'жапсырма',
                stickerCount == 1 ? 'sticker' : 'stickers',
              ),
            ),
            _StatPill(
              value: '$masteryCount',
              label: textFor(
                language,
                russianPlural(masteryCount, 'значок', 'значка', 'значков'),
                'белгі',
                masteryCount == 1 ? 'badge' : 'badges',
              ),
            ),
            _StatPill(
              key: const ValueKey('total-play-days'),
              value: '$totalPlayDays',
              label: textFor(
                language,
                russianPlural(
                  totalPlayDays,
                  'день вместе',
                  'дня вместе',
                  'дней вместе',
                ),
                'күн бірге',
                totalPlayDays == 1 ? 'day together' : 'days together',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatPill extends StatelessWidget {
  const _StatPill({super.key, required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.lime,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({
    required this.language,
    required this.days,
    required this.weeklyPlayDays,
  });
  final String language;
  final List<PlayDay> days;
  final int weeklyPlayDays;

  @override
  Widget build(BuildContext context) {
    final weekdayNames = switch (language) {
      'kk' => const ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жс'],
      'en' => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
      _ => const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    };
    return Container(
      key: const ValueKey('play-week'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textFor(language, 'Твоя неделя', 'Сенің аптаң', 'Your week'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            textFor(
              language,
              'Отмечаем дни с новыми открытиями.',
              'Жаңа жетістіктері бар күндерді белгілейміз.',
              'A little mark for each day of discovery.',
            ),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < days.length; index++)
                Expanded(
                  child: Semantics(
                    key: ValueKey(
                      'playday-${calendarDayKey(days[index].date)}',
                    ),
                    label:
                        '${_dayLabel(days[index].date, language)}. ${days[index].isToday ? textFor(language, 'Сегодня. ', 'Бүгін. ', 'Today. ') : ''}'
                        '${days[index].played ? textFor(language, 'Были открытия', 'Жетістіктер болды', 'Discoveries made') : textFor(language, 'Свободный день', 'Бос күн', 'An open day')}',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Text(
                          weekdayNames[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: days[index].isToday
                                ? AppColors.green
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          key: days[index].isToday
                              ? const ValueKey('calendar-today')
                              : null,
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: days[index].played
                                ? AppColors.green
                                : AppColors.paper,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: days[index].isToday
                                  ? AppColors.green
                                  : AppColors.line,
                              width: days[index].isToday ? 2 : 1,
                            ),
                          ),
                          child: days[index].played
                              ? const TrailIcon(
                                  TrailIconKind.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${days[index].date.day}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: days[index].isToday
                                ? AppColors.green
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            weeklyPlayDays == 0
                ? textFor(
                    language,
                    'Начни с любого задания, когда захочется.',
                    'Қалаған кезіңде кез келген тапсырмадан баста.',
                    'Start with any activity whenever you feel like it.',
                  )
                : textFor(
                    language,
                    'Дней с открытиями на этой неделе: $weeklyPlayDays',
                    'Осы аптадағы жетістік күндері: $weeklyPlayDays',
                    'Discovery days this week: $weeklyPlayDays',
                  ),
            key: const ValueKey('week-summary'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.language,
    required this.ordinal,
    required this.completed,
    required this.level,
    required this.onPlay,
  });
  final DailyQuestDefinition quest;
  final String language;
  final int ordinal, completed;
  final LevelDefinition? level;
  final ValueChanged<LevelDefinition> onPlay;

  @override
  Widget build(BuildContext context) {
    final done = completed >= quest.target;
    final isMatching = level?.kind == quest.kind;
    return Container(
      key: ValueKey('daily-quest-${quest.id}'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: done ? AppColors.lime.withValues(alpha: .25) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: done ? AppColors.green.withValues(alpha: .25) : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.green : AppColors.lavender,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const TrailIcon(
                        TrailIconKind.check,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        '$ordinal',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  quest.title.resolve(language),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              TrailIcon(trailActivityKind(quest.kind), size: 30),
            ],
          ),
          const SizedBox(height: 10),
          if (done)
            Text(
              textFor(
                language,
                'Готово! Хорошая находка.',
                'Дайын! Керемет жаңалық.',
                'Done! A lovely discovery.',
              ),
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            Text(
              isMatching
                  ? textFor(
                      language,
                      'Одно маленькое приключение.',
                      'Бір шағын шытырман оқиға.',
                      'One little adventure.',
                    )
                  : textFor(
                      language,
                      'Откроем следующее доступное приключение.',
                      'Келесі қолжетімді шытырманды ашайық.',
                      'Let’s open the next available adventure.',
                    ),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('daily-quest-play-${quest.id}'),
                onPressed: level == null ? null : () => onPlay(level!),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  textFor(
                    language,
                    isMatching ? 'Начать' : 'Продолжить',
                    isMatching ? 'Бастау' : 'Жалғастыру',
                    isMatching ? 'Let’s play' : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({
    super.key,
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String title, count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 76),
      padding: const EdgeInsets.all(12),
      foregroundColor: selected ? Colors.white : AppColors.green,
      backgroundColor: selected
          ? AppColors.green
          : AppColors.line.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    child: Semantics(
      selected: selected,
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.lime : AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StickerCard extends StatelessWidget {
  const _StickerCard({
    required this.sticker,
    required this.number,
    required this.language,
    required this.earned,
    required this.onPlay,
  });
  final StickerDefinition sticker;
  final int number;
  final String language;
  final bool earned;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final status = earned
        ? textFor(language, 'Собрано', 'Жиналды', 'Collected')
        : textFor(
            language,
            'Ждёт открытия',
            'Ашылуын күтеді',
            'Waiting to be found',
          );
    return Semantics(
      key: ValueKey('sticker-${sticker.id}'),
      label: '${sticker.title.resolve(language)}. $status.',
      button: onPlay != null,
      onTap: onPlay,
      excludeSemantics: true,
      child: Material(
        color: earned ? Colors.white : const Color(0xFFF1F2E9),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: earned
                    ? AppColors.green.withValues(alpha: .3)
                    : AppColors.line,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.15,
                      child: Opacity(
                        opacity: earned ? 1 : .25,
                        child: _Illustration(
                          asset: sticker.illustrationAsset,
                          number: number,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: earned ? AppColors.green : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: earned
                            ? const TrailIcon(
                                TrailIconKind.check,
                                size: 15,
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: AppColors.muted,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  sticker.title.resolve(language),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: earned ? AppColors.ink : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  key: ValueKey('sticker-status-${sticker.id}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: earned ? AppColors.green : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.asset, required this.number});
  final String? asset;
  final int number;
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: AppColors.muted,
        ),
      ),
    );
    if (asset == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        asset!,
        fit: BoxFit.contain,
        cacheWidth: 480,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({
    required this.achievement,
    required this.language,
    required this.completed,
  });
  final AchievementDefinition achievement;
  final String language;
  final int completed;
  @override
  Widget build(BuildContext context) {
    final earned = completed >= achievement.target;
    final relatedLevels = levels
        .where((level) => level.kind == achievement.kind)
        .toList();
    return Semantics(
      key: ValueKey('achievement-${achievement.id}'),
      label:
          '${achievement.title.resolve(language)}. ${achievement.description.resolve(language)}. '
          '${earned ? textFor(language, 'Получен', 'Алынды', 'Collected') : '${completed.clamp(0, achievement.target)} / ${achievement.target}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: earned ? AppColors.lime.withValues(alpha: .35) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: earned
                ? AppColors.green.withValues(alpha: .3)
                : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    achievement.title.resolve(language),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                earned
                    ? const TrailIcon(TrailIconKind.check, size: 25)
                    : const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.muted,
                        size: 21,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description.resolve(language),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var index = 0; index < relatedLevels.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: Opacity(
                        opacity: earned ? 1 : .55,
                        child: _Illustration(
                          asset: relatedLevels[index].illustrationAsset,
                          number: index + 1,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Text(
                  earned
                      ? textFor(language, 'Получен', 'Алынды', 'Collected')
                      : '${completed.clamp(0, achievement.target)} / ${achievement.target}',
                  key: ValueKey('achievement-status-${achievement.id}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: earned ? AppColors.green : AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestonePath extends StatelessWidget {
  const _MilestonePath({
    required this.language,
    required this.milestones,
    required this.completedCount,
  });
  final String language;
  final List<AchievementDefinition> milestones;
  final int completedCount;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('milestone-path'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.lavender.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textFor(
            language,
            'Твои большие открытия',
            'Сенің үлкен жаңалықтарың',
            'Your big discoveries',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final milestone in milestones)
              Container(
                key: ValueKey('milestone-${milestone.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: completedCount >= milestone.target
                      ? AppColors.green
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${milestone.target} / ${levels.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: completedCount >= milestone.target
                        ? Colors.white
                        : AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _MilestoneCelebration extends StatelessWidget {
  const _MilestoneCelebration({
    required this.achievement,
    required this.language,
    required this.reducedMotion,
    required this.onDismiss,
  });
  final AchievementDefinition achievement;
  final String language;
  final bool reducedMotion;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('milestone-celebration-${achievement.id}'),
    tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
    duration: Duration(milliseconds: reducedMotion ? 0 : 450),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: child,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 8, 13),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textFor(
                    language,
                    'Новое достижение!',
                    'Жаңа жетістік!',
                    'A new achievement!',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.title.resolve(language),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            tooltip: textFor(language, 'Закрыть', 'Жабу', 'Dismiss'),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.count,
  });
  final String title, subtitle;
  final String? count;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (count != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                count!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  );
}

String _dayLabel(DateTime day, String language) =>
    '${day.day}.${day.month}.${day.year}';
