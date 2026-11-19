import 'dart:ui';

import 'package:flutter/material.dart'
    show
        CustomPainter,
        TextPainter,
        TextSpan,
        TextStyle,
        TextDirection,
        FontWeight;

import 'themed_geometric_scene.dart';

part 'ocean_scenes.dart';
part 'woodland_scenes.dart';
part 'rocket_scene.dart';
part 'number_scene.dart';

const numberPalette = <int, Color>{
  6: Color(0xFFB9E7FA),
  7: Color(0xFFA0DBF5),
  8: Color(0xFF8ED0F0),
  9: Color(0xFF79C6EB),
  10: Color(0xFF426CBA),
  11: Color(0xFF355AA4),
  12: Color(0xFF284A91),
};

class ArtRegion {
  const ArtRegion({
    required this.id,
    required this.path,
    required this.color,
    required this.labelPoint,
    required this.number,
    this.group,
  });
  final String id;
  final Path path;
  final Color color;
  final Offset labelPoint;
  final int number;
  final String? group;
}

class ArtStroke {
  const ArtStroke({
    required this.path,
    this.color = const Color(0xFF293E49),
    this.width = 2.5,
  });
  final Path path;
  final Color color;
  final double width;
}

class HiddenAnimal {
  const HiddenAnimal({
    required this.id,
    required this.nameRu,
    required this.nameKk,
    required this.nameEn,
    required this.anchor,
    required this.regionIds,
  });
  final String id;
  final String nameRu;
  final String nameKk;
  final String nameEn;
  final Offset anchor;
  final List<String> regionIds;
}

class ArtScene {
  const ArtScene({
    required this.regions,
    this.details = const [],
    this.drawingDetails = const [],
    this.viewBox = const Size(400, 400),
    this.hiddenAnimals = const [],
  });
  final List<ArtRegion> regions;
  final List<ArtStroke> details;
  final List<ArtStroke> drawingDetails;
  final Size viewBox;
  final List<HiddenAnimal> hiddenAnimals;

  /// A number has meaning only within this artwork. A shared blue palette
  /// cannot represent the natural colours of a fox, flower, or toy scene.
  Map<int, Color> get numberPalette {
    final colors = <int, Color>{};
    for (final region in regions) {
      final existing = colors[region.number];
      if (existing != null && existing.toARGB32() != region.color.toARGB32()) {
        throw StateError(
          'Number ${region.number} has conflicting colours. '
          'Prepare this artwork with withSemanticNumbers().',
        );
      }
      colors[region.number] = region.color;
    }
    return Map.unmodifiable(colors);
  }

  /// Equal source colours receive equal numbers, in stable first-use order.
  /// Region IDs and paths stay intact so saved fills and hit areas agree.
  ArtScene withSemanticNumbers() {
    final colorNumbers = <int, int>{};
    return ArtScene(
      regions: List.unmodifiable([
        for (final region in regions)
          ArtRegion(
            id: region.id,
            path: region.path,
            color: region.color,
            labelPoint: region.labelPoint,
            number: colorNumbers.putIfAbsent(
              region.color.toARGB32(),
              () => colorNumbers.length + 1,
            ),
            group: region.group,
          ),
      ]),
      details: details,
      drawingDetails: drawingDetails,
      viewBox: viewBox,
      hiddenAnimals: hiddenAnimals,
    );
  }
}

/// Original, resolution-independent artwork. Paths are also the input hit areas.
class SceneFactory {
  static final Map<String, ArtScene> _cache = {};
  static const sceneNames = [
    'whale',
    'dolphin',
    'duck',
    'turtle',
    'fox',
    'rabbit',
    'cat',
    'butterfly',
    'lion',
    'giraffe',
    'rocket',
    'owl',
  ];

  static ArtScene create(
    String scene, {
    int variant = 0,
    bool geometric = false,
    bool segmented = false,
    String? worldId,
  }) {
    if (!sceneNames.contains(scene)) {
      throw ArgumentError.value(
        scene,
        'scene',
        'Unknown archived vector scene. Current lessons use illustrationAsset.',
      );
    }
    final key = '$scene:$variant:$geometric:$segmented:$worldId';
    if (_cache.containsKey(key)) return _cache[key]!;
    if (geometric) {
      return _cache[key] = createThemedGeometricScene(
        scene,
        variant: variant,
        worldId: worldId,
      );
    }
    final b = _Builder(scene, variant);
    switch (scene) {
      case 'whale':
        _whale(b);
      case 'dolphin':
        _dolphin(b);
      case 'duck':
        _duck(b);
      case 'turtle':
        _turtle(b);
      case 'fox':
        _fox(b);
      case 'rabbit':
        _rabbit(b);
      case 'cat':
        _cat(b);
      case 'butterfly':
        _butterfly(b);
      case 'lion':
        _lion(b);
      case 'giraffe':
        _giraffe(b);
      case 'rocket':
        _rocket(b);
      case 'owl':
        _owl(b);
      default:
        throw StateError(
          'The vector scene registry has no renderer for $scene',
        );
    }
    final artwork = b.build();
    return _cache[key] = segmented ? _numberScene(artwork, variant) : artwork;
  }
}

