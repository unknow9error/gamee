import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../domain/artwork_limits.dart';
import '../../../domain/models.dart';
import 'raster_color_spec.dart';

/// An immutable stroke in normalized canvas coordinates. Width uses a fixed
/// 400-unit artboard so the same saved mark looks alike on phones and tablets.
class ColorPaintStroke {
  ColorPaintStroke({
    required List<Offset> points,
    required this.color,
    required this.width,
    this.eraser = false,
    this.clipRegionId,
  }) : points = List.unmodifiable(points);

  final List<Offset> points;
  final Color color;
  final double width;
  final bool eraser;
  final String? clipRegionId;
  double get normalizedWidth => width / 400;

  ColorPaintStroke withPoints(List<Offset> value) => ColorPaintStroke(
    points: value,
    color: color,
    width: width,
    eraser: eraser,
    clipRegionId: clipRegionId,
  );

  Map<String, dynamic> toJson() => {
    'points': [
      for (final point in points) [_rounded(point.dx), _rounded(point.dy)],
    ],
    'color': color.toARGB32(),
    'width': width,
    'eraser': eraser,
    'clipRegionId': clipRegionId,
  };

  static ColorPaintStroke? fromJson(dynamic value) {
    if (value is! Map ||
        value['points'] is! List ||
        value['color'] is! int ||
        value['width'] is! num) {
      return null;
    }
    final width = (value['width'] as num).toDouble();
    final argb = value['color'] as int;
    if (!width.isFinite || argb < 0 || argb > 0xFFFFFFFF) return null;
    final rawPoints = value['points'] as List;
    final count = math.min(rawPoints.length, ArtworkLimits.maxPointsPerStroke);
    final points = <Offset>[];
    // Retain both ends of a legacy long stroke rather than truncating its tail.
    for (var i = 0; i < count; i++) {
      final index = count == 1
          ? 0
          : (i * (rawPoints.length - 1) / (count - 1)).round();
      final raw = rawPoints[index];
      if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
        continue;
      }
      final x = (raw[0] as num).toDouble();
      final y = (raw[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
        continue;
      }
      points.add(Offset(x, y));
    }
    if (points.isEmpty) return null;
    final clip = value['clipRegionId'];
    if (clip != null && clip is! String) return null;
    return ColorPaintStroke(
      points: points,
      color: Color(argb),
      width: width.clamp(4, 32),
      eraser: value['eraser'] == true,
      clipRegionId: clip as String?,
    );
  }

  static double _rounded(double value) =>
      double.parse(value.toStringAsFixed(4));
}

/// Owns a coloring document, correctness and history independently of the UI.
/// Hints and labels never mutate it: only real fills or committed marks do.
class RasterColorDocument extends ChangeNotifier {
  RasterColorDocument({
    required this.spec,
    required this.ageBand,
    this.specSha256,
    Map<String, dynamic>? initialData,
  }) {
    if (specSha256 != null &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(specSha256!)) {
      throw ArgumentError('Invalid raster color metadata digest');
    }
    _regions = {for (final region in spec.regions) region.id: region};
    _palette = {for (final entry in spec.palette) entry.id: entry};
    _requiredIds = spec.regionsFor(ageBand).map((region) => region.id).toSet();
    _taskPaletteIds = spec.paletteFor(ageBand).map((entry) => entry.id).toSet();
    _selectedPaletteId = spec.paletteFor(ageBand).first.id;
    _restore(initialData);
    _measureVisibleWork();
  }

  final ColorSceneSpec spec;
  final AgeBand ageBand;

  /// Digest of the reviewed JSON bytes, supplied by the production loader.
  final String? specSha256;
  late final Map<String, ColorRegionSpec> _regions;
  late final Map<String, ColorPaletteEntry> _palette;
  late final Set<String> _requiredIds;
  late final Set<String> _taskPaletteIds;
  late String _selectedPaletteId;
  bool _creative = false;
  Map<String, String> _fills = {};
  List<ColorPaintStroke> _strokes = [];
  ColorPaintStroke? _activeStroke;
  final List<_DocumentSnapshot> _undo = [];
  final List<_DocumentSnapshot> _redo = [];
  final Map<String, Set<int>> _regionCells = {};
  int _visibleInkCells = 0;
  int _visibleFilledRegions = 0;

