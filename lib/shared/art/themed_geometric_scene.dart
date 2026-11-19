import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'art_scene.dart';

/// Original line-art animals become angular, independently paintable mosaic
/// pieces. The actual paths drive both rendering and hit-testing.
ArtScene createThemedGeometricScene(
  String scene, {
  int variant = 0,
  String? worldId,
}) {
  final theme = _themes[worldId] ?? _themes[_themeForScene(scene)]!;
  final layout = _layouts[variant % _layouts.length];
  final regions = <ArtRegion>[];
  final details = <ArtStroke>[];
  final animals = <HiddenAnimal>[];
  var silhouettes = Path();
  var number = 6;

  for (var index = 0; index < theme.length; index++) {
    final name = theme[(index + variant ~/ 2) % theme.length];
    final original = SceneFactory.create(name);
    final parts = original.regions.where((r) => r.group == 'subject').toList();
    var sourceBounds = Rect.zero;
    for (final part in parts) {
      sourceBounds = sourceBounds.isEmpty
          ? part.path.getBounds()
          : sourceBounds.expandToInclude(part.path.getBounds());
    }
    for (final detail in original.drawingDetails) {
      sourceBounds = sourceBounds.expandToInclude(
        detail.path.getBounds().inflate(detail.width / 2),
      );
    }
    final angle = ((index + variant) % 3 - 1) * .065;
    final matrix = _fitMatrix(sourceBounds, layout[index], angle);
    final transformed = [
      for (final part in parts) _angular(part.path).transform(matrix),
    ];
    final visibleParts = <Path>[];
    for (var partIndex = 0; partIndex < transformed.length; partIndex++) {
      var visible = transformed[partIndex];
      for (final later in transformed.skip(partIndex + 1)) {
        visible = Path.combine(PathOperation.difference, visible, later);
      }
      visibleParts.add(visible);
    }

    final ids = <String>[];
    var largestArea = 0.0;
    var anchor = layout[index].center;
    for (var partIndex = 0; partIndex < visibleParts.length; partIndex++) {
      final path = visibleParts[partIndex];
      if (path.getBounds().isEmpty) continue;
      final pieces = _splitBroadPart(path, variant + partIndex);
      for (var pieceIndex = 0; pieceIndex < pieces.length; pieceIndex++) {
        final piece = pieces[pieceIndex];
        final point = _interiorPoint(piece);
        if (point == null) continue;
        final id = '$name-${parts[partIndex].id}-$pieceIndex';
        ids.add(id);
        final bounds = piece.getBounds();
        final area = bounds.width * bounds.height;
        if (area > largestArea) {
          largestArea = area;
          anchor = point;
        }
        regions.add(
          ArtRegion(
            id: id,
            path: piece,
            color: parts[partIndex].color,
            labelPoint: point,
            number: number,
            group: name,
          ),
        );
        number = number == 12 ? 6 : number + 1;
        silhouettes = Path.combine(PathOperation.union, silhouettes, piece);
      }
    }
    final scale = math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]);
    for (final detail in original.drawingDetails) {
      details.add(
        ArtStroke(
          path: detail.path.transform(matrix),
          color: detail.color,
          width: math.max(1.15, detail.width * scale),
        ),
      );
    }
    final names = _names[name]!;
    animals.add(
      HiddenAnimal(
        id: name,
        nameRu: names[0],
        nameKk: names[1],
        nameEn: names[2],
        anchor: anchor,
        regionIds: List.unmodifiable(ids),
      ),
    );
  }

  final hub = _hubs[variant % _hubs.length];
  final background = <ArtRegion>[];
  for (var i = 0; i < _edge.length; i++) {
    final triangle = Path()
      ..addPolygon([_edge[i], _edge[(i + 1) % _edge.length], hub], true);
    final path = Path.combine(PathOperation.difference, triangle, silhouettes);
    final point = _interiorPoint(path);
    if (point == null) continue;
    background.add(
      ArtRegion(
        id: 'mosaic-$i',
        path: path,
        color: _backgroundColors[(i + variant) % _backgroundColors.length],
        labelPoint: point,
        number: 6 + i % 7,
      ),
    );
  }
  return ArtScene(
    regions: List.unmodifiable([...background, ...regions]),
    details: List.unmodifiable(details),
    hiddenAnimals: List.unmodifiable(animals),
  );
}

const _themes = <String, List<String>>{
  'ocean': ['whale', 'dolphin', 'turtle'],
  'forest': ['fox', 'rabbit', 'owl'],
  'meadow': ['butterfly', 'turtle', 'rabbit'],
  'farm': ['duck', 'cat', 'rabbit'],
  'safari': ['lion', 'giraffe', 'turtle'],
  'space': ['owl', 'cat', 'rocket'],
};

String _themeForScene(String scene) => switch (scene) {
  'whale' || 'dolphin' || 'turtle' => 'ocean',
  'fox' || 'owl' => 'forest',
  'butterfly' || 'rabbit' => 'meadow',
  'duck' || 'cat' => 'farm',
  'lion' || 'giraffe' => 'safari',
  _ => 'space',
};

