import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/artwork_limits.dart';
import '../../shared/art/art_scene.dart';
import 'activity_config.dart';
import 'raster_color_activity.dart';

enum _Tool { fill, brush, eraser }

/// The album uses the exact same renderer, including clipping and erasing.
class ColorArtworkPreview extends StatelessWidget {
  const ColorArtworkPreview({
    super.key,
    required this.level,
    required this.data,
  });
  final LevelDefinition level;
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    if (level.illustrationAsset != null) {
      return RasterColorArtworkPreview(level: level, data: data);
    }
    final scene = SceneFactory.create(
      level.scene,
      variant: level.variant,
      segmented: level.kind == ActivityKind.numberColor,
    );
    final ids = scene.regions.map((r) => r.id).toSet();
    final rawFills = data['fills'];
    final fills = <String, Color>{};
    if (rawFills is Map) {
      for (final entry in rawFills.entries) {
        if (entry.key is String &&
            ids.contains(entry.key) &&
            entry.value is int) {
          fills[entry.key as String] = Color(entry.value as int);
        }
      }
    }
    final rawStrokes = data['strokes'];
    final strokes = rawStrokes is List
        ? rawStrokes
              .take(ArtworkLimits.maxBrushStrokes)
              .map(_Stroke.fromJson)
              .whereType<_Stroke>()
              .where((s) => s.regionId == null || ids.contains(s.regionId))
              .toList()
        : <_Stroke>[];
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _ColorCanvasPainter(
          scene: scene,
          fills: fills,
          strokes: strokes,
          numberMode: false,
        ),
      ),
    );
  }
}

/// Coloring with closed regions and a separate, region-clipped brush layer.
class ColorActivity extends StatelessWidget {
  const ColorActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  Widget build(BuildContext context) => config.level.illustrationAsset == null
      ? _LegacyColorActivity(config: config)
      : RasterColorActivity(config: config);
}

class _LegacyColorActivity extends StatefulWidget {
  const _LegacyColorActivity({required this.config});
  final ActivityConfig config;
  @override
  State<_LegacyColorActivity> createState() => _ColorActivityState();
}

