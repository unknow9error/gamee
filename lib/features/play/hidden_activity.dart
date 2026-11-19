import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../shared/art/art_scene.dart';
import 'activity_config.dart';
import 'raster_hidden_activity.dart';

/// Routes curated bitmap activities while keeping archived vector drafts usable.
class HiddenActivity extends StatelessWidget {
  const HiddenActivity({super.key, required this.config});

  final ActivityConfig config;

  @override
  Widget build(BuildContext context) => config.level.illustrationAsset != null
      ? RasterHiddenActivity(config: config)
      : _LegacyHiddenActivity(config: config);
}

class _LegacyHiddenActivity extends StatefulWidget {
  const _LegacyHiddenActivity({required this.config});

  final ActivityConfig config;

  @override
  State<_LegacyHiddenActivity> createState() => _HiddenActivityState();
}

class _HiddenActivityState extends State<_LegacyHiddenActivity> {
  late ArtScene _scene;
  final Set<String> _found = <String>{};
  final Set<String> _colored = <String>{};
  String? _selected;
  String? _neededAnimal;
  String? _lastFound;
  bool _missed = false;
  bool _completionSent = false;

  String _t(String ru, String kk, String en) =>
      textFor(widget.config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(covariant _LegacyHiddenActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != widget.config.level.id) {
      _restore();
    }
  }

  void _restore() {
    _scene = SceneFactory.create(
      widget.config.level.scene,
      variant: widget.config.level.variant,
      geometric: true,
      worldId: widget.config.level.worldId,
    );
    _found.clear();
    _colored.clear();
    final rawFound = widget.config.initialData?['found'];
    final validIds = _scene.hiddenAnimals.map((animal) => animal.id).toSet();
    if (rawFound is List) {
      _found.addAll(rawFound.whereType<String>().where(validIds.contains));
    }
    final rawFills = widget.config.initialData?['fills'];
    if (widget.config.initialData?['version'] == 2 && rawFills is Map) {
      for (final animal in _scene.hiddenAnimals) {
        if (!_found.contains(animal.id)) continue;
        for (final region in _scene.regions) {
          if (animal.regionIds.contains(region.id) &&
              rawFills[region.id] == region.color.toARGB32()) {
            _colored.add(region.id);
          }
        }
      }
    }
    final selected = widget.config.initialData?['selected'];
    _selected = selected is String && _found.contains(selected)
        ? selected
        : _found.firstOrNull;
    _neededAnimal = null;
    _lastFound = null;
    _missed = false;
    _completionSent = false;
  }

  String _animalName(HiddenAnimal animal) => switch (widget.config.language) {
    'kk' => animal.nameKk,
    'en' => animal.nameEn,
    _ => animal.nameRu,
  };

  bool get _finished =>
      _scene.hiddenAnimals.isNotEmpty &&
      _found.length == _scene.hiddenAnimals.length &&
      _requiredRegionIds.every(_colored.contains);

  Set<String> get _requiredRegionIds =>
      _scene.hiddenAnimals.expand((animal) => animal.regionIds).toSet();

  Map<String, Color> get _fills {
    return <String, Color>{
      for (final region in _scene.regions)
        if (_colored.contains(region.id)) region.id: region.color,
    };
  }

  Map<String, dynamic> get _data => <String, dynamic>{
    'version': 2,
    'kind': 'hiddenAnimals',
    'geometric': true,
    'scene': widget.config.level.scene,
    'worldId': widget.config.level.worldId,
    'variant': widget.config.level.variant,
    'found': _found.toList(growable: false),
    'selected': _selected,
    'fills': <String, int>{
      for (final entry in _fills.entries) entry.key: entry.value.toARGB32(),
    },
  };

  void _hit(Offset point) {
    if (_completionSent) return;
    ArtRegion? hitRegion;
    // The painter draws from first to last, so the last containing path wins.
    for (final region in _scene.regions.reversed) {
      if (region.path.contains(point)) {
        hitRegion = region;
        break;
      }
    }
    if (hitRegion == null) {
      _showMiss();
      return;
    }
    HiddenAnimal? target;
    for (final animal in _scene.hiddenAnimals) {
      if (animal.regionIds.contains(hitRegion.id)) {
        target = animal;
        break;
      }
    }
    if (target == null) {
      _showMiss();
      return;
    }
    final foundAnimal = target;
    if (!_found.contains(foundAnimal.id)) {
      setState(() {
        _found.add(foundAnimal.id);
        _selected = foundAnimal.id;
        _lastFound = foundAnimal.id;
        _neededAnimal = null;
        _missed = false;
      });
    } else if (_selected != foundAnimal.id) {
      setState(() {
        _neededAnimal = foundAnimal.id;
        _lastFound = null;
        _missed = false;
      });
      return;
    } else {
      if (_colored.contains(hitRegion.id)) return;
      final regionId = hitRegion.id;
      setState(() {
        _colored.add(regionId);
        _lastFound = null;
        _neededAnimal = null;
        _missed = false;
      });
    }
    widget.config.onFeedback();
    widget.config.onChanged(_data);
  }