  bool get creative => _creative;
  String get selectedPaletteId => _selectedPaletteId;
  ColorPaletteEntry get selectedPalette => _palette[_selectedPaletteId]!;
  Map<String, String> get fills => Map.unmodifiable(_fills);
  List<ColorPaintStroke> get strokes => List.unmodifiable(_strokes);
  ColorPaintStroke? get activeStroke => _activeStroke;
  List<ColorPaintStroke> get allStrokes =>
      List.unmodifiable([..._strokes, ?_activeStroke]);
  bool get canUndo => _activeStroke == null && _undo.isNotEmpty;
  bool get canRedo => _activeStroke == null && _redo.isNotEmpty;
  int get requiredCount => _requiredIds.length;
  int get completedCount => _requiredIds
      .where(
        (id) => _fills[id] == spec.acceptedPaletteIdFor(_regions[id]!, ageBand),
      )
      .length;
  bool get solved => requiredCount > 0 && completedCount == requiredCount;
  int get visibleInkCells => _visibleInkCells;
  bool get canFinish =>
      _creative ? _visibleFilledRegions > 0 || _visibleInkCells >= 8 : solved;
  int get totalPointCount =>
      _strokes.fold(0, (sum, stroke) => sum + stroke.points.length);

  void selectPalette(String id) {
    if (!_palette.containsKey(id) ||
        (!_creative && !_taskPaletteIds.contains(id)) ||
        _selectedPaletteId == id) {
      return;
    }
    _selectedPaletteId = id;
    notifyListeners();
  }

  void setCreative(bool value) {
    if (_creative == value) return;
    endStroke();
    _record();
    _creative = value;
    if (!value) {
      _fills.removeWhere(
        (id, palette) =>
            !_requiredIds.contains(id) ||
            palette != spec.acceptedPaletteIdFor(_regions[id]!, ageBand),
      );
      _strokes = [];
      if (!_taskPaletteIds.contains(_selectedPaletteId)) {
        _selectedPaletteId = spec.paletteFor(ageBand).first.id;
      }
    }
    _changed();
  }

  bool fillRegion(String regionId) {
    final region = _regions[regionId];
    if (region == null || _activeStroke != null) return false;
    if (!_creative &&
        (!_requiredIds.contains(regionId) ||
            _selectedPaletteId != spec.acceptedPaletteIdFor(region, ageBand))) {
      return false;
    }
    if (_fills[regionId] == _selectedPaletteId) return false;
    _record();
    _fills[regionId] = _selectedPaletteId;
    _changed();
    return true;
  }

  void eraseRegion(String regionId) {
    if (!_creative || !_fills.containsKey(regionId) || _activeStroke != null) {
      return;
    }
    _record();
    _fills.remove(regionId);
    _changed();
  }

  void beginStroke(
    Offset point, {
    String? clipRegionId,
    bool eraser = false,
    double width = 12,
    Color? color,
  }) {
    if (!_creative ||
        _activeStroke != null ||
        _strokes.length >= ArtworkLimits.maxBrushStrokes ||
        !_finitePoint(point) ||
        !width.isFinite ||
        (clipRegionId != null && !_regions.containsKey(clipRegionId))) {
      return;
    }
    _activeStroke = ColorPaintStroke(
      points: [_clamped(point)],
      color: color ?? selectedPalette.color,
      width: width.clamp(4, 32),
      eraser: eraser,
      clipRegionId: clipRegionId,
    );
    notifyListeners();
  }

