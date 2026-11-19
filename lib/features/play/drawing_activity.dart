import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/tracing_layouts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/artwork_limits.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/trace_engine.dart';

class DrawingActivity extends StatefulWidget {
  const DrawingActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  State<DrawingActivity> createState() => _DrawingActivityState();
}

/// Passive artwork uses the same master, normalized ink and stamp renderer as
/// the live lesson. It intentionally has no input or completion callbacks.
class DrawingArtworkPreview extends StatefulWidget {
  const DrawingArtworkPreview({
    super.key,
    required this.level,
    required this.data,
    this.language = 'ru',
  });
  final LevelDefinition level;
  final Map<String, dynamic> data;
  final String language;

  @override
  State<DrawingArtworkPreview> createState() => _DrawingArtworkPreviewState();
}

class _DrawingArtworkPreviewState extends State<DrawingArtworkPreview> {
  int _reload = 0;
  LevelDefinition get level => widget.level;
  Map<String, dynamic> get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final rawAge = data['childAge'];
    final age = rawAge is int ? rawAge.clamp(3, 11) : 6;
    final layout = guidedDrawingLayout(level.scene, AgeBand.fromAge(age));
    final strokes = <List<Offset>>[];
    var points = 0;
    final rawStrokes = data['strokes'];
    if (rawStrokes is List) {
      for (final raw in rawStrokes.take(ArtworkLimits.maxBrushStrokes)) {
        if (raw is! Map) continue;
        final decoded = decodeTraceStrokes([raw['points']]);
        for (final stroke in decoded) {
          if (points + stroke.length > ArtworkLimits.maxTotalBrushPoints) break;
          strokes.add(stroke);
          points += stroke.length;
        }
      }
    }
    final stamps = _decodeStamps(data['stamps']);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, space) {
          final asset = level.illustrationAsset ?? layout.asset;
          final decodeWidth =
              (space.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(96, 1254);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                key: ValueKey('$asset:$_reload'),
                fit: BoxFit.contain,
                cacheWidth: decodeWidth,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.paper,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.muted,
                        ),
                        if (space.maxWidth >= 150)
                          Text(
                            textFor(
                              widget.language,
                              'Рисунок не загрузился',
                              'Сурет жүктелмеді',
                              'The picture has not loaded',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        IconButton(
                          tooltip: textFor(
                            widget.language,
                            'Повторить',
                            'Қайталау',
                            'Try again',
                          ),
                          onPressed: () async {
                            await ResizeImage.resizeIfNeeded(
                              decodeWidth,
                              null,
                              AssetImage(asset),
                            ).evict();
                            if (mounted) setState(() => _reload++);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _LessonPainter(
                    layout: layout,
                    step: layout.actions.length,
                    completed: [strokes],
                    current: const [],
                    checkpoints: const [],
                    tapGuide: false,
                    guide: 0,
                    hint: false,
                    stamps: stamps,
                    side: space.maxWidth,
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

List<_Stamp> _decodeStamps(Object? value) {
  final stamps = <_Stamp>[];
  if (value is! List) return stamps;
  for (final raw in value.take(48)) {
    if (raw is! Map ||
        raw['point'] is! List ||
        (raw['point'] as List).length != 2 ||
        raw['color'] is! int ||
        raw['shape'] is! int) {
      continue;
    }
    final point = raw['point'] as List;
    if (point[0] is! num || point[1] is! num) continue;
    final x = (point[0] as num).toDouble(), y = (point[1] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x < 0 || y < 0 || x > 1 || y > 1) {
      continue;
    }
    stamps.add(
      _Stamp(
        Offset(x * 400, y * 400),
        Color(raw['color'] as int),
        (raw['shape'] as int).clamp(0, 2),
      ),
    );
  }
  return stamps;
}

class _DrawingActivityState extends State<DrawingActivity>
    with SingleTickerProviderStateMixin {
  late GuidedDrawingLayout _layout;
  late List<TraceValidator> _validators;
  late AnimationController _guide;
  final List<List<List<Offset>>> _completed = [];
  final List<String> _completedModes = [];
  final List<List<int>> _completedProofs = [];
  final List<List<Offset>> _current = [];
  final List<int> _checkpoints = [];
  final List<_Stamp> _stamps = [];
  int? _activePointer;
  bool _tapGuide = false;
  bool _sent = false;
  bool _assetLoaded = false;
  bool _assetFailed = false;
  String? _loadingAsset;
  double _coverage = 0;
  int _selectedColor = 0;
  int _stampShape = 0;

  static const _colors = [
    Color(0xFFF7CF63),
    Color(0xFFEB9B79),
    Color(0xFF81C4B3),
    Color(0xFF7FB5D5),
    Color(0xFFB1A0D0),
    Color(0xFFEC9DB4),
  ];
  ActivityConfig get config => widget.config;
  bool get _creativeReplay =>
      config.level.activityData['creativeReplay'] == true;
  bool get _decorating =>
      _creativeReplay || _completed.length == _layout.actions.length;
  bool get _hasCreativeInput =>
      _stamps.isNotEmpty ||
      _completed.any((stage) => stage.any(_strokeHasVisibleInk)) ||
      _current.any(_strokeHasVisibleInk);
  bool get _canFinish => !_creativeReplay || _hasCreativeInput;

  bool _strokeHasVisibleInk(List<Offset> stroke) {
    var length = 0.0;
    for (var index = 1; index < stroke.length; index++) {
      length += (stroke[index] - stroke[index - 1]).distance;
      if (length >= 4) return true;
    }
    return false;
  }

  DrawingAction get _action => _layout.actions[_completed.length];
  int get _pointCount =>
      _completed.fold<int>(
        0,
        (sum, stage) =>
            sum + stage.fold<int>(0, (count, stroke) => count + stroke.length),
      ) +
      _current.fold<int>(0, (sum, stroke) => sum + stroke.length);
  int get _strokeCount =>
      _completed.fold<int>(0, (sum, stage) => sum + stage.length) +
      _current.length;
  String _t(String ru, String kk, String en) =>
      textFor(config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _guide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _initialize();
    _setMotion();
  }

  void _initialize() {
    _layout = guidedDrawingLayout(config.level.scene, config.ageBand);
    _validators = [
      for (final action in _layout.actions)
        TraceValidator(
          action.path,
          tolerance: switch (config.ageBand) {
            AgeBand.preschool => 29,
            AgeBand.primary => 22,
            AgeBand.advanced => 22,
          },
          requiredCoverage: config.ageBand == AgeBand.preschool ? .66 : .76,
          requiredHorizontalRuns: action.requiredHorizontalRuns,
          minimumPatternHeight: action.minimumPatternHeight,
        ),
    ];
    _completed.clear();
    _completedModes.clear();
    _completedProofs.clear();
    _current.clear();
    _checkpoints.clear();
    _stamps.clear();
    _activePointer = null;
    _sent = false;
    _coverage = 0;
    _tapGuide = config.ageBand == AgeBand.preschool;
    _assetLoaded = false;
    _assetFailed = false;
    _loadingAsset = null;
    final data = config.initialData;
    if (data == null ||
        data['version'] != 2 ||
        data['type'] != 'guidedDraw' ||
        data['levelId'] != config.level.id ||
        data['layoutId'] != _layout.id ||
        data['ageBand'] != config.ageBand.name ||
        data['childAge'] != config.childAge) {
      return;
    }
    final stages = data['stepStrokes'];
    final modes = data['stepModes'];
    final proofs = data['checkpointProofs'];
    if (stages is List && modes is List && proofs is List) {
      for (
        var index = 0;
        index < stages.length && index < _layout.actions.length;
        index++
      ) {
        if (index >= modes.length || index >= proofs.length) break;
        final strokes = decodeTraceStrokes(stages[index]);
        final mode = modes[index];
        final proof = orderedCheckpointProof(
          proofs[index],
          _layout.actions[index].checkpointCount,
        );
        final valid = mode == 'trace'
            ? _validators[index].evaluate(strokes).complete
            : mode == 'checkpoints' &&
                  config.ageBand == AgeBand.preschool &&
                  proof.length == _layout.actions[index].checkpointCount;
        if (!valid || !_fitsBudget(strokes)) break;
        _completed.add(strokes);
        _completedModes.add(mode as String);
        _completedProofs.add(proof);
      }
    }
    if (!_decorating) {
      _tapGuide =
          config.ageBand == AgeBand.preschool && data['tapGuide'] != false;
      final strokes = decodeTraceStrokes(data['currentStrokes']);
      if (_fitsBudget(strokes)) _current.addAll(strokes);
      if (_tapGuide) {
        _checkpoints.addAll(
          orderedCheckpointProof(
            data['currentCheckpoints'],
            _action.checkpointCount,
          ),
        );
        _rebuildCheckpointStroke();
        _coverage = _checkpoints.length / _action.checkpointCount;
        if (_checkpoints.length == _action.checkpointCount) {
          _advance('checkpoints');
        }
      } else {
        _coverage = _validators[_completed.length].evaluate(_current).coverage;
      }
    }
    if (_decorating) _stamps.addAll(_decodeStamps(data['stamps']));
  }

  bool _fitsBudget(List<List<Offset>> strokes) =>
      _pointCount + strokes.fold<int>(0, (sum, s) => sum + s.length) <=
          ArtworkLimits.maxTotalBrushPoints &&
      _strokeCount + strokes.length <= ArtworkLimits.maxBrushStrokes;

  void _setMotion() {
    if (config.reducedMotion) {
      _guide.stop();
      _guide.value = .25;
    } else {
      _guide.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadArtwork();
  }

  void _loadArtwork() {
    final asset = config.level.illustrationAsset ?? _layout.asset;
    if (_loadingAsset == asset) return;
    _loadingAsset = asset;
    var failed = false;
    precacheImage(
      AssetImage(asset),
      context,
      onError: (_, _) => failed = true,
    ).then((_) {
      if (!mounted || _loadingAsset != asset) return;
      setState(() {
        _assetLoaded = !failed;
        _assetFailed = failed;
      });
    });
  }

  @override
  void didUpdateWidget(covariant DrawingActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != config.level.id ||
        oldWidget.config.childAge != config.childAge) {
      _initialize();
      _loadArtwork();
    }
    if (oldWidget.config.reducedMotion != config.reducedMotion) _setMotion();
  }

  @override
  void dispose() {
    _guide.dispose();
    super.dispose();
  }

  Map<String, dynamic> _data() => {
    'version': 2,
    'type': 'guidedDraw',
    'levelId': config.level.id,
    'layoutId': _layout.id,
    'ageBand': config.ageBand.name,
    'childAge': config.childAge,
    'scene': config.level.scene,
    'illustrationAsset': config.level.illustrationAsset ?? _layout.asset,
    'step': _completed.length,
    if (_creativeReplay) 'creativeReplay': true,
    'tapGuide': _tapGuide,
    'stepStrokes': [for (final s in _completed) encodeTraceStrokes(s)],
    'stepModes': List<String>.of(_completedModes),
    'checkpointProofs': [for (final p in _completedProofs) List<int>.of(p)],
    'currentStrokes': encodeTraceStrokes(_current),
    'currentCheckpoints': List<int>.of(_checkpoints),
    'stamps': [
      for (final stamp in _stamps)
        {
          'point': [
            normalizedTraceCoordinate(stamp.point.dx),
            normalizedTraceCoordinate(stamp.point.dy),
          ],
          'color': stamp.color.toARGB32(),
          'shape': stamp.shape,
        },
    ],
    'strokes': [
      for (final stroke in [..._completed.expand((s) => s), ..._current])
        {
          'color': AppColors.green.toARGB32(),
          'width': 3.5,
          'points': [
            for (final p in stroke)
              [
                normalizedTraceCoordinate(p.dx),
                normalizedTraceCoordinate(p.dy),
              ],
          ],
        },
    ],
  };
  void _save() => config.onChanged(_data());
  Offset _artPoint(Offset point, double side) => Offset(
    (point.dx / side * 400).clamp(0.0, 400.0),
    (point.dy / side * 400).clamp(0.0, 400.0),
  );

  void _start(Offset point, double side, int pointer) {
    if (!_assetLoaded ||
        _decorating ||
        _tapGuide ||
        _sent ||
        _activePointer != null ||
        _current.length >= 80 ||
        _strokeCount >= ArtworkLimits.maxBrushStrokes ||
        _pointCount >= ArtworkLimits.maxTotalBrushPoints) {
      return;
    }
    setState(() {
      _activePointer = pointer;
      _current.add([_artPoint(point, side)]);
    });
  }

  void _move(Offset point, double side, int pointer) {
    if (_activePointer != pointer || _current.isEmpty || _decorating) return;
    final stroke = _current.last,
        next = _artPoint(point, side),
        previous = stroke.last;
    final distance = (next - previous).distance;
    if (distance < 2 ||
        stroke.length >= ArtworkLimits.maxPointsPerStroke ||
        _pointCount >= ArtworkLimits.maxTotalBrushPoints) {
      return;
    }
    if (distance > 65) {
      _end(pointer);
      return;
    }
    final count = math.max(1, (distance / 7).ceil());
    final available = math.min(
      ArtworkLimits.maxPointsPerStroke - stroke.length,
      ArtworkLimits.maxTotalBrushPoints - _pointCount,
    );
    setState(() {
      for (var i = 1; i <= count && i <= available; i++) {
        stroke.add(Offset.lerp(previous, next, i / count)!);
      }
    });
  }

  void _end(int pointer) {
    if (_activePointer != pointer || _decorating) return;
    _activePointer = null;
    _current.removeWhere((s) => s.length < 2);
    for (var i = 0; i < _current.length; i++) {
      _current[i] = simplifyTraceStroke(_current[i]);
    }
    final evaluation = _validators[_completed.length].evaluate(_current);
    setState(() {
      _coverage = evaluation.coverage;
      if (evaluation.complete) _advance('trace');
    });
    if (evaluation.complete) config.onFeedback();
    _save();
  }

  void _advance(String mode) {
    _completed.add([for (final s in _current) List<Offset>.of(s)]);
    _completedModes.add(mode);
    _completedProofs.add(List<int>.of(_checkpoints));
    _current.clear();
    _checkpoints.clear();
    _coverage = 0;
    _guide.value = 0;
    _setMotion();
  }

  void _rebuildCheckpointStroke() {
    _current.clear();
    if (_checkpoints.length < 2) return;
    _current.add(
      sampleTracePath(
        _action.path,
        endFraction: (_checkpoints.length - 1) / (_action.checkpointCount - 1),
      ),
    );
  }

  void _tap(Offset point, double side) {
    if (_sent || !_assetLoaded) return;
    final position = _artPoint(point, side);
    if (_decorating) {
      if (_stamps.length >= 48) return;
      setState(
        () =>
            _stamps.add(_Stamp(position, _colors[_selectedColor], _stampShape)),
      );
      config.onFeedback();
      _save();
      return;
    }
    if (!_tapGuide) return;
    final targets = _action.checkpointsForCanvas(side);
    final next = _checkpoints.length;
    if (next >= targets.length ||
        (targets[next] - position).distance > math.max(25 * 400 / side, 25)) {
      return;
    }
    setState(() {
      _checkpoints.add(next);
      _coverage = _checkpoints.length / targets.length;
      _rebuildCheckpointStroke();
      if (_checkpoints.length == targets.length) _advance('checkpoints');
    });
    config.onFeedback();
    _save();
  }

  void _undo() {
    if (_sent) return;
    setState(() {
      if (_decorating && _stamps.isNotEmpty) {
        _stamps.removeLast();
        return;
      }
      if (_checkpoints.isNotEmpty) {
        _checkpoints.removeLast();
        _rebuildCheckpointStroke();
      } else if (_current.isNotEmpty) {
        _current.removeLast();
      } else if (_completed.isNotEmpty) {
        _stamps.clear();
        _current.addAll(_completed.removeLast());
        final mode = _completedModes.removeLast();
        _checkpoints.addAll(_completedProofs.removeLast());
        _tapGuide = mode == 'checkpoints';
        if (_tapGuide) {
          if (_checkpoints.isNotEmpty) _checkpoints.removeLast();
          _rebuildCheckpointStroke();
        } else if (_current.isNotEmpty) {
          _current.removeLast();
        }
      }
      _coverage = _decorating
          ? 0
          : _tapGuide
          ? _checkpoints.length / _action.checkpointCount
          : _validators[_completed.length].evaluate(_current).coverage;
    });
    _save();
  }

  Future<void> _reset() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t(
            'Начнём рисунок заново?',
            'Суретті қайта бастаймыз ба?',
            'Start this drawing again?',
          ),
        ),
        content: Text(
          _t(
            'Линии и украшения этого рисунка очистятся.',
            'Бұл суреттің сызықтары мен әшекейлері өшіріледі.',
            'The lines and decorations in this drawing will be cleared.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Оставить', 'Қалдыру', 'Keep drawing')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Заново', 'Қайта бастау', 'Start again')),
          ),
        ],
      ),
    );
    if (answer != true || !mounted) return;
    setState(() {
      _completed.clear();
      _completedModes.clear();
      _completedProofs.clear();
      _current.clear();
      _checkpoints.clear();
      _stamps.clear();
      _coverage = 0;
      _sent = false;
      _activePointer = null;
    });
    _save();
  }

  void _switchGuide() {
    setState(() {
      _tapGuide = !_tapGuide;
      _current.clear();
      _checkpoints.clear();
      _coverage = 0;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape =
          constraints.maxWidth > constraints.maxHeight &&
          constraints.maxHeight < 500;
      final compact = constraints.maxHeight < 500;
      final board = Expanded(
        child: Center(
          child: LayoutBuilder(
            builder: (context, space) {
              final side = math.min(space.maxWidth, space.maxHeight);
              return SizedBox.square(
                dimension: side,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Semantics(
                    label: _t(
                      'Поле для рисования',
                      'Сурет салу алаңы',
                      'Drawing canvas',
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tap(d.localPosition, side),
                      child: Listener(
                        key: const ValueKey('drawing-canvas'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) =>
                            _start(e.localPosition, side, e.pointer),
                        onPointerMove: (e) =>
                            _move(e.localPosition, side, e.pointer),
                        onPointerUp: (e) => _end(e.pointer),
                        onPointerCancel: (e) => _end(e.pointer),
                        child: AnimatedBuilder(
                          animation: _guide,
                          builder: (context, _) => Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: AppColors.paper,
                                child: Opacity(
                                  opacity: _decorating
                                      ? 1
                                      : .28 +
                                            .38 *
                                                _completed.length /
                                                _layout.actions.length,
                                  child: Image.asset(
                                    config.level.illustrationAsset ??
                                        _layout.asset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: AppColors.paper,
                                    ),
                                  ),
                                ),
                              ),
                              CustomPaint(
                                painter: _LessonPainter(
                                  layout: _layout,
                                  step: _decorating
                                      ? _layout.actions.length
                                      : _completed.length,
                                  completed: _completed,
                                  current: _current,
                                  checkpoints: _checkpoints,
                                  tapGuide: _tapGuide,
                                  guide: _guide.value,
                                  hint: config.showHint,
                                  stamps: _stamps,
                                  side: side,
                                ),
                              ),
                              if (!_assetLoaded)
                                Positioned.fill(
                                  child: ColoredBox(
                                    color: AppColors.paper,
                                    child: Center(
                                      child: _assetFailed
                                          ? Text(
                                              _t(
                                                'Не удалось открыть рисунок. Вернись и попробуй ещё раз.',
                                                'Сурет ашылмады. Артқа қайтып, қайта көр.',
                                                'The picture could not open. Go back and try again.',
                                              ),
                                            )
                                          : const CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      if (landscape) {
        return Row(
          children: [
            board,
            const SizedBox(width: 12),
            SizedBox(
              width: 224,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _status(compact: false),
                          _progress(),
                          if (_decorating) _palette(),
                        ],
                      ),
                    ),
                  ),
                  _actions(side: true),
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          _status(compact: compact),
          _progress(),
          SizedBox(height: compact ? 6 : 12),
          Expanded(
            child: Row(
              children: [
                board,
                if (constraints.maxWidth >= 650 && _decorating)
                  SizedBox(width: 104, child: _palette()),
              ],
            ),
          ),
          if (constraints.maxWidth < 650 && _decorating) _palette(),
          _actions(compact: compact),
        ],
      );
    },
  );

  Widget _status({required bool compact}) => Padding(
    padding: EdgeInsets.fromLTRB(8, compact ? 0 : 4, 8, compact ? 4 : 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _decorating ? Icons.auto_awesome_rounded : Icons.gesture_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _decorating
                    ? _t(
                        'Твой рисунок ожил!',
                        'Суретің жанданды!',
                        'Your drawing came to life!',
                      )
                    : _action.title.resolve(config.language),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!compact)
                Text(
                  _decorating
                      ? _t(
                          'Добавь звёздочки или нажми «Готово».',
                          'Жұлдызша қос немесе «Дайын» түймесін бас.',
                          'Add some stars, or tap All done.',
                        )
                      : _tapGuide
                      ? _t(
                          'Нажимай на светящийся кружок. Все точки идут по порядку.',
                          'Жанып тұрған шеңберді ретімен бас.',
                          'Tap the glowing circle. Visit every point in order.',
                        )
                      : _action.instruction.resolve(config.language),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (!_decorating && config.onSpeak != null)
          IconButton(
            tooltip: _t(
              'Послушать шаг',
              'Қадамды тыңдау',
              'Listen to this step',
            ),
            onPressed: () => config.onSpeak?.call(
              _tapGuide
                  ? '${_action.title.resolve(config.language)}. ${_t('Нажимай на светящийся кружок. Все точки идут по порядку.', 'Жанып тұрған шеңберді ретімен бас.', 'Tap the glowing circle. Visit every point in order.')}'
                  : _action.instruction.resolve(config.language),
            ),
            icon: const Icon(Icons.volume_up_outlined),
          ),
      ],
    ),
  );
  Widget _progress() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        for (var i = 0; i < _layout.actions.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: _creativeReplay
                      ? 1
                      : i < _completed.length
                      ? 1
                      : i == _completed.length
                      ? _coverage
                      : 0,
                  backgroundColor: AppColors.line,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _actions({bool side = false, bool compact = false}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 2 : 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: _t('Отменить', 'Болдырмау', 'Undo'),
              onPressed:
                  _completed.isEmpty &&
                      _current.isEmpty &&
                      _checkpoints.isEmpty &&
                      _stamps.isEmpty
                  ? null
                  : _undo,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: _t('Начать заново', 'Қайта бастау', 'Start again'),
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            if (config.ageBand == AgeBand.preschool && !_decorating)
              IconButton(
                key: const ValueKey('drawing-guide-toggle'),
                tooltip: _tapGuide
                    ? _t(
                        'Рисовать пальчиком',
                        'Саусақпен салу',
                        'Draw with your finger',
                      )
                    : _t(
                        'Помощник по точкам',
                        'Нүктелер көмекшісі',
                        'Tap guide',
                      ),
                onPressed: _switchGuide,
                icon: Icon(
                  _tapGuide ? Icons.gesture_rounded : Icons.touch_app_rounded,
                ),
              ),
            if (!side) const Spacer(),
            if (_decorating)
              IconButton(
                tooltip: _t(
                  'Выбрать украшение',
                  'Әшекейді таңдау',
                  'Choose a decoration',
                ),
                onPressed: () =>
                    setState(() => _stampShape = (_stampShape + 1) % 3),
                icon: Icon(
                  [
                    Icons.star_rounded,
                    Icons.favorite_rounded,
                    Icons.circle,
                  ][_stampShape],
                ),
              ),
            if (!side && _decorating) _finish(),
          ],
        ),
        if (side && _decorating) _finish(),
      ],
    ),
  );
  Widget _finish() => FilledButton.icon(
    key: const ValueKey('drawing-finish'),
    onPressed: _sent || !_assetLoaded || !_canFinish
        ? null
        : () {
            if (_sent || !_assetLoaded || !_canFinish) return;
            setState(() => _sent = true);
            config.onCompleted(_data());
          },
    icon: const Icon(Icons.check_rounded),
    label: Text(_t('Готово!', 'Дайын!', 'All done!')),
  );
  Widget _palette() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < _colors.length; i++)
          Semantics(
            button: true,
            selected: i == _selectedColor,
            label: _t('Цвет ${i + 1}', '${i + 1}-түс', 'Color ${i + 1}'),
            child: InkResponse(
              onTap: () => setState(() => _selectedColor = i),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _selectedColor
                            ? AppColors.ink
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Stamp {
  const _Stamp(this.point, this.color, this.shape);
  final Offset point;
  final Color color;
  final int shape;
}

class _LessonPainter extends CustomPainter {
  _LessonPainter({
    required this.layout,
    required this.step,
    required this.completed,
    required this.current,
    required this.checkpoints,
    required this.tapGuide,
    required this.guide,
    required this.hint,
    required this.stamps,
    required this.side,
  });
  final GuidedDrawingLayout layout;
  final int step;
  final List<List<List<Offset>>> completed;
  final List<List<Offset>> current;
  final List<int> checkpoints;
  final bool tapGuide;
  final double guide;
  final bool hint;
  final List<_Stamp> stamps;
  final double side;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 400);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 400, 400));
    final pencil = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stage in completed) {
      for (final stroke in stage) {
        _stroke(canvas, stroke, pencil);
      }
    }
    if (step < layout.actions.length) {
      final action = layout.actions[step], path = action.path;
      if (hint) {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.lime.withValues(alpha: .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 24
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 13) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 7, metric.length)),
            Paint()
              ..color = AppColors.green.withValues(alpha: .8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      for (final stroke in current) {
        _stroke(canvas, stroke, pencil);
      }
      final points = tapGuide
          ? action.checkpointsForCanvas(side)
          : action.checkpoints;
      if (tapGuide && checkpoints.length < points.length) {
        final point = points[checkpoints.length], radius = 12 * 400 / side;
        canvas.drawCircle(
          point,
          radius * 1.7,
          Paint()..color = AppColors.yellow.withValues(alpha: .5),
        );
        canvas.drawCircle(point, radius, Paint()..color = AppColors.green);
        canvas.drawCircle(point, radius * .45, Paint()..color = Colors.white);
        _label(
          canvas,
          point + Offset(0, -radius * 2.1),
          '${checkpoints.length + 1}',
          15 * 400 / side,
        );
      } else {
        final samples = sampleTracePath(path);
        if (samples.isNotEmpty) {
          final p = samples[(guide * (samples.length - 1)).floor()];
          canvas.drawCircle(p, 7, Paint()..color = AppColors.peach);
          canvas.drawCircle(p, 3, Paint()..color = Colors.white);
        }
        canvas.drawCircle(points.first, 5, Paint()..color = AppColors.green);
      }
    }
    for (final stamp in stamps) {
      final paint = Paint()..color = stamp.color;
      if (stamp.shape == 2) {
        canvas.drawCircle(stamp.point, 10, paint);
        continue;
      }
      final p = Path();
      if (stamp.shape == 1) {
        p.moveTo(stamp.point.dx, stamp.point.dy + 11);
        p.cubicTo(
          stamp.point.dx - 22,
          stamp.point.dy - 3,
          stamp.point.dx - 11,
          stamp.point.dy - 17,
          stamp.point.dx,
          stamp.point.dy - 8,
        );
        p.cubicTo(
          stamp.point.dx + 11,
          stamp.point.dy - 17,
          stamp.point.dx + 22,
          stamp.point.dy - 3,
          stamp.point.dx,
          stamp.point.dy + 11,
        );
      } else {
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? 13.0 : 6.0;
          final point =
              stamp.point + Offset(math.cos(angle) * r, math.sin(angle) * r);
          if (i == 0) {
            p.moveTo(point.dx, point.dy);
          } else {
            p.lineTo(point.dx, point.dy);
          }
        }
        p.close();
      }
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }

  void _stroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (final v in points.skip(1)) {
      p.lineTo(v.dx, v.dy);
    }
    canvas.drawPath(p, paint);
  }

  void _label(Canvas canvas, Offset center, String text, double fontSize) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, center - Offset(p.width / 2, p.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LessonPainter oldDelegate) => true;
}