  void _showMiss() {
    if (_missed) return;
    setState(() {
      _missed = true;
      _lastFound = null;
      _neededAnimal = null;
    });
  }

  void _selectAnimal(HiddenAnimal animal) {
    if (!_found.contains(animal.id) || _completionSent) return;
    setState(() {
      _selected = animal.id;
      _lastFound = null;
      _neededAnimal = null;
      _missed = false;
    });
    widget.config.onChanged(_data);
  }

  void _complete() {
    if (!_finished || _completionSent) return;
    setState(() => _completionSent = true);
    widget.config.onCompleted(_data);
  }

  String get _message {
    if (_finished) {
      return _t(
        'Все друзья найдены и раскрашены!',
        'Барлық достар табылып, боялды!',
        'Every friend is found and colored!',
      );
    }
    if (_neededAnimal != null) {
      final animal = _scene.hiddenAnimals.firstWhere(
        (animal) => animal.id == _neededAnimal,
      );
      return _t(
        'Выбери краску «${_animalName(animal)}» и закрась деталь.',
        '«${_animalName(animal)}» бояуын таңдап, бөлшекті боя.',
        'Choose the ${_animalName(animal)} paint, then color this piece.',
      );
    }
    if (_missed) {
      return _t(
        'Посмотри на глазки, ушки и хвостики.',
        'Көздеріне, құлақтары мен құйрықтарына қара.',
        'Look for eyes, ears, and little tails.',
      );
    }
    if (_lastFound != null) {
      final animal = _scene.hiddenAnimals.firstWhere(
        (animal) => animal.id == _lastFound,
      );
      return _t(
        'Нашёлся: ${_animalName(animal)}! Теперь раскрась каждую деталь.',
        '${_animalName(animal)} табылды! Енді әр бөлшегін боя.',
        'Found: ${_animalName(animal)}! Now color each piece.',
      );
    }
    if (_selected != null) {
      final animal = _scene.hiddenAnimals.firstWhere(
        (animal) => animal.id == _selected,
      );
      return _t(
        'Краска: ${_animalName(animal)}. Коснись его белых деталей.',
        'Бояу: ${_animalName(animal)}. Оның ақ бөлшектерін түрт.',
        'Paint: ${_animalName(animal)}. Tap its white pieces.',
      );
    }
    return _t(
      'Коснись животного, спрятанного в фигурах.',
      'Пішіндердің ішіне жасырынған жануарды түрт.',
      'Tap an animal hiding in the shapes.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        if (wide) {
          final compact = constraints.maxHeight < 420;
          // In landscape every vertical pixel belongs to the picture. Put
          // instructions and controls beside it rather than above and below.
          return Row(
            children: [
              Expanded(child: _board()),
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    _statusHeader(stacked: true, compact: compact),
                    Expanded(child: _targetList(wide: true, compact: compact)),
                    _finishButton(),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _statusHeader(),
            _targetList(wide: false),
            Expanded(child: _board()),
            _finishButton(),
          ],
        );
      },
    );
  }

  Widget _statusHeader({bool stacked = false, bool compact = false}) {
    final message = AnimatedSwitcher(
      duration: widget.config.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: Text(
        _message,
        key: ValueKey(_message),
        style: const TextStyle(fontSize: 13, height: 1.25),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final counters = [
      Text(
        '${_found.length} / ${_scene.hiddenAnimals.length}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      Text(
        '${_colored.length}/${_requiredRegionIds.length} ${_t('деталей', 'бөлшек', 'pieces')}',
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ];
    final progress = Semantics(
      label: _t(
        'Найдено ${_found.length} из ${_scene.hiddenAnimals.length}, раскрашено ${_colored.length} из ${_requiredRegionIds.length} деталей',
        '${_scene.hiddenAnimals.length} достан ${_found.length} табылды, ${_requiredRegionIds.length} бөлшектен ${_colored.length} боялды',
        '${_found.length} of ${_scene.hiddenAnimals.length} found, ${_colored.length} of ${_requiredRegionIds.length} pieces colored',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(16),
          ),
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    counters.first,
                    const SizedBox(width: 10),
                    Flexible(child: counters.last),
                  ],
                )
              : Column(mainAxisSize: MainAxisSize.min, children: counters),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [message, const SizedBox(height: 6), progress],
            )
          : Row(
              children: [
                Expanded(child: message),
                const SizedBox(width: 8),
                progress,
              ],
            ),
    );
  }

  Widget _finishButton() => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('hidden-finish'),
        onPressed: _finished && !_completionSent ? _complete : null,
        icon: Icon(_finished ? Icons.celebration_rounded : Icons.brush_rounded),
        label: Text(
          _finished
              ? _t('Готово!', 'Дайын!', 'All done!')
              : _t(
                  'Раскрась все детали',
                  'Барлық бөлшекті боя',
                  'Color every piece',
                ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _targetList({required bool wide, bool compact = false}) {
    final chips = [
      for (final animal in _scene.hiddenAnimals)
        Semantics(
          label:
              '${_animalName(animal)}, ${_found.contains(animal.id) ? _t('найдено', 'табылды', 'found') : _t('ещё ищем', 'іздеп жатырмыз', 'still hiding')}',
          selected: _selected == animal.id,
          button: _found.contains(animal.id),
          onTap: _found.contains(animal.id)
              ? () => _selectAnimal(animal)
              : null,
          child: ExcludeSemantics(
            child: InkWell(
              key: ValueKey('hidden-target-${animal.id}'),
              borderRadius: BorderRadius.circular(17),
              onTap: _found.contains(animal.id)
                  ? () => _selectAnimal(animal)
                  : null,
              child: AnimatedContainer(
                duration: widget.config.reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _selected == animal.id ? AppColors.lime : Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    width: _selected == animal.id ? 2 : 1,
                    color: _selected == animal.id
                        ? AppColors.green
                        : AppColors.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _found.contains(animal.id)
                            ? _scene.regions
                                  .firstWhere(
                                    (region) =>
                                        animal.regionIds.contains(region.id),
                                  )
                                  .color
                            : AppColors.line,
                      ),
                      child: Icon(
                        !_found.contains(animal.id)
                            ? Icons.search_rounded
                            : animal.regionIds.every(_colored.contains)
                            ? Icons.check_rounded
                            : Icons.brush_rounded,
                        size: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _animalName(animal),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: wide
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact) ...[
                    Text(
                      _t('Найди и раскрась', 'Тауып, боя', 'Find, then color'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final chip in chips) ...[
                    chip,
                    SizedBox(height: compact ? 6 : 12),
                  ],
                ],
              ),
            )
          : SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: chip,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _board() {
    final selectedAnimal = _scene.hiddenAnimals
        .where((animal) => animal.id == _selected)
        .firstOrNull;
    final nextTarget =
        selectedAnimal != null &&
            selectedAnimal.regionIds.any((id) => !_colored.contains(id))
        ? selectedAnimal
        : _scene.hiddenAnimals
                  .where((animal) => !_found.contains(animal.id))
                  .firstOrNull ??
              _scene.hiddenAnimals
                  .where(
                    (animal) =>
                        animal.regionIds.any((id) => !_colored.contains(id)),
                  )
                  .firstOrNull;
    final hintRegionId = nextTarget?.regionIds
        .where((id) => !_colored.contains(id))
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: RepaintBoundary(
                    key: const Key('hidden-artwork'),
                    child: LayoutBuilder(
                      builder: (context, boardConstraints) {
                        return Semantics(
                          label: _t(
                            'Узор с животными. Найди их на рисунке.',
                            'Жануарлар жасырынған өрнек. Оларды суреттен тап.',
                            'An animal pattern. Find the animals in the picture.',
                          ),
                          hint: _t(
                            'Увеличивай узор двумя пальцами, чтобы раскрасить мелкие детали.',
                            'Ұсақ бөлшектерді бояу үшін өрнекті екі саусақпен үлкейт.',
                            'Pinch to zoom in and color the small pieces.',
                          ),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: GestureDetector(
                              key: const Key('hidden-canvas'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _hit(
                                Offset(
                                  details.localPosition.dx *
                                      _scene.viewBox.width /
                                      boardConstraints.maxWidth,
                                  details.localPosition.dy *
                                      _scene.viewBox.height /
                                      boardConstraints.maxHeight,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: ArtScenePainter(
                                      scene: _scene,
                                      fills: _fills,
                                    ),
                                  ),
                                  if (widget.config.showHint &&
                                      hintRegionId != null)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _HiddenHintPainter(
                                          scene: _scene,
                                          regionIds: {hintRegionId},
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HiddenHintPainter extends CustomPainter {
  const _HiddenHintPainter({required this.scene, required this.regionIds});

  final ArtScene scene;
  final Set<String> regionIds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / scene.viewBox.width,
      size.height / scene.viewBox.height,
    );
    for (final region in scene.regions) {
      if (!regionIds.contains(region.id)) continue;
      canvas.drawPath(
        region.path,
        Paint()
          ..color = AppColors.yellow.withValues(alpha: 0.24)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        region.path,
        Paint()
          ..color = AppColors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HiddenHintPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.regionIds != regionIds;
}