  void appendStroke(Offset point) {
    final active = _activeStroke;
    if (active == null || !_finitePoint(point)) return;
    final clamped = _clamped(point);
    if ((clamped - active.points.last).distance < .001) return;
    var points = [...active.points, clamped];
    if (points.length > ArtworkLimits.maxPointsPerStroke) {
      points = _simplify(points, ArtworkLimits.maxPointsPerStroke ~/ 2);
    }
    _activeStroke = active.withPoints(points);
    notifyListeners();
  }

  void endStroke() {
    final active = _activeStroke;
    if (active == null) return;
    _record();
    _strokes = [..._strokes, active];
    _activeStroke = null;
    _compact();
    _changed();
  }

  void cancelStroke() {
    if (_activeStroke == null) return;
    _activeStroke = null;
    // Starting or cancelling a pointer never consumes the redo history.
    notifyListeners();
  }

  void undo() => _restoreHistory(_undo, _redo);
  void redo() => _restoreHistory(_redo, _undo);

  void clear() {
    cancelStroke();
    if (_fills.isEmpty && _strokes.isEmpty) return;
    _record();
    _fills = {};
    _strokes = [];
    _changed();
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'kind': 'rasterColor',
    'asset': spec.asset,
    'assetSha256': spec.assetSha256,
    if (specSha256 != null) 'specSha256': specSha256,
    'ageBand': ageBand.name,
    'creative': _creative,
    'selectedPaletteId': _selectedPaletteId,
    'fills': Map<String, String>.of(_fills),
    'strokes': [for (final stroke in _strokes) stroke.toJson()],
  };

  void _restore(Map<String, dynamic>? data) {
    if (data == null ||
        data['version'] != 2 ||
        data['kind'] != 'rasterColor' ||
        data['asset'] != spec.asset ||
        data['assetSha256'] != spec.assetSha256 ||
        (specSha256 != null && data['specSha256'] != specSha256)) {
      return;
    }
    _creative = data['creative'] == true;
    final selected = data['selectedPaletteId'];
    if (selected is String &&
        _palette.containsKey(selected) &&
        (_creative || _taskPaletteIds.contains(selected))) {
      _selectedPaletteId = selected;
    }
    final rawFills = data['fills'];
    if (rawFills is Map) {
      for (final entry in rawFills.entries) {
        final id = entry.key, paletteId = entry.value;
        if (id is! String ||
            paletteId is! String ||
            !_regions.containsKey(id) ||
            !_palette.containsKey(paletteId)) {
          continue;
        }
        if (_creative ||
            (_requiredIds.contains(id) &&
                paletteId ==
                    spec.acceptedPaletteIdFor(_regions[id]!, ageBand))) {
          _fills[id] = paletteId;
        }
      }
    }
    final rawStrokes = data['strokes'];
    if (_creative && rawStrokes is List) {
      for (final raw in rawStrokes.take(ArtworkLimits.maxBrushStrokes)) {
        final stroke = ColorPaintStroke.fromJson(raw);
        if (stroke == null ||
            (stroke.clipRegionId != null &&
                !_regions.containsKey(stroke.clipRegionId))) {
          continue;
        }
        _strokes.add(stroke);
      }
      _compact();
    }
  }

  _DocumentSnapshot _snapshot() =>
      _DocumentSnapshot(Map.of(_fills), List.of(_strokes), _creative);