const _ink = Color(0xFF293E49);
const _cream = Color(0xFFFFF1CF);
const _coral = Color(0xFFFF9B7D);
const _gold = Color(0xFFF5C451);
const _teal = Color(0xFF74CABD);
const _blue = Color(0xFF81BAEA);
const _lavender = Color(0xFFB7A5E4);
const _leaf = Color(0xFF91BD86);
const _white = Color(0xFFFFFEFA);

Path _poly(List<Offset> points) => Path()..addPolygon(points, true);
Path _oval(double x, double y, double w, double h) =>
    Path()..addOval(Rect.fromLTWH(x, y, w, h));

class _Builder {
  _Builder(this.name, this.variant);
  final String name;
  final int variant;
  final List<ArtRegion> regions = [];
  final List<ArtStroke> details = [];
  int _count = 0;
  int? _subjectDetailsStart;
  void region(
    String id,
    Path path,
    Color color,
    double x,
    double y, {
    bool subject = true,
    int? number,
  }) {
    if (subject) _subjectDetailsStart ??= details.length;
    regions.add(
      ArtRegion(
        id: id,
        path: path,
        color: color,
        labelPoint: Offset(x, y),
        number: number ?? (subject ? 10 + _count++ % 3 : 6 + _count++ % 4),
        group: subject ? 'subject' : null,
      ),
    );
  }

  void stroke(Path path, {double width = 2.5, Color color = _ink}) =>
      details.add(ArtStroke(path: path, color: color, width: width));
  void eye(double x, double y, {double r = 4}) {
    stroke(_oval(x - r, y - r, r * 2, r * 2), width: r * 2 - 1);
  }

  void sparkle(double x, double y, double r, Color color) => region(
    'spark$_count',
    _poly([
      Offset(x, y - r),
      Offset(x + r * .3, y - r * .3),
      Offset(x + r, y),
      Offset(x + r * .3, y + r * .3),
      Offset(x, y + r),
      Offset(x - r * .3, y + r * .3),
      Offset(x - r, y),
      Offset(x - r * .3, y - r * .3),
    ]),
    color,
    x,
    y,
    subject: false,
  );
  ArtScene build() => ArtScene(
    regions: _placeLabels(regions, details: details),
    details: List.unmodifiable(details),
    drawingDetails: List.unmodifiable(
      details.skip(_subjectDetailsStart ?? details.length),
    ),
  );
}

List<ArtRegion> _placeLabels(
  List<ArtRegion> regions, {
  List<ArtStroke> details = const [],
  bool partitioned = false,
}) {
  final eyeBounds = details
      .where((d) => d.width >= 4)
      .map((d) => d.path.getBounds().inflate(d.width / 2 + 5))
      .toList();
  // Labels belong to the visible part of each layered path, never a later
  // animal part. This also gives every task region a reliable hint target.
  final labeled = <ArtRegion>[];
  for (var i = 0; i < regions.length; i++) {
    final r = regions[i];
    var exposed = r.path;
    if (!partitioned) {
      for (final later in regions.skip(i + 1)) {
        exposed = Path.combine(PathOperation.difference, exposed, later.path);
      }
    }
    if (exposed.getBounds().isEmpty) continue;
    bool visible(Offset p) =>
        r.path.contains(p) &&
        (partitioned ||
            !regions.skip(i + 1).any((later) => later.path.contains(p)));
    double clearance(Offset p) {
      if (!visible(p)) return 0;
      if (eyeBounds.any((bounds) => bounds.contains(p))) return 0;
      for (var distance = 3.0; distance <= 18; distance += 3) {
        for (final direction in const [
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(0, -1),
          Offset(.7, .7),
          Offset(-.7, .7),
          Offset(.7, -.7),
          Offset(-.7, -.7),
        ]) {
          if (!visible(p + direction * distance)) return distance - 3;
        }
      }
      return 18;
    }

    var point = r.labelPoint;
    var best = clearance(point);
    if (best < 9) {
      final bounds = r.path.getBounds();
      for (var x = bounds.left + 2; x < bounds.right; x += 4) {
        for (var y = bounds.top + 2; y < bounds.bottom; y += 4) {
          final candidate = Offset(x, y);
          final score =
              clearance(candidate) - (candidate - r.labelPoint).distance * .005;
          if (score > best) {
            point = candidate;
            best = score;
          }
        }
      }
    }
    labeled.add(
      ArtRegion(
        id: r.id,
        path: r.path,
        color: r.color,
        labelPoint: point,
        number: r.number,
        group: r.group,
      ),
    );
  }
  return List.unmodifiable(labeled);
}