class _ColorActivityState extends State<_LegacyColorActivity>
    with WidgetsBindingObserver {
  static const _palette = <Color>[
    Color(0xFFEA7563),
    Color(0xFFF3AA69),
    Color(0xFFF5D66B),
    Color(0xFF90BC77),
    Color(0xFF439282),
    Color(0xFF6EBBDA),
    Color(0xFF5375BD),
    Color(0xFF9F83CC),
    Color(0xFFE49FBC),
    Color(0xFFB18565),
    Color(0xFF455B63),
    Color(0xFFFFFFFF),
  ];
  late ArtScene _scene;
  Map<String, Color> _fills = {};
  List<_Stroke> _strokes = [];
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];
  _Tool _tool = _Tool.fill;
  Color _selected = _palette.first;
  double _width = 12;
  _Stroke? _active;
  String? _message;
  bool _completed = false;
  int _inkCells = 0;
  int get _pointCount =>
      _strokes.fold(0, (sum, stroke) => sum + stroke.points.length);
  ActivityConfig get _config => widget.config;
  bool get _numberMode => _config.level.kind == ActivityKind.numberColor;
  String _t(String ru, String kk, String en) =>
      textFor(_config.language, ru, kk, en);
  List<Color> get _numberColors => _scene.regions
      .map((r) => _scene.numberPalette[r.number]!)
      .toSet()
      .toList();
  int get _correct => _scene.regions
      .where((r) => _fills[r.id] == _scene.numberPalette[r.number])
      .length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _end();
    }
  }

  @override
  void didUpdateWidget(_LegacyColorActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != _config.level.id) _load();
  }

  void _load() {
    _scene = SceneFactory.create(
      _config.level.scene,
      variant: _config.level.variant,
      segmented: _numberMode,
    );
    if (_numberMode) _scene = _scene.withSemanticNumbers();
    _fills = {};
    _strokes = [];
    _undo.clear();
    _redo.clear();
    _completed = false;
    _inkCells = 0;
    _message = null;
    _active = null;
    _tool = _Tool.fill;
    _selected = _numberMode ? _numberColors.first : _palette.first;
    final saved = _config.initialData;
    if (saved == null) return;
    final validIds = _scene.regions.map((r) => r.id).toSet();
    final savedFills = saved['fills'];
    if (savedFills is Map) {
      for (final entry in savedFills.entries) {
        if (entry.key is String &&
            validIds.contains(entry.key) &&
            entry.value is int) {
          final color = Color(entry.value as int);
          final region = _scene.regions.firstWhere((r) => r.id == entry.key);
          final legacyFill =
              _numberMode &&
              saved['semanticNumbers'] != true &&
              numberPalette.values.contains(color);
          if (!_numberMode ||
              color == _scene.numberPalette[region.number] ||
              legacyFill) {
            _fills[entry.key as String] = _numberMode
                ? _scene.numberPalette[region.number]!
                : color;
          }
        }
      }
    }
    if (!_numberMode && saved['strokes'] is List) {
      for (final raw in (saved['strokes'] as List).take(
        ArtworkLimits.maxBrushStrokes,
      )) {
        final stroke = _Stroke.fromJson(raw);
        if (stroke == null ||
            (stroke.regionId != null && !validIds.contains(stroke.regionId))) {
          continue;
        }
        _strokes.add(stroke);
      }
    }
    if (saved['selectedColor'] is int) {
      _selected = Color(saved['selectedColor'] as int);
    }
    if (_numberMode && !_numberColors.contains(_selected)) {
      _selected = _numberColors.first;
    }
    if (!_numberMode) {
      _tool = _Tool.values.firstWhere(
        (t) => t.name == saved['tool'],
        orElse: () => _Tool.fill,
      );
      final width = saved['brushWidth'];
      if (width is num && width.isFinite) {
        _width = width.toDouble().clamp(4, 24);
      }
    }
    _compactStrokes();
    _measureVisibleInk();
  }

  bool get _canFinish {
    if (_numberMode) return _correct == _scene.regions.length;
    final colored = _fills.values
        .where((c) => c.a > 0 && c.toARGB32() != 0xFFFFFFFF)
        .length;
    return colored >= 3 || _inkCells >= 8 || (colored >= 1 && _inkCells >= 4);
  }

  Map<String, dynamic> _data() => {
    'version': 1,
    'kind': 'color',
    'scene': _config.level.scene,
    'variant': _config.level.variant,
    'segmented': _numberMode,
    'semanticNumbers': _numberMode,
    'fills': {
      for (final entry in _fills.entries) entry.key: entry.value.toARGB32(),
    },
    'strokes': _strokes.map((s) => s.toJson()).toList(),
    'tool': _tool.name,
    'selectedColor': _selected.toARGB32(),
    'brushWidth': _width,
  };
  void _record() {
    _undo.add(_Snapshot(Map.of(_fills), List.of(_strokes)));
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  void _save() {
    _compactStrokes();
    _measureVisibleInk();
    _config.onChanged(_data());
  }

  List<Offset> _simplify(List<Offset> points, int cap) {
    if (points.length <= cap) return points;
    return List.generate(
      cap,
      (i) => points[(i * (points.length - 1) / (cap - 1)).round()],
    );
  }

  void _compactStrokes() {
    while (_pointCount > ArtworkLimits.maxTotalBrushPoints) {
      final before = _pointCount;
      _strokes = _strokes
          .map(
            (stroke) => stroke.copyWithPoints(
              _simplify(
                stroke.points,
                math.max(2, (stroke.points.length * .8).floor()),
              ),
            ),
          )
          .toList();
      if (_pointCount == before) break;
    }
  }

  // A bounded occupancy sketch of the brush layer. Erasing all visible paint
  // disables Done again, rather than counting historic, now invisible strokes.
  void _measureVisibleInk() {
    final ink = <int>{};
    const grid = 64;
    final paths = {for (final r in _scene.regions) r.id: r.path};
    for (final stroke in _strokes) {
      final radius = stroke.width / _scene.viewBox.width * grid / 2;
      final clip = paths[stroke.regionId];
      final paints =
          !stroke.eraser &&
          stroke.color.a > 0 &&
          stroke.color.toARGB32() != 0xFFFFFFFF;
      void stamp(Offset p) {
        final cx = p.dx * grid, cy = p.dy * grid;
        for (var x = (cx - radius).floor(); x <= (cx + radius).ceil(); x++) {
          for (var y = (cy - radius).floor(); y <= (cy + radius).ceil(); y++) {
            if (x < 0 || x >= grid || y < 0 || y >= grid) continue;
            if (Offset(x + .5 - cx, y + .5 - cy).distance > radius + .25) {
              continue;
            }
            if (clip != null &&
                !clip.contains(
                  Offset(
                    (x + .5) / grid * _scene.viewBox.width,
                    (y + .5) / grid * _scene.viewBox.height,
                  ),
                )) {
              continue;
            }
            final cell = y * grid + x;
            if (paints) {
              ink.add(cell);
            } else {
              ink.remove(cell);
            }
          }
        }
      }

      stamp(stroke.points.first);
      for (var i = 1; i < stroke.points.length; i++) {
        final a = stroke.points[i - 1], b = stroke.points[i];
        final samples = math.max(1, ((b - a).distance * grid * 2).ceil());
        for (var step = 1; step <= samples; step++) {
          stamp(Offset.lerp(a, b, step / samples)!);
        }
      }
    }
    _inkCells = ink.length;
  }

  void _history(bool redo) {
    if (_active != null) return;
    final source = redo ? _redo : _undo, target = redo ? _undo : _redo;
    if (source.isEmpty) return;
    final snapshot = source.removeLast();
    setState(() {
      target.add(_Snapshot(Map.of(_fills), List.of(_strokes)));
      _fills = Map.of(snapshot.fills);
      _strokes = List.of(snapshot.strokes);
      _message = null;
    });
    _save();
  }

  Offset _unit(Offset p, double side) =>
      Offset((p.dx / side).clamp(0.0, 1.0), (p.dy / side).clamp(0.0, 1.0));
  ArtRegion? _regionAt(Offset p) {
    final point = Offset(
      p.dx * _scene.viewBox.width,
      p.dy * _scene.viewBox.height,
    );
    for (final region in _scene.regions.reversed) {
      if (region.path.contains(point)) return region;
    }
    return null;
  }

  ArtRegion? _numberRegionAt(Offset unit, double side) {
    final exact = _regionAt(unit);
    final point = Offset(
      unit.dx * _scene.viewBox.width,
      unit.dy * _scene.viewBox.height,
    );
    final scale = side / _scene.viewBox.width;
    if (exact != null &&
        !_fills.containsKey(exact.id) &&
        _scene.numberPalette[exact.number] == _selected) {
      final bounds = exact.path.getBounds();
      if (math.min(bounds.width, bounds.height) * scale <= 44 ||
          (exact.labelPoint - point).distance * scale <= 3) {
        return exact;
      }
    }
    final nearby = <(ArtRegion, double, double)>[];
    for (final region in _scene.regions) {
      if (_fills.containsKey(region.id) ||
          _scene.numberPalette[region.number] != _selected) {
        continue;
      }
      final bounds = region.path.getBounds();
      final small = math.min(bounds.width, bounds.height) * scale <= 44;
      if (!small || !bounds.inflate(18 / scale).contains(point)) continue;
      var distance = region.path.contains(point) ? 0.0 : double.infinity;
      for (final metric in region.path.computeMetrics()) {
        for (var offset = 0.0; offset <= metric.length; offset += 4) {
          final tangent = metric.getTangentForOffset(offset);
          if (tangent != null) {
            distance = math.min(
              distance,
              (point - tangent.position).distance * scale,
            );
          }
        }
      }
      if (distance <= 18) {
        nearby.add((region, distance, bounds.width * bounds.height));
      }
    }
    nearby.sort((a, b) {
      final near = a.$2.compareTo(b.$2);
      if ((a.$2 - b.$2).abs() > 6) return near;
      return a.$3.compareTo(b.$3);
    });
    if (nearby.isNotEmpty) {
      return nearby.first.$1;
    }
    return exact;
  }

  void _tap(Offset local, double side) {
    if (_completed) return;
    final point = _unit(local, side);
    final region = _numberMode
        ? _numberRegionAt(point, side)
        : _regionAt(point);
    if (_tool == _Tool.brush && !_numberMode) {
      if (_strokes.length >= ArtworkLimits.maxBrushStrokes) return;
      _record();
      setState(
        () => _strokes = [
          ..._strokes,
          _Stroke(
            points: [point],
            color: _selected,
            width: _width,
            regionId: region?.id,
          ),
        ],
      );
      _save();
      return;
    }
    if (region == null) return;
    if (_numberMode && _selected != _scene.numberPalette[region.number]) {
      setState(
        () => _message = _t(
          'Найди цвет для числа ${region.number}. У тебя получится!',
          '${region.number} санының түсін тап. Қолыңнан келеді!',
          'Find the color for ${region.number}. You can do it!',
        ),
      );
      return;
    }
    if (_tool == _Tool.eraser) {
      if (!_fills.containsKey(region.id)) return;
      _record();
      setState(() {
        _fills.remove(region.id);
        _message = null;
      });
    } else {
      if (_fills[region.id] == _selected) return;
      _record();
      setState(() {
        _fills[region.id] = _selected;
        _message = _numberMode
            ? _t(
                'Отлично! Ещё одна часть готова.',
                'Керемет! Тағы бір бөлік дайын.',
                'Lovely! One more piece in place.',
              )
            : null;
      });
      _config.onFeedback();
    }
    _save();
  }

  void _start(Offset local, double side) {
    if (_numberMode ||
        _tool == _Tool.fill ||
        _completed ||
        _strokes.length >= ArtworkLimits.maxBrushStrokes) {
      return;
    }
    final point = _unit(local, side);
    setState(
      () => _active = _Stroke(
        points: [point],
        color: _selected,
        width: _width,
        eraser: _tool == _Tool.eraser,
        regionId: _regionAt(point)?.id,
      ),
    );
  }

  void _move(Offset local, double side) {
    final active = _active;
    if (active == null) return;
    final point = _unit(local, side);
    if ((point - active.points.last).distance < .002) return;
    final points = [...active.points, point];
    setState(
      () => _active = active.copyWithPoints(
        points.length > ArtworkLimits.maxPointsPerStroke
            ? _simplify(points, ArtworkLimits.maxPointsPerStroke ~/ 2)
            : points,
      ),
    );
  }

  void _end() {
    if (_active == null) return;
    _record();
    setState(() {
      _strokes = [..._strokes, _active!];
      _active = null;
    });
    _save();
  }

  void _cancel() {
    if (_active == null) return;
    setState(() {
      _active = null;
    });
  }

  Future<void> _clear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t('Начать заново?', 'Қайта бастаймыз ба?', 'Start again?'),
        ),
        content: Text(
          _t(
            'Очистку можно отменить стрелкой назад.',
            'Тазалауды кері көрсеткімен қайтаруға болады.',
            'You can undo clearing with the back arrow.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Оставить', 'Қалдыру', 'Keep it')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Очистить', 'Тазалау', 'Clear')),
          ),
        ],
      ),
    );
    if (clear != true || !mounted) return;
    _record();
    setState(() {
      _fills.clear();
      _strokes.clear();
      _message = null;
    });
    _save();
  }

  void _finish() {
    if (!_canFinish || _completed) return;
    _completed = true;
    _config.onCompleted(_data());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      final status = _numberMode
          ? _t(
              '$_correct из ${_scene.regions.length} частей',
              '$_correct / ${_scene.regions.length} бөлік',
              '$_correct of ${_scene.regions.length} pieces',
            )
          : _t(
              'Твоя фантазия — твои цвета',
              'Өз қиялың — өз түстерің',
              'Your imagination, your colors',
            );
      final message =
          _message ??
          (_config.showHint
              ? _t(
                  'Выбери цвет и коснись подходящей части рисунка.',
                  'Түсті таңдап, суреттің сәйкес бөлігін түрт.',
                  'Choose a color, then tap a matching piece.',
                )
              : _numberMode
              ? _t(
                  'Цвет подсказывает число на рисунке',
                  'Суреттегі сан түсті көрсетеді',
                  'The number tells you which color to use',
                )
              : _t(
                  'Заливай цветом или рисуй кистью',
                  'Түспен боя немесе қылқаламмен сал',
                  'Tap to fill or paint with a brush',
                ));
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_numberMode)
                  SizedBox(
                    width: 72,
                    child: LinearProgressIndicator(
                      value: _scene.regions.isEmpty
                          ? 0
                          : _correct / _scene.regions.length,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(9),
                      backgroundColor: AppColors.line,
                      color: AppColors.green,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _canvas()),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 230,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: _controls(message),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _finishButton(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _canvas()),
                      const SizedBox(height: 8),
                      _compactControls(message),
                    ],
                  ),
          ),
        ],
      );
    },
  );
  Widget _compactControls(String message) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_numberMode)
        SizedBox(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _numberColors.map(_swatch).toList()),
          ),
        ),
      if (_config.showHint || _message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      Row(
        children: [
          IconButton(
            onPressed: _undo.isEmpty ? null : () => _history(false),
            icon: const Icon(Icons.undo_rounded),
            tooltip: _t('Отменить', 'Болдырмау', 'Undo'),
          ),
          IconButton(
            onPressed: _redo.isEmpty ? null : () => _history(true),
            icon: const Icon(Icons.redo_rounded),
            tooltip: _t('Повторить', 'Қайталау', 'Redo'),
          ),
          if (!_numberMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                key: const ValueKey('color-tools'),
                onPressed: _showTools,
                tooltip: _t(
                  'Краски и инструменты',
                  'Түстер мен құралдар',
                  'Colors and tools',
                ),
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.circle, color: _selected, size: 32),
                    Icon(
                      _tool == _Tool.fill
                          ? Icons.format_color_fill_rounded
                          : _tool == _Tool.brush
                          ? Icons.brush_rounded
                          : Icons.auto_fix_normal_rounded,
                      size: 18,
                      color: _selected.computeLuminance() > .42
                          ? AppColors.ink
                          : Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('color-finish'),
              onPressed: _canFinish ? _finish : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(_t('Готово', 'Дайын', 'Done')),
            ),
          ),
        ],
      ),
    ],
  );
  Future<void> _showTools() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, refresh) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('Твоя мастерская', 'Сенің шеберханаң', 'Your art studio'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: _palette
                      .map(
                        (color) =>
                            _swatch(color, afterSelect: () => refresh(() {})),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _toolButton(
                      _Tool.fill,
                      Icons.format_color_fill_rounded,
                      _t('Заливка', 'Бояу', 'Fill'),
                      afterSelect: () => refresh(() {}),
                    ),
                    _toolButton(
                      _Tool.brush,
                      Icons.brush_rounded,
                      _t('Кисть', 'Қылқалам', 'Brush'),
                      afterSelect: () => refresh(() {}),
                    ),
                    _toolButton(
                      _Tool.eraser,
                      Icons.auto_fix_normal_rounded,
                      _t('Ластик', 'Өшіргіш', 'Eraser'),
                      afterSelect: () => refresh(() {}),
                    ),
                  ],
                ),
                if (_tool != _Tool.fill)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [6.0, 12.0, 22.0]
                        .map(
                          (width) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: IconButton.filledTonal(
                              tooltip: _t(
                                'Толщина кисти',
                                'Қылқалам қалыңдығы',
                                'Brush size',
                              ),
                              isSelected: _width == width,
                              onPressed: () {
                                setState(() => _width = width);
                                refresh(() {});
                              },
                              icon: Icon(Icons.circle, size: width),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: _fills.isEmpty && _strokes.isEmpty
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _clear();
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: _t('Очистить', 'Тазалау', 'Clear'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(_t('Рисовать', 'Сурет салу', 'Let’s draw')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _canvas() => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08615238),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Semantics(
              label: _t(
                'Холст для раскрашивания',
                'Бояуға арналған кенеп',
                'Coloring canvas',
              ),
              child: GestureDetector(
                key: const ValueKey('color-canvas'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _tap(details.localPosition, side),
                onPanStart: (details) => _start(details.localPosition, side),
                onPanUpdate: (details) => _move(details.localPosition, side),
                onPanEnd: (_) => _end(),
                onPanCancel: _cancel,
                child: CustomPaint(
                  painter: _ColorCanvasPainter(
                    scene: _scene,
                    fills: Map.of(_fills),
                    strokes: [..._strokes, ?_active],
                    numberMode: _numberMode,
                    hintColor: _config.showHint && _numberMode
                        ? _selected
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _controls(String message) {
    final palette = _numberMode ? _numberColors : _palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_numberMode)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _toolButton(
                _Tool.fill,
                Icons.format_color_fill_rounded,
                _t('Заливка', 'Бояу', 'Fill'),
              ),
              _toolButton(
                _Tool.brush,
                Icons.brush_rounded,
                _t('Кисть', 'Қылқалам', 'Brush'),
              ),
              _toolButton(
                _Tool.eraser,
                Icons.auto_fix_normal_rounded,
                _t('Ластик', 'Өшіргіш', 'Eraser'),
              ),
              if (_tool != _Tool.fill)
                PopupMenuButton<double>(
                  tooltip: _t(
                    'Толщина кисти',
                    'Қылқалам қалыңдығы',
                    'Brush size',
                  ),
                  initialValue: _width,
                  icon: Icon(Icons.circle, size: _width),
                  onSelected: (width) => setState(() => _width = width),
                  itemBuilder: (_) => [6.0, 12.0, 22.0]
                      .map(
                        (width) => PopupMenuItem(
                          value: width,
                          child: SizedBox(
                            width: 120,
                            height: 32,
                            child: Center(
                              child: Container(
                                width: 100,
                                height: width,
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          children: palette.map(_swatch).toList(),
        ),
        if (_message != null || _config.showHint)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.25,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _undo.isEmpty ? null : () => _history(false),
                icon: const Icon(Icons.undo_rounded),
                tooltip: _t('Отменить', 'Болдырмау', 'Undo'),
              ),
              IconButton(
                onPressed: _redo.isEmpty ? null : () => _history(true),
                icon: const Icon(Icons.redo_rounded),
                tooltip: _t('Повторить', 'Қайталау', 'Redo'),
              ),
              if (!_numberMode)
                IconButton(
                  onPressed: (_fills.isEmpty && _strokes.isEmpty)
                      ? null
                      : _clear,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: _t('Очистить', 'Тазалау', 'Clear'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _finishButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: const ValueKey('color-finish'),
      onPressed: _canFinish ? _finish : null,
      icon: const Icon(Icons.check_rounded, size: 20),
      label: Text(_t('Готово', 'Дайын', 'Done'), maxLines: 1),
    ),
  );

  Widget _toolButton(
    _Tool tool,
    IconData icon,
    String label, {
    VoidCallback? afterSelect,
  }) => Semantics(
    selected: _tool == tool,
    child: Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: _tool == tool ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _tool = tool);
              afterSelect?.call();
            },
            child: SizedBox(
              width: 52,
              height: 48,
              child: Icon(icon, color: AppColors.ink),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _swatch(Color color, {VoidCallback? afterSelect}) {
    final selected = _selected == color;
    final numbers =
        !_numberMode
              ? <int>[]
              : _scene.regions
                    .where((r) => _scene.numberPalette[r.number] == color)
                    .map((r) => r.number)
                    .toSet()
                    .toList()
          ..sort();
    final label = numbers.isEmpty
        ? ''
        : numbers.length == 1
        ? '${numbers.first}'
        : '${numbers.first}–${numbers.last}';
    final contrast = color.computeLuminance() > .42
        ? AppColors.ink
        : Colors.white;
    return Semantics(
      label: _numberMode
          ? _t('Цвет для $label', '$label үшін түс', 'Color for $label')
          : _t(
              'Цвет ${_palette.indexOf(color) + 1}',
              '${_palette.indexOf(color) + 1}-түс',
              'Color ${_palette.indexOf(color) + 1}',
            ),
      selected: selected,
      button: true,
      child: GestureDetector(
        key: ValueKey('color-swatch-${color.toARGB32()}'),
        onTap: () {
          setState(() {
            _selected = color;
            _message = null;
          });
          afterSelect?.call();
        },
        child: SizedBox(
          width: _numberMode && label.length > 2 ? 67 : 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: _config.reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              width: _numberMode && label.length > 2 ? 58 : 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected
                      ? AppColors.ink
                      : (color == Colors.white ? AppColors.line : color),
                  width: selected ? 3 : 1,
                ),
              ),
              child: Center(
                child: _numberMode
                    ? Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: contrast,
                        ),
                      )
                    : selected
                    ? Icon(Icons.check_rounded, size: 22, color: contrast)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Snapshot {
  const _Snapshot(this.fills, this.strokes);
  final Map<String, Color> fills;
  final List<_Stroke> strokes;
}

class _Stroke {
  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
    this.regionId,
  });
  final List<Offset> points;
  final Color color;
  final double width;
  final bool eraser;
  final String? regionId;
  _Stroke copyWithPoints(List<Offset> p) => _Stroke(
    points: p,
    color: color,
    width: width,
    eraser: eraser,
    regionId: regionId,
  );
  Map<String, dynamic> toJson() => {
    'points': points
        .map(
          (p) => [
            double.parse(p.dx.toStringAsFixed(4)),
            double.parse(p.dy.toStringAsFixed(4)),
          ],
        )
        .toList(),
    'color': color.toARGB32(),
    'width': width,
    'eraser': eraser,
    'clipRegionId': regionId,
  };
  static _Stroke? fromJson(dynamic json) {
    if (json is! Map ||
        json['points'] is! List ||
        json['color'] is! int ||
        json['width'] is! num) {
      return null;
    }
    final width = (json['width'] as num).toDouble();
    if (!width.isFinite) return null;
    final points = <Offset>[];
    final source = json['points'] as List;
    final count = math.min(source.length, ArtworkLimits.maxPointsPerStroke);
    for (var i = 0; i < count; i++) {
      final raw =
          source[count == 1
              ? 0
              : (i * (source.length - 1) / (count - 1)).round()];
      if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
        continue;
      }
      final x = (raw[0] as num).toDouble(), y = (raw[1] as num).toDouble();
      if (x.isFinite && y.isFinite) {
        points.add(Offset(x.clamp(0, 1), y.clamp(0, 1)));
      }
    }
    if (points.isEmpty) return null;
    return _Stroke(
      points: points,
      color: Color(json['color'] as int),
      width: width.clamp(4, 24),
      eraser: json['eraser'] == true,
      regionId: json['clipRegionId'] is String
          ? json['clipRegionId'] as String
          : null,
    );
  }
}

class _ColorCanvasPainter extends CustomPainter {
  const _ColorCanvasPainter({
    required this.scene,
    required this.fills,
    required this.strokes,
    required this.numberMode,
    this.hintColor,
  });
  final ArtScene scene;
  final Map<String, Color> fills;
  final List<_Stroke> strokes;
  final bool numberMode;
  final Color? hintColor;
  @override
  void paint(Canvas canvas, Size size) {
    ArtScenePainter(
      scene: scene,
      fills: fills,
      showNumbers: numberMode,
    ).paint(canvas, size);
    canvas.save();
    canvas.scale(
      size.width / scene.viewBox.width,
      size.height / scene.viewBox.height,
    );
    if (strokes.isNotEmpty) {
      canvas.saveLayer(Offset.zero & scene.viewBox, Paint());
      for (final stroke in strokes) {
        canvas.save();
        if (stroke.regionId != null) {
          for (final region in scene.regions) {
            if (region.id == stroke.regionId) {
              canvas.clipPath(region.path);
              break;
            }
          }
        }
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver;
        final points = stroke.points
            .map(
              (p) => Offset(
                p.dx * scene.viewBox.width,
                p.dy * scene.viewBox.height,
              ),
            )
            .toList();
        if (points.length == 1) {
          canvas.drawCircle(
            points.first,
            stroke.width / 2,
            paint..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, paint);
        }
        canvas.restore();
      }
      canvas.restore();
      final outline = Paint()
        ..color = AppColors.ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      var covered = Path();
      for (final region in scene.regions.reversed) {
        canvas.save();
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(Offset.zero & scene.viewBox),
            covered,
          ),
        );
        canvas.drawPath(region.path, outline);
        canvas.restore();
        covered = Path.combine(PathOperation.union, covered, region.path);
      }
      for (final detail in scene.details) {
        canvas.drawPath(
          detail.path,
          outline
            ..color = detail.color
            ..strokeWidth = detail.width,
        );
      }
    }
    if (hintColor != null) {
      final hint = Paint()
        ..color = hintColor!.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round;
      for (final region in scene.regions) {
        if (!fills.containsKey(region.id) &&
            scene.numberPalette[region.number] == hintColor) {
          canvas.drawPath(region.path, hint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ColorCanvasPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.fills != fills ||
      oldDelegate.strokes != strokes ||
      oldDelegate.numberMode != numberMode ||
      oldDelegate.hintColor != hintColor;
}
