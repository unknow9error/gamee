import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/raster_color_asset.dart';
import 'engines/raster_color_document.dart';
import 'engines/raster_color_spec.dart';
import 'raster_color_painter.dart';

enum _PaintTool { fill, brush, eraser }

String colorSpecAsset(LevelDefinition level) {
  final configured = level.activityData['colorSpecAsset'];
  if (configured is String) return configured;
  return switch (level.id) {
    'v2_01' => 'assets/content/color-toybox.json',
    'v2_11' => 'assets/content/color-garden.json',
    _ => throw const FormatException('Missing coloring lesson metadata'),
  };
}

/// Uses the saved age band and the exact live painter for historical artwork.
class RasterColorArtworkPreview extends StatefulWidget {
  const RasterColorArtworkPreview({
    super.key,
    required this.level,
    required this.data,
  });
  final LevelDefinition level;
  final Map<String, dynamic> data;
  @override
  State<RasterColorArtworkPreview> createState() =>
      _RasterColorArtworkPreviewState();
}

class _RasterColorArtworkPreviewState extends State<RasterColorArtworkPreview> {
  LoadedColorScene? _scene;
  RasterColorDocument? _document;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RasterColorArtworkPreview old) {
    super.didUpdateWidget(old);
    if (old.level.id != widget.level.id ||
        old.level.illustrationAsset != widget.level.illustrationAsset ||
        colorSpecAsset(old.level) != colorSpecAsset(widget.level)) {
      _load();
    } else if (!identical(old.data, widget.data) && _scene != null) {
      _bindDocument();
    }
  }

  void _bindDocument() {
    _document?.dispose();
    final band =
        AgeBand.values
            .where((b) => b.name == widget.data['ageBand'])
            .firstOrNull ??
        AgeBand.primary;
    _document = RasterColorDocument(
      spec: _scene!.spec,
      ageBand: band,
      specSha256: _scene!.specSha256,
      initialData: widget.data,
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _document?.dispose();
    _document = null;
    _scene?.dispose();
    _scene = null;
    LoadedColorScene? loaded;
    try {
      loaded = await ColorSceneAssets.load(
        colorSpecAsset(widget.level),
        expectedIllustrationAsset: widget.level.illustrationAsset,
      );
      if (!mounted || generation != _generation) {
        loaded.dispose();
        return;
      }
      _scene = loaded;
      _bindDocument();
      setState(() {});
    } catch (_) {
      if (!identical(_scene, loaded)) loaded?.dispose();
      if (mounted && generation == _generation) setState(() {});
    }
  }

  @override
  void dispose() {
    _generation++;
    _document?.dispose();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scene == null || _document == null) {
      return const Center(child: Icon(Icons.palette_outlined));
    }
    return AspectRatio(
      aspectRatio: _scene!.spec.imageWidth / _scene!.spec.imageHeight,
      child: CustomPaint(
        painter: RasterColorPainter(
          image: _scene!.image,
          spec: _scene!.spec,
          ageBand: _document!.ageBand,
          fills: _document!.fills,
          strokes: _document!.strokes,
          creative: _document!.creative,
          showClues: false,
        ),
      ),
    );
  }
}

class RasterColorActivity extends StatefulWidget {
  const RasterColorActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  State<RasterColorActivity> createState() => _RasterColorActivityState();
}