/// Anatomical teaching order is independent of painting order. Background
/// scenery is deliberately excluded: each gesture develops the animal itself.
List<ArtStroke> drawingSteps(String scene) {
  final art = SceneFactory.create(scene);
  const sequences = <String, List<List<String>>>{
    'duck': [
      ['head'],
      ['beak'],
      ['body', 'wing'],
      ['footleft', 'footright'],
    ],
    'whale': [
      ['body', 'belly'],
      ['flipper'],
      ['tailupper', 'taillower'],
      ['spoutleft', 'spoutright'],
    ],
    'dolphin': [
      ['body', 'belly'],
      ['flipper'],
      ['dorsal'],
      ['tailupper', 'taillower'],
    ],
    'turtle': [
      ['shelltop', 'shellbottom'],
      ['shellcenter'],
      ['head'],
      ['leftflipper', 'backflipper', 'frontflipper', 'tail'],
    ],
    'fox': [
      ['head', 'cheekleft', 'cheekright'],
      ['earleft', 'earright'],
      ['bodyleft', 'bodyright', 'chest'],
      ['tail', 'tailtip'],
    ],
    'rabbit': [
      ['head'],
      ['earleft', 'earright', 'earpinkleft', 'earpinkright'],
      ['bodyleft', 'bodyright'],
      ['foot', 'taillarge'],
    ],
    'cat': [
      ['head', 'earleft', 'earright'],
      ['muzzle'],
      ['body', 'chest'],
      ['pawleft', 'pawright', 'tail'],
    ],
    'butterfly': [
      ['body', 'head'],
      ['winglefttop', 'wingrighttop'],
      ['wingleftbottom', 'wingrightbottom'],
      ['spotleft', 'spotright', 'bottomleftdot', 'bottomrightdot'],
    ],
    'lion': [
      ['maneleft', 'maneright'],
      ['face', 'earleft', 'earright'],
      ['muzzleleft', 'muzzleright'],
      ['body', 'chest'],
      ['pawleft', 'pawright', 'tail'],
    ],
    'giraffe': [
      ['head', 'earleft', 'earright', 'muzzle'],
      ['neck'],
      ['body'],
      ['legfront', 'legback', 'tail'],
      ['spotneck1', 'spotneck2', 'spotbody1', 'spotbody2'],
    ],
    'rocket': [
      ['body', 'nose'],
      ['windowrim', 'window'],
      ['finleft', 'finright'],
      ['base'],
      ['flameouter', 'flameinner'],
    ],
    'owl': [
      ['head'],
      ['faceleft', 'faceright', 'beak'],
      ['body', 'belly'],
      ['wingleft', 'wingright'],
      ['footleft', 'footright'],
    ],
  };
  final result = <ArtStroke>[];
  for (final ids in sequences[scene] ?? sequences['fox']!) {
    final path = Path();
    for (final id in ids) {
      final index = art.regions.indexWhere((r) => r.id == id);
      if (index < 0) continue;
      var visible = art.regions[index].path;
      for (final later
          in art.regions.skip(index + 1).where((r) => r.group == 'subject')) {
        visible = Path.combine(PathOperation.difference, visible, later.path);
      }
      path.addPath(visible, Offset.zero);
    }
    if (!path.getBounds().isEmpty) result.add(ArtStroke(path: path));
  }
  final details = Path();
  for (final detail in art.drawingDetails) {
    details.addPath(detail.path, Offset.zero);
  }
  if (!details.getBounds().isEmpty) result.add(ArtStroke(path: details));
  return List.unmodifiable(result);
}

class ArtScenePainter extends CustomPainter {
  ArtScenePainter({
    required this.scene,
    this.fills = const {},
    this.colored = false,
    this.showNumbers = false,
    this.revealGroups = const {},
    this.faint = false,
  });
  final ArtScene scene;
  final Map<String, Color> fills;
  final bool colored;
  final bool showNumbers;
  final Set<String> revealGroups;
  final bool faint;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / scene.viewBox.width,
      size.height / scene.viewBox.height,
    );
    final outline = Paint()
      ..color = faint ? _ink.withValues(alpha: .15) : _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final r in scene.regions) {
      final fill =
          fills[r.id] ??
          (colored || revealGroups.contains(r.group)
              ? r.color
              : const Color(0xFFFFFEFA));
      canvas.drawPath(
        r.path,
        Paint()
          ..color = faint ? fill.withValues(alpha: .2) : fill
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(r.path, outline);
      if (showNumbers && !fills.containsKey(r.id)) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${r.number}',
            style: TextStyle(
              color: _ink.withValues(alpha: .72),
              fontSize: 14,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, r.labelPoint - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final d in scene.details) {
      canvas.drawPath(
        d.path,
        Paint()
          ..color = faint ? d.color.withValues(alpha: .15) : d.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArtScenePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.fills != fills ||
      oldDelegate.colored != colored ||
      oldDelegate.showNumbers != showNumbers ||
      oldDelegate.revealGroups != revealGroups ||
      oldDelegate.faint != faint;
}
