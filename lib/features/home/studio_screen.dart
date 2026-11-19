import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../domain/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/lesson_illustration.dart';
import '../../shared/widgets/trail_icon.dart';
import 'artwork_preview.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({
    super.key,
    required this.controller,
    required this.onPlay,
  });
  final GameController controller;
  final ValueChanged<LevelDefinition> onPlay;

  String _t(String ru, String kk, String en) =>
      textFor(controller.language, ru, kk, en);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 700;
        final artworks = controller.artworks;
        final archivedArtworks = controller.legacyArtworks;
        final archivedDrafts = controller.legacyDrafts;
        final archivedProgress = controller.legacyProgress;
        final allLevels = controller.allLevelIndex;
        final earlierWorlds = controller.legacyWorldIndex;
        final creative = levels
            .where(
              (level) =>
                  level.kind == ActivityKind.numberColor ||
                  level.kind == ActivityKind.guidedDraw,
            )
            .toList();
        return SingleChildScrollView(
          key: const PageStorageKey('studio-scroll'),
          padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 12, wide ? 32 : 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Твоя мастерская',
                      'Сенің шеберханаң',
                      'Your little studio',
                    ),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'У каждого рисунка есть своя история. Сохраним все её страницы.',
                      'Әр суреттің өз хикаясы бар. Оның әр бетін сақтаймыз.',
                      'Every picture has a story. Keep every colorful chapter.',
                    ),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  SectionTitle(
                    _t('Альбом художника', 'Суретші альбомы', 'My art album'),
                    trailing: Text(
                      '${artworks.length} / ${GameController.maxArtworks}',
                      key: const Key('studio-album-count'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (artworks.length >= GameController.maxArtworks) ...[
                    SurfaceCard(
                      color: AppColors.peach.withValues(alpha: .35),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _t(
                          'Альбом заполнен. Открой ненужную работу и удали её, чтобы освободить место для новой. Остальные рисунки останутся с тобой.',
                          'Альбом толды. Жаңа суретке орын босату үшін қажетсіз жұмысты ашып, өшір. Басқа суреттер сақталады.',
                          'Your album is full. Open a drawing you no longer need and delete it to make room. Your other pictures will stay safe.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (artworks.isEmpty)
                    _emptyAlbum()
                  else
                    _workGrid(context, [
                      for (final art in artworks)
                        _StudioWork(
                          key: art.id,
                          artwork: art,
                          level: allLevels[art.levelId],
                          data: art.data,
                        ),
                    ]),
                  SectionTitle(
                    _t(
                      'Создадим что-нибудь?',
                      'Бірдеңе жасаймыз ба?',
                      'What shall we create?',
                    ),
                  ),
                  Text(
                    _t(
                      'Сначала пройди задание. Потом можно творить по-своему и сохранять новые рисунки.',
                      'Алдымен тапсырманы орында. Содан соң өзіңше жасап, жаңа суреттерді сақтай аласың.',
                      'Try the activity first. Then make it your own and save each new version in your album.',
                    ),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, gridBox) {
                      final columns = gridBox.maxWidth >= 650 ? 2 : 1;
                      final width =
                          (gridBox.maxWidth - (columns - 1) * 14) / columns;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final level in creative)
                            SizedBox(width: width, child: _creativeCard(level)),
                        ],
                      );
                    },
                  ),
                  if (controller.hasLegacyArchive) ...[
                    SectionTitle(
                      _t(
                        'Архив открытий',
                        'Жаңалықтар мұрағаты',
                        'Your earlier discoveries',
                      ),
                    ),
                    SurfaceCard(
                      color: AppColors.blue.withValues(alpha: .45),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TrailIcon(TrailIconKind.album),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(
                                    'Бережно храним прежние работы',
                                    'Бұрынғы жұмыстарың сақтаулы',
                                    'A safe home for earlier creations',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _t(
                                    'Рисунки и наброски из прежней версии можно рассматривать. Они хранятся отдельно от новых приключений.',
                                    'Алдыңғы нұсқаның суреттері мен нобайларын көруге болады. Олар жаңа шытырмандардан бөлек сақталады.',
                                    'View your drawings and sketches from the earlier version. They live here, apart from your new adventures.',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (archivedArtworks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _workGrid(context, [
                        for (var i = 0; i < archivedArtworks.length; i++)
                          _StudioWork(
                            key: 'archive-$i-${archivedArtworks[i].id}',
                            artwork: archivedArtworks[i],
                            level: allLevels[archivedArtworks[i].levelId],
                            data: archivedArtworks[i].data,
                            archived: true,
                          ),
                      ]),
                    ],
                    if (archivedDrafts.isNotEmpty) ...[
                      SectionTitle(
                        _t(
                          'Сохранённые наброски',
                          'Сақталған нобайлар',
                          'Saved sketches',
                        ),
                      ),
                      _workGrid(context, [
                        for (final entry in archivedDrafts.entries)
                          _StudioWork(
                            key: 'archive-draft-${entry.key}',
                            level: allLevels[entry.key],
                            data: entry.value,
                            archived: true,
                            draft: true,
                          ),
                      ]),
                    ],
                    if (archivedProgress.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        border: true,
                        child: ExpansionTile(
                          key: const Key('studio-archive-progress'),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          title: Text(
                            _t(
                              'Прежние открытия: ${controller.legacyCompletedCount}',
                              'Бұрынғы жаңалықтар: ${controller.legacyCompletedCount}',
                              'Earlier discoveries: ${controller.legacyCompletedCount}',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          children: [
                            for (final entry in archivedProgress.entries)
                              ListTile(
                                leading: const TrailIcon(TrailIconKind.check),
                                title: Text(
                                  allLevels[entry.key]?.title.resolve(
                                        controller.language,
                                      ) ??
                                      _t(
                                        'Сохранённое открытие',
                                        'Сақталған жаңалық',
                                        'Saved discovery',
                                      ),
                                ),
                                subtitle:
                                    earlierWorlds[allLevels[entry.key]
                                            ?.worldId] ==
                                        null
                                    ? null
                                    : Text(
                                        earlierWorlds[allLevels[entry.key]!
                                                .worldId]!
                                            .title
                                            .resolve(controller.language),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _emptyAlbum() => SurfaceCard(
    color: AppColors.peach.withValues(alpha: .28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrailIcon(TrailIconKind.album, size: 40, selected: true),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Здесь будут твои шедевры',
                  'Мұнда сенің туындыларың болады',
                  'A home for your masterpieces',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'Закончи раскраску или рисунок — он появится в альбоме. Каждый новый вариант сохранится отдельно.',
                  'Бояуды не суретті аяқта — ол альбомда пайда болады. Әр жаңа нұсқа бөлек сақталады.',
                  'Finish a coloring page or drawing to add it here. Each new version gets its own place.',
                ),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _creativeCard(LevelDefinition level) {
    final completed = controller.progress.containsKey(level.id);
    return SurfaceCard(
      key: ValueKey('studio-create-${level.id}'),
      color: activityColor(level.kind).withValues(alpha: .48),
      padding: EdgeInsets.zero,
      onTap: () => onPlay(_creativeLevel(level, completed)),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 148,
            child: LessonIllustration(
              level: level,
              language: controller.language,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.title.resolve(controller.language),
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    completed
                        ? _t(
                            'Твори по-своему',
                            'Өзіңше жаса',
                            'Make it your own',
                          )
                        : _t(
                            'Сначала задание',
                            'Алдымен тапсырма',
                            'Try the activity first',
                          ),
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (completed)
                    const TrailIcon(TrailIconKind.brush, size: 27)
                  else
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.green,
                      size: 23,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workGrid(BuildContext context, List<_StudioWork> works) =>
      LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 900
              ? 4
              : box.maxWidth >= 580
              ? 3
              : 2;
          final width = (box.maxWidth - (columns - 1) * 13) / columns;
          return Wrap(
            spacing: 13,
            runSpacing: 13,
            children: [
              for (final work in works)
                SizedBox(
                  width: width,
                  child: SurfaceCard(
                    key: ValueKey('artwork-${work.key}'),
                    border: true,
                    padding: const EdgeInsets.all(10),
                    onTap: () => _showArtwork(context, work),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: _workPreview(work, controller.language),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          work.level?.title.resolve(controller.language) ??
                              _t(
                                'Сохранённый рисунок',
                                'Сақталған сурет',
                                'Saved drawing',
                              ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          work.draft && work.level?.kind == ActivityKind.maze
                              ? _t(
                                  'Задание · архив',
                                  'Тапсырма · мұрағат',
                                  'Activity · archive',
                                )
                              : work.draft
                              ? _t(
                                  'Набросок · архив',
                                  'Нобай · мұрағат',
                                  'Sketch · archive',
                                )
                              : work.archived
                              ? _t(
                                  'Из прежнего альбома',
                                  'Бұрынғы альбомнан',
                                  'From your earlier album',
                                )
                              : _date(work.artwork!.createdAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  void _showArtwork(BuildContext context, _StudioWork work) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ArtworkDialog(
      work: work,
      controller: controller,
      onCreate:
          work.archived ||
              work.level == null ||
              (work.level!.kind != ActivityKind.numberColor &&
                  work.level!.kind != ActivityKind.guidedDraw)
          ? null
          : () => onPlay(
              _creativeLevel(
                work.level!,
                controller.progress.containsKey(work.level!.id),
              ),
            ),
    ),
  );
}

LevelDefinition _creativeLevel(LevelDefinition level, bool completed) {
  if (!completed) return level;
  return LevelDefinition(
    id: level.id,
    worldId: level.worldId,
    kind: level.kind,
    scene: level.scene,
    variant: level.variant,
    difficulty: level.difficulty,
    title: level.title,
    instruction: level.instruction,
    order: level.order,
    illustrationAsset: level.illustrationAsset,
    voiceKey: level.voiceKey,
    activityData: {...level.activityData, 'creativeReplay': true},
  );
}

class _StudioWork {
  const _StudioWork({
    required this.key,
    required this.level,
    required this.data,
    this.artwork,
    this.archived = false,
    this.draft = false,
  });
  final String key;
  final LevelDefinition? level;
  final Map<String, dynamic> data;
  final Artwork? artwork;
  final bool archived;
  final bool draft;
}

Widget _workPreview(_StudioWork work, String language) {
  if (work.archived && work.level?.kind == ActivityKind.maze) {
    return _LegacyMazeSummary(data: work.data, language: language);
  }
  if (work.level == null) {
    return const Center(child: TrailIcon(TrailIconKind.album, size: 40));
  }
  return ArtworkPreview(level: work.level!, data: work.data);
}

class _LegacyMazeSummary extends StatelessWidget {
  const _LegacyMazeSummary({required this.data, required this.language});
  final Map<String, dynamic> data;
  final String language;

  @override
  Widget build(BuildContext context) {
    final route = data['route'];
    final count =
        route is List &&
            route.isNotEmpty &&
            route.every((point) => point is int && point >= 0)
        ? route.length
        : null;
    return Container(
      key: const Key('legacy-maze-summary'),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 200;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrailIcon(TrailIconKind.adventures, size: compact ? 32 : 56),
                const SizedBox(height: 8),
                Text(
                  count == null
                      ? textFor(
                          language,
                          'Сохранённый маршрут',
                          'Сақталған бағыт',
                          'Saved route',
                        )
                      : textFor(
                          language,
                          'Точек маршрута: $count',
                          'Бағыт нүктелері: $count',
                          'Saved route points: $count',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArtworkDialog extends StatefulWidget {
  const _ArtworkDialog({
    required this.work,
    required this.controller,
    this.onCreate,
  });
  final _StudioWork work;
  final GameController controller;
  final VoidCallback? onCreate;
  @override
  State<_ArtworkDialog> createState() => _ArtworkDialogState();
}

class _ArtworkDialogState extends State<_ArtworkDialog> {
  bool _deleting = false;
  String? _error;
  String _t(String ru, String kk, String en) =>
      textFor(widget.controller.language, ru, kk, en);

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t(
            'Удалить эту работу?',
            'Осы жұмысты өшіру керек пе?',
            'Delete this drawing?',
          ),
        ),
        content: Text(
          _t(
            'Этот рисунок удалится навсегда. Остальные варианты останутся в альбоме.',
            'Бұл сурет біржола өшіріледі. Басқа нұсқалар альбомда қалады.',
            'This drawing will be deleted permanently. Your other versions will stay in the album.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Оставить', 'Қалдыру', 'Keep it')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Удалить', 'Өшіру', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.controller.deleteArtwork(widget.work.artwork!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = _t(
          'Не получилось удалить работу. Она осталась в альбоме. Попробуй ещё раз.',
          'Жұмыс өшірілмеді. Ол альбомда қалды. Қайталап көр.',
          'The drawing could not be deleted. It is still in your album. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    return PopScope(
      canPop: !_deleting,
      child: Dialog(
        backgroundColor: AppColors.paper,
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          work.level?.title.resolve(
                                widget.controller.language,
                              ) ??
                              _t(
                                'Сохранённый рисунок',
                                'Сақталған сурет',
                                'Saved drawing',
                              ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: _deleting
                            ? null
                            : () => Navigator.of(context).pop(),
                        tooltip: _t('Закрыть', 'Жабу', 'Close'),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (work.archived)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        _t(
                          'Архив · только для просмотра',
                          'Мұрағат · тек көруге арналған',
                          'Archive · view only',
                        ),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: _workPreview(work, widget.controller.language),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const Key('artwork-delete-error'),
                          style: const TextStyle(color: Color(0xFF9A472F)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (widget.onCreate != null)
                    FilledButton.icon(
                      onPressed: _deleting
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onCreate!();
                            },
                      icon: const TrailIcon(
                        TrailIconKind.brush,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: Text(
                        _t(
                          'Нарисовать ещё',
                          'Тағы сурет салу',
                          'Create another',
                        ),
                      ),
                    ),
                  if (!work.archived && work.artwork != null)
                    TextButton.icon(
                      key: const Key('delete-artwork'),
                      onPressed: _deleting ? null : _delete,
                      icon: _deleting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _deleting
                            ? _t('Удаляем…', 'Өшірілуде…', 'Deleting…')
                            : _t(
                                'Удалить эту работу',
                                'Осы жұмысты өшіру',
                                'Delete this drawing',
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