class _RasterColorActivityState extends State<RasterColorActivity>
    with WidgetsBindingObserver {
  LoadedColorScene? _scene;
  RasterColorDocument? _document;
  bool _failed = false;
  bool _creativeUnlocked = false;
  int _generation = 0;
  _PaintTool _tool = _PaintTool.fill;
  double _brushWidth = 12;
  String? _message;
  String? _focusedRegionId;
  int? _drawingPointer;
  final Set<int> _pointers = {};
  final TransformationController _transform = TransformationController();
  Size _canvasSize = Size.zero;
  ActivityConfig get _config => widget.config;
  String _t(String ru, String kk, String en) =>
      textFor(_config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(RasterColorActivity old) {
    super.didUpdateWidget(old);
    if (old.config.level.id != _config.level.id ||
        old.config.ageBand != _config.ageBand) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _commitStroke();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _document?.removeListener(_refresh);
    _document?.dispose();
    _scene?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _document?.removeListener(_refresh);
    _document?.dispose();
    _document = null;
    _scene?.dispose();
    _scene = null;
    _failed = false;
    _creativeUnlocked = false;
    _focusedRegionId = null;
    _pointers.clear();
    _drawingPointer = null;
    _transform.value = Matrix4.identity();
    if (mounted) setState(() {});
    LoadedColorScene? loaded;
    try {
      final scene = loaded = await ColorSceneAssets.load(
        colorSpecAsset(_config.level),
        expectedIllustrationAsset: _config.level.illustrationAsset,
      );
      if (!mounted || generation != _generation) {
        scene.dispose();
        return;
      }
      final document = RasterColorDocument(
        spec: scene.spec,
        ageBand: _config.ageBand,
        initialData: _config.initialData,
        specSha256: scene.specSha256,
      );
      _creativeUnlocked =
          document.solved ||
          document.creative ||
          _config.level.activityData['creativeReplay'] == true;
      if (_config.level.activityData['creativeReplay'] == true) {
        document.setCreative(true);
      }
      document.addListener(_refresh);
      setState(() {
        _scene = scene;
        _document = document;
      });
    } catch (_) {
      if (!identical(_scene, loaded)) loaded?.dispose();
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  void _refresh() {
    if (!mounted) return;
    if (_document!.solved) _creativeUnlocked = true;
    setState(() {});
  }

  void _save() {
    final document = _document;
    if (document != null) {
      _config.onChanged({
        ...document.toJson(),
        'specAsset': colorSpecAsset(_config.level),
      });
    }
  }

  void _commitStroke() {
    final document = _document;
    if (document?.activeStroke == null) return;
    document!.endStroke();
    _drawingPointer = null;
    _save();
  }

  Offset _unit(Offset p, Size size) =>
      Offset(p.dx / size.width, p.dy / size.height);
  ColorRegionSpec? _hit(Offset point, Size size, {bool tolerate = false}) {
    final scene = _scene!.spec;
    final document = _document!;
    final regions = document.creative
        ? scene.regions
        : scene.regionsFor(_config.ageBand);
    for (final region in regions.reversed) {
      if (region.path.contains(point)) return region;
    }
    if (!tolerate || document.creative) return null;
    final zoom = _transform.value.getMaxScaleOnAxis();
    final radius =
        (switch (_config.ageBand) {
          AgeBand.preschool => 28.0,
          AgeBand.primary => 22.0,
          AgeBand.advanced => 18.0,
        }) /
        zoom;
    ColorRegionSpec? nearest;
    var distance = radius;
    for (final region in regions) {
      if (document.fills.containsKey(region.id) ||
          region.paletteId != document.selectedPaletteId) {
        continue;
      }
      if (!region.path
          .getBounds()
          .inflate(radius / size.shortestSide)
          .contains(point)) {
        continue;
      }
      for (final metric in region.path.computeMetrics()) {
        for (var along = 0.0; along < metric.length; along += .004) {
          final tangent = metric.getTangentForOffset(along);
          if (tangent == null) continue;
          final d = Offset(
            (tangent.position.dx - point.dx) * size.width,
            (tangent.position.dy - point.dy) * size.height,
          ).distance;
          if (d < distance) {
            nearest = region;
            distance = d;
          }
        }
      }
    }
    return nearest;
  }

  void _tap(Offset local, Size size) {
    final document = _document!;
    if (document.creative && _tool != _PaintTool.fill) return;
    final region = _hit(_unit(local, size), size, tolerate: true);
    if (region == null) return;
    _paintRegion(region);
  }

  void _paintRegion(ColorRegionSpec region) {
    final document = _document!;
    setState(() => _focusedRegionId = region.id);
    final filled = document.fillRegion(region.id);
    if (filled) {
      _config.onFeedback();
      _message = null;
      _save();
    } else if (!document.fills.containsKey(region.id)) {
      setState(
        () => _message = _t(
          'Сравни цвет с подсказкой этой детали.',
          'Түсті осы бөліктің белгісімен салыстыр.',
          'Match your color to this piece’s clue.',
        ),
      );
    }
  }

  void _pointerDown(PointerDownEvent event, Size size) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) {
      _document!.cancelStroke();
      _drawingPointer = null;
      return;
    }
    final document = _document!;
    if (!document.creative || _tool == _PaintTool.fill) return;
    final point = _unit(event.localPosition, size);
    final region = _hit(point, size);
    if (region == null) return;
    _drawingPointer = event.pointer;
    document.beginStroke(
      point,
      clipRegionId: region.id,
      eraser: _tool == _PaintTool.eraser,
      width: _brushWidth,
    );
  }

  void _pointerUp(PointerUpEvent event, Size size) {
    _pointers.remove(event.pointer);
    if (_drawingPointer != event.pointer) return;
    final document = _document!;
    if (_tool == _PaintTool.eraser &&
        document.activeStroke?.points.length == 1) {
      final id = document.activeStroke!.clipRegionId!;
      document.cancelStroke();
      document.eraseRegion(id);
      _drawingPointer = null;
      _save();
    } else {
      _commitStroke();
    }
  }

  void _history(bool redo) {
    if (redo) {
      _document!.redo();
    } else {
      _document!.undo();
    }
    _save();
  }

  Future<void> _toggleCreative() async {
    if (!_creativeUnlocked) return;
    final document = _document!;
    if (document.creative) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _t(
              'Вернуться к заданию?',
              'Тапсырмаға қайтамыз ба?',
              'Return to the lesson?',
            ),
          ),
          content: Text(
            _t(
              'Свободные штрихи и изменённые цвета будут убраны.',
              'Еркін сызықтар мен өзгерген түстер өшіріледі.',
              'Free brush marks and changed colors will be removed.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                _t(
                  'Продолжить рисовать',
                  'Сурет салуды жалғастыру',
                  'Keep painting',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_t('К заданию', 'Тапсырмаға', 'Return')),
            ),
          ],
        ),
      );
      if (!mounted || leave != true) return;
    }
    document.setCreative(!document.creative);
    setState(() {
      _tool = _PaintTool.fill;
      _message = null;
    });
    _save();
  }

  Future<void> _clear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t(
            'Очистить рисунок?',
            'Суретті тазалаймыз ба?',
            'Clear this picture?',
          ),
        ),
        content: Text(
          _t(
            'Очистку можно отменить стрелкой назад.',
            'Тазалауды кері көрсеткімен қайтаруға болады.',
            'You can undo clearing.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Оставить', 'Қалдыру', 'Keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Очистить', 'Тазалау', 'Clear')),
          ),
        ],
      ),
    );
    if (!mounted || clear != true) return;
    _document!.clear();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              _t(
                'Не получилось открыть рисунок.',
                'Суретті ашу мүмкін болмады.',
                'Could not open this picture.',
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(_t('Ещё раз', 'Қайталау', 'Try again')),
            ),
          ],
        ),
      );
    }
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _document!.creative
                        ? Icons.brush_rounded
                        : Icons.palette_rounded,
                    size: 20,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _document!.creative
                          ? _t('Твои цвета', 'Өз түстерің', 'Your colors')
                          : _instruction(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_document!.creative)
                    Text(
                      '${_document!.completedCount}/${_document!.requiredCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.green,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _canvas()),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 230,
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _legend(wide: true),
                                      if (_document!.creative) _creativeTools(),
                                      if (_message != null)
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            _message!,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              _actions(wide: true),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _canvas()),
                        _legend(wide: false),
                        if (_message != null)
                          Text(
                            _message!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        _actions(wide: false),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  String _instruction() => switch (_scene!.spec.ruleFor(_config.ageBand).mode) {
    ColorRuleMode.color => _t(
      'Найди такой же цвет',
      'Дәл сондай түсті тап',
      'Match the color',
    ),
    ColorRuleMode.number => _t(
      'Число подскажет цвет',
      'Сан түсті көрсетеді',
      'Match the number',
    ),
    ColorRuleMode.shape => _t(
      'Фигура подскажет цвет',
      'Пішін түсті көрсетеді',
      'Match the shape',
    ),
    ColorRuleMode.numberAndShape => _t(
      'Реши пример и сравни фигуру',
      'Мысалды шешіп, пішінді салыстыр',
      'Solve the sum and match the shape',
    ),
    ColorRuleMode.parityAndShape => _t(
      'Чётность числа и фигура',
      'Санның жұптығы мен пішін',
      'Number parity and shape',
    ),
  };
  Widget _canvas() => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = _scene!.spec.imageWidth / _scene!.spec.imageHeight;
      final width = math.min(
        constraints.maxWidth,
        constraints.maxHeight * ratio,
      );
      final size = Size(width, width / ratio);
      _canvasSize = size;
      final document = _document!;
      final pending = _scene!.spec
          .regionsFor(_config.ageBand)
          .where((r) => !document.fills.containsKey(r.id));
      final hinted =
          pending
              .where((r) => r.paletteId == document.selectedPaletteId)
              .firstOrNull ??
          pending.firstOrNull;
      final painter = RasterColorPainter(
        image: _scene!.image,
        spec: _scene!.spec,
        ageBand: _config.ageBand,
        fills: document.fills,
        strokes: document.allStrokes,
        creative: document.creative,
        focusedRegionId: _focusedRegionId,
        hintRegionId: _config.showHint && !document.creative
            ? hinted?.id
            : null,
      );
      final callouts = document.creative
          ? <ColorClueLayout>[]
          : painter
                .visibleClueLayouts(size)
                .values
                .where((layout) => layout.isCallout)
                .toList();
      return Center(
        child: SizedBox.fromSize(
          size: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 4,
              panEnabled: !document.creative || _tool == _PaintTool.fill,
              child: Listener(
                onPointerDown: (e) => _pointerDown(e, size),
                onPointerMove: (e) {
                  if (e.pointer == _drawingPointer && _pointers.length == 1) {
                    _document!.appendStroke(_unit(e.localPosition, size));
                  }
                },
                onPointerUp: (e) => _pointerUp(e, size),
                onPointerCancel: (e) {
                  _pointers.remove(e.pointer);
                  if (e.pointer == _drawingPointer) {
                    _document!.cancelStroke();
                    _drawingPointer = null;
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      key: const ValueKey('color-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _tap(details.localPosition, size),
                      child: CustomPaint(size: size, painter: painter),
                    ),
                    for (final layout in callouts) _clueTarget(layout, size),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _clueTarget(ColorClueLayout layout, Size size) {
    final badge = layout.badgeBounds!;
    final width = math.max(48.0, badge.width),
        height = math.max(48.0, badge.height);
    final hit = Rect.fromLTWH(
      (badge.center.dx - width / 2)
          .clamp(0, math.max(0, size.width - width))
          .toDouble(),
      (badge.center.dy - height / 2)
          .clamp(0, math.max(0, size.height - height))
          .toDouble(),
      width,
      height,
    );
    return Positioned.fromRect(
      rect: hit,
      child: Semantics(
        button: true,
        label:
            _t('Выбрать цвет: ', 'Түс таңдау: ', 'Choose a color: ') +
            _scene!.spec
                .regionById(layout.regionId)
                .names
                .resolve(_config.language),
        child: GestureDetector(
          key: ValueKey('raster-clue-${layout.regionId}'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final point = details.localPosition + hit.topLeft;
            if (!badge.contains(point)) {
              final actual = _hit(_unit(point, size), size);
              if (actual != null && actual.id != layout.regionId) {
                _paintRegion(actual);
                return;
              }
            }
            _paintRegion(_scene!.spec.regionById(layout.regionId));
          },
        ),
      ),
    );
  }

  Widget _legend({required bool wide}) {
    final entries = _document!.creative
        ? _scene!.spec.palette
        : _scene!.spec.paletteFor(_config.ageBand);
    final compact =
        wide &&
        _scene!.spec.ruleFor(_config.ageBand).mode !=
            ColorRuleMode.parityAndShape;
    final cards = entries
        .map((entry) => _paletteCard(entry, compact: compact))
        .toList();
    return wide
        ? Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: cards,
          )
        : SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: cards),
            ),
          );
  }

  Widget _paletteCard(ColorPaletteEntry entry, {bool compact = false}) {
    final selected = _document!.selectedPaletteId == entry.id;
    final contrast = entry.color.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    final mode = _scene!.spec.ruleFor(_config.ageBand).mode;
    Widget clue = ColorSymbol(symbol: entry.symbol, size: 24, color: contrast);
    if (!_document!.creative && mode == ColorRuleMode.number) {
      clue = Text(
        '${entry.number}',
        style: TextStyle(
          color: contrast,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      );
    }
    if (!_document!.creative &&
        (mode == ColorRuleMode.numberAndShape ||
            mode == ColorRuleMode.parityAndShape)) {
      final rule = _scene!.spec
          .ruleFor(_config.ageBand)
          .lookup
          .firstWhere((r) => r.paletteId == entry.id);
      clue = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            mode == ColorRuleMode.numberAndShape
                ? '${rule.value}'
                : rule.parity == 'odd'
                ? _t('Нечёт.', 'Тақ', 'Odd')
                : _t('Чёт.', 'Жұп', 'Even'),
            style: TextStyle(
              color: contrast,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          ColorSymbol(symbol: rule.symbol, size: 20, color: contrast),
        ],
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: entry.names.resolve(_config.language),
      child: Tooltip(
        message: entry.names.resolve(_config.language),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            key: ValueKey('raster-palette-${entry.id}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              _document!.selectPalette(entry.id);
              _message = null;
            },
            child: Container(
              width: compact ? 64 : 88,
              height: 48,
              decoration: BoxDecoration(
                color: entry.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.ink : entry.color,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Center(child: clue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions({required bool wide}) {
    final tools = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _document!.canUndo ? () => _history(false) : null,
          tooltip: _t('Отменить', 'Болдырмау', 'Undo'),
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          onPressed: _document!.canRedo ? () => _history(true) : null,
          tooltip: _t('Повторить', 'Қайталау', 'Redo'),
          icon: const Icon(Icons.redo_rounded),
        ),
        ValueListenableBuilder<Matrix4>(
          valueListenable: _transform,
          builder: (context, matrix, _) => IconButton(
            onPressed: _zoomPicture,
            tooltip: matrix.getMaxScaleOnAxis() > 1.01
                ? _t(
                    'Показать весь рисунок',
                    'Бүкіл суретті көрсету',
                    'Show full picture',
                  )
                : _t('Увеличить рисунок', 'Суретті үлкейту', 'Zoom picture'),
            icon: Icon(
              matrix.getMaxScaleOnAxis() > 1.01
                  ? Icons.zoom_out_rounded
                  : Icons.zoom_in_rounded,
            ),
          ),
        ),
        IconButton(
          onPressed: _creativeUnlocked
              ? (_document!.creative ? _showTools : _toggleCreative)
              : null,
          tooltip: _t(
            'Свои цвета и кисть',
            'Өз түстерің мен қылқалам',
            'Your colors and brush',
          ),
          icon: const Icon(Icons.brush_rounded),
        ),
        if (!wide) Expanded(child: _finishButton()),
      ],
    );
    return wide
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [tools, _finishButton()],
          )
        : tools;
  }

  void _zoomPicture() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    final targets = _scene!.spec
        .regionsFor(_config.ageBand)
        .where((r) => !_document!.fills.containsKey(r.id));
    final target =
        targets
            .where((r) => r.paletteId == _document!.selectedPaletteId)
            .firstOrNull ??
        targets.firstOrNull;
    final center = target?.anchor ?? const Offset(.5, .5);
    const scale = 2.3;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (_canvasSize.width / 2 - center.dx * _canvasSize.width * scale).clamp(
          _canvasSize.width * (1 - scale),
          0,
        ),
        (_canvasSize.height / 2 - center.dy * _canvasSize.height * scale).clamp(
          _canvasSize.height * (1 - scale),
          0,
        ),
        0,
      );
  }

  Widget _finishButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: const ValueKey('color-finish'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: _document!.canFinish
          ? () => _config.onCompleted({
              ..._document!.toJson(),
              'specAsset': colorSpecAsset(_config.level),
            })
          : null,
      icon: const Icon(Icons.check_rounded, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(_t('Готово', 'Дайын', 'Done'), maxLines: 1),
      ),
    ),
  );
  Widget _creativeTools({VoidCallback? refresh, VoidCallback? onReturn}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _PaintTool.values
                .map(
                  (tool) => IconButton(
                    isSelected: _tool == tool,
                    onPressed: () {
                      setState(() => _tool = tool);
                      refresh?.call();
                    },
                    tooltip: switch (tool) {
                      _PaintTool.fill => _t('Заливка', 'Бояу', 'Fill'),
                      _PaintTool.brush => _t('Кисть', 'Қылқалам', 'Brush'),
                      _PaintTool.eraser => _t('Ластик', 'Өшіргіш', 'Eraser'),
                    },
                    icon: Icon(switch (tool) {
                      _PaintTool.fill => Icons.format_color_fill_rounded,
                      _PaintTool.brush => Icons.brush_rounded,
                      _PaintTool.eraser => Icons.auto_fix_normal_rounded,
                    }),
                  ),
                )
                .toList(),
          ),
          if (_tool != _PaintTool.fill)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [6.0, 12.0, 24.0]
                  .map(
                    (width) => IconButton(
                      isSelected: _brushWidth == width,
                      onPressed: () {
                        setState(() => _brushWidth = width);
                        refresh?.call();
                      },
                      tooltip: _t(
                        'Толщина кисти',
                        'Қылқалам қалыңдығы',
                        'Brush size',
                      ),
                      icon: Icon(Icons.circle, size: width),
                    ),
                  )
                  .toList(),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _clear,
                tooltip: _t('Очистить', 'Тазалау', 'Clear'),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              TextButton(
                onPressed: onReturn ?? _toggleCreative,
                child: Text(_t('К заданию', 'Тапсырмаға', 'Lesson')),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListenableBuilder(
              listenable: _document!,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t(
                      'Твоя мастерская',
                      'Сенің шеберханаң',
                      'Your art studio',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  _legend(wide: true),
                  _creativeTools(
                    refresh: () => refresh(() {}),
                    onReturn: () {
                      Navigator.pop(sheetContext);
                      _toggleCreative();
                    },
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_t('Рисовать', 'Сурет салу', 'Paint')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