  void _record() {
    _undo.add(_snapshot());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  void _restoreHistory(
    List<_DocumentSnapshot> source,
    List<_DocumentSnapshot> target,
  ) {
    if (_activeStroke != null || source.isEmpty) return;
    final snapshot = source.removeLast();
    target.add(_snapshot());
    _fills = Map.of(snapshot.fills);
    _strokes = List.of(snapshot.strokes);
    _creative = snapshot.creative;
    if (!_creative && !_taskPaletteIds.contains(_selectedPaletteId)) {
      _selectedPaletteId = spec.paletteFor(ageBand).first.id;
    }
    _changed();
  }

  void _changed() {
    _measureVisibleWork();
    notifyListeners();
  }

  void _compact() {
    while (totalPointCount > ArtworkLimits.maxTotalBrushPoints) {
      final before = totalPointCount;
      _strokes = [
        for (final stroke in _strokes)
          stroke.withPoints(
            _simplify(
              stroke.points,
              math.max(2, (stroke.points.length * .8).floor()),
            ),
          ),
      ];
      if (before == totalPointCount) break;
    }
  }

  static List<Offset> _simplify(List<Offset> points, int cap) {
    if (points.length <= cap) return points;
    // A cap changes sampling density, never the number of separate strokes,
    // their clipping, endpoints, color, or eraser order.
    return List.generate(
      cap,
      (i) => points[(i * (points.length - 1) / (cap - 1)).round()],
    );
  }

  static const _grid = 64;

  Set<int> _cellsFor(String regionId) => _regionCells.putIfAbsent(regionId, () {
    final path = _regions[regionId]!.path;
    final bounds = path.getBounds();
    final cells = <int>{};
    for (
      var y = math.max(0, (bounds.top * _grid).floor());
      y < math.min(_grid, (bounds.bottom * _grid).ceil());
      y++
    ) {
      for (
        var x = math.max(0, (bounds.left * _grid).floor());
        x < math.min(_grid, (bounds.right * _grid).ceil());
        x++
      ) {
        if (path.contains(Offset((x + .5) / _grid, (y + .5) / _grid))) {
          cells.add(y * _grid + x);
        }
      }
    }
    return cells;
  });

  void _measureVisibleWork() {
    // false is opaque white paint; a missing entry is transparent brush layer.
    // An eraser removes brush paint and reveals the region fill underneath.
    final brush = <int, bool>{};
    for (final stroke in _strokes) {
      final clipCells = stroke.clipRegionId == null
          ? {for (final id in _regions.keys) ..._cellsFor(id)}
          : _cellsFor(stroke.clipRegionId!);
      final radius = stroke.normalizedWidth * _grid / 2;
      final colored = _visibleColor(stroke.color);
      void stamp(Offset p) {
        final cx = p.dx * _grid, cy = p.dy * _grid;
        for (var x = (cx - radius).floor(); x <= (cx + radius).ceil(); x++) {
          for (var y = (cy - radius).floor(); y <= (cy + radius).ceil(); y++) {
            if (x < 0 ||
                x >= _grid ||
                y < 0 ||
                y >= _grid ||
                Offset(x + .5 - cx, y + .5 - cy).distance > radius + .25) {
              continue;
            }
            final cell = y * _grid + x;
            if (!clipCells.contains(cell)) continue;
            if (stroke.eraser) {
              brush.remove(cell);
            } else if (stroke.color.a > 0) {
              brush[cell] = colored;
            }
          }
        }
      }

      stamp(stroke.points.first);
      for (var i = 1; i < stroke.points.length; i++) {
        final start = stroke.points[i - 1], end = stroke.points[i];
        final count = math.max(1, ((end - start).distance * _grid * 2).ceil());
        for (var sample = 1; sample <= count; sample++) {
          stamp(Offset.lerp(start, end, sample / count)!);
        }
      }
    }
    _visibleInkCells = brush.values.where((colored) => colored).length;
    _visibleFilledRegions = _fills.entries
        .where(
          (entry) =>
              _visibleColor(_palette[entry.value]!.color) &&
              _cellsFor(entry.key).any((cell) => brush[cell] != false),
        )
        .length;
  }

  static bool _visibleColor(Color color) =>
      color.a > 0 && color.toARGB32() != 0xFFFFFFFF;
  static bool _finitePoint(Offset point) =>
      point.dx.isFinite && point.dy.isFinite;
  static Offset _clamped(Offset point) =>
      Offset(point.dx.clamp(0, 1), point.dy.clamp(0, 1));
}

class _DocumentSnapshot {
  const _DocumentSnapshot(this.fills, this.strokes, this.creative);
  final Map<String, String> fills;
  final List<ColorPaintStroke> strokes;
  final bool creative;
}