const _names = <String, List<String>>{
  'whale': ['Кит', 'Кит', 'Whale'],
  'dolphin': ['Дельфин', 'Дельфин', 'Dolphin'],
  'duck': ['Утёнок', 'Үйрек', 'Duckling'],
  'turtle': ['Черепаха', 'Тасбақа', 'Turtle'],
  'fox': ['Лисёнок', 'Түлкі', 'Fox'],
  'rabbit': ['Зайчонок', 'Қоян', 'Bunny'],
  'cat': ['Котёнок', 'Мысық', 'Kitten'],
  'butterfly': ['Бабочка', 'Көбелек', 'Butterfly'],
  'lion': ['Львёнок', 'Арыстан', 'Lion cub'],
  'giraffe': ['Жираф', 'Керік', 'Giraffe'],
  'rocket': ['Ракета', 'Зымыран', 'Rocket'],
  'owl': ['Совёнок', 'Жапалақ', 'Owl'],
};

// Each composition places its three silhouettes in distinct, non-overlapping
// rectangles. A quarter-turn of the *layout* never turns an animal upside down.
const _layouts = <List<Rect>>[
  [
    Rect.fromLTWH(31, 33, 171, 171),
    Rect.fromLTWH(209, 44, 161, 161),
    Rect.fromLTWH(105, 218, 190, 151),
  ],
  [
    Rect.fromLTWH(31, 208, 166, 161),
    Rect.fromLTWH(104, 32, 184, 158),
    Rect.fromLTWH(207, 207, 163, 162),
  ],
  [
    Rect.fromLTWH(31, 93, 161, 194),
    Rect.fromLTWH(207, 32, 163, 160),
    Rect.fromLTWH(207, 211, 163, 158),
  ],
  [
    Rect.fromLTWH(31, 32, 163, 161),
    Rect.fromLTWH(31, 209, 163, 160),
    Rect.fromLTWH(211, 101, 159, 187),
  ],
];
const _hubs = [
  Offset(202, 211),
  Offset(202, 197),
  Offset(196, 201),
  Offset(203, 201),
];
const _edge = [
  Offset(22, 22),
  Offset(200, 22),
  Offset(378, 22),
  Offset(378, 199),
  Offset(378, 378),
  Offset(199, 378),
  Offset(22, 378),
  Offset(22, 201),
];
const _backgroundColors = [
  Color(0xFFFFF0D6),
  Color(0xFFE8F1EC),
  Color(0xFFF1E3DC),
  Color(0xFFE4ECF4),
];

Float64List _fitMatrix(Rect source, Rect target, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  final rotatedWidth = c.abs() * source.width + s.abs() * source.height;
  final rotatedHeight = s.abs() * source.width + c.abs() * source.height;
  final scale =
      .96 *
      math.min(target.width / rotatedWidth, target.height / rotatedHeight);
  final center = source.center;
  return Float64List.fromList([
    c * scale,
    s * scale,
    0,
    0,
    -s * scale,
    c * scale,
    0,
    0,
    0,
    0,
    1,
    0,
    target.center.dx - c * scale * center.dx + s * scale * center.dy,
    target.center.dy - s * scale * center.dx - c * scale * center.dy,
    0,
    1,
  ]);
}

Path _angular(Path original) {
  final result = Path()..fillType = original.fillType;
  for (final metric in original.computeMetrics()) {
    final count = math.max(3, (metric.length / 17).ceil());
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / count);
      if (tangent != null) points.add(tangent.position);
    }
    if (points.length >= 3) result.addPolygon(points, true);
  }
  return result;
}

List<Path> _splitBroadPart(Path path, int variant) {
  final bounds = path.getBounds();
  if (bounds.width < 32 || bounds.height < 29) return [path];
  final r = bounds.inflate(1);
  final first = Path()
    ..addPolygon(
      variant.isEven
          ? [r.topLeft, r.topRight, r.bottomRight]
          : [r.topLeft, r.topRight, r.bottomLeft],
      true,
    );
  final a = Path.combine(PathOperation.intersect, path, first);
  final b = Path.combine(PathOperation.difference, path, first);
  if (_interiorPoint(a) == null || _interiorPoint(b) == null) return [path];
  return [a, b];
}

Offset? _interiorPoint(Path path) {
  final bounds = path.getBounds();
  if (bounds.isEmpty) return null;
  if (path.contains(bounds.center)) return bounds.center;
  Offset? best;
  var bestDistance = double.infinity;
  final step = math.max(.4, math.min(2.0, bounds.shortestSide / 8));
  for (var y = bounds.top + step / 2; y < bounds.bottom; y += step) {
    for (var x = bounds.left + step / 2; x < bounds.right; x += step) {
      final p = Offset(x, y);
      final distance = (p - bounds.center).distanceSquared;
      if (distance < bestDistance && path.contains(p)) {
        bestDistance = distance;
        best = p;
      }
    }
  }
  return best;
}
