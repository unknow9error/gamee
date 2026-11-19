import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/models.dart';

/// A reviewed hotspot attached to one particular bitmap. Public geometry is in
/// source-image pixels, so rendering, crops and input share the same coordinate
/// space even when the image is letterboxed or magnified.
class HiddenPictureTarget {
  HiddenPictureTarget._({
    required this.id,
    required this.name,
    required List<Offset> polygon,
    required this.anchor,
    required this.cropRect,
  }) : polygon = List.unmodifiable(polygon),
       _path = Path()..addPolygon(polygon, true);

  final String id;
  final LocalizedText name;
  final List<Offset> polygon;
  final Offset anchor;
  final Rect cropRect;
  final Path _path;

  /// Return a copy so a painter cannot accidentally mutate input geometry.
  Path get path => Path.from(_path);
}

class HiddenPictureSpec {
  HiddenPictureSpec._({
    required this.id,
    required this.asset,
    required this.imageSize,
    required List<HiddenPictureTarget> targets,
    this.imageSha256,
  }) : targets = List.unmodifiable(targets);

  final String id;
  final String asset;
  final Size imageSize;
  final String? imageSha256;
  final List<HiddenPictureTarget> targets;

  factory HiddenPictureSpec.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('A hidden-picture spec must be an object.');
    }
    return HiddenPictureSpec.fromJson(decoded);
  }

  factory HiddenPictureSpec.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported hidden-picture spec version.');
    }
    final id = _identifier(json['id'], 'id');
    final asset = json['asset'];
    if (asset is! String ||
        !RegExp(r'^assets/images/levels/[A-Za-z0-9][A-Za-z0-9._-]*\.png$')
            .hasMatch(asset)) {
      throw const FormatException('Invalid hidden-picture image asset.');
    }
    final imageSize = Size(
      _dimension(json['imageWidth'], 'imageWidth'),
      _dimension(json['imageHeight'], 'imageHeight'),
    );
    final rawFingerprint = json['imageSha256'];
    if (rawFingerprint != null &&
        (rawFingerprint is! String ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(rawFingerprint))) {
      throw const FormatException('Invalid hidden-picture image fingerprint.');
    }
    final rawTargets = json['targets'];
    if (rawTargets is! List || rawTargets.length != 8) {
      throw const FormatException(
        'A hidden picture must define eight targets.',
      );
    }
    final targets = <HiddenPictureTarget>[];
    final ids = <String>{};
    for (final rawTarget in rawTargets) {
      if (rawTarget is! Map<String, dynamic>) {
        throw const FormatException(
          'A hidden-picture target must be an object.',
        );
      }
      final targetId = _identifier(rawTarget['id'], 'target.id');
      if (!ids.add(targetId)) {
        throw FormatException('Duplicate hidden-picture target: $targetId.');
      }
      final rawName = rawTarget['name'];
      if (rawName is! Map<String, dynamic>) {
        throw const FormatException('A target needs names in three languages.');
      }
      final name = LocalizedText(
        _name(rawName['ru'], 'ru'),
        _name(rawName['kk'], 'kk'),
        _name(rawName['en'], 'en'),
      );
      final rawPolygon = rawTarget['polygon'];
      if (rawPolygon is! List ||
          rawPolygon.length < 3 ||
          rawPolygon.length > 256) {
        throw const FormatException('A target needs a bounded polygon.');
      }
      final normalizedPolygon = [for (final point in rawPolygon) _point(point)];
      // Both open and explicitly closed JSON contours are accepted.
      if (normalizedPolygon.first == normalizedPolygon.last) {
        normalizedPolygon.removeLast();
      }
      _validatePolygon(normalizedPolygon);
      final normalizedPath = Path()..addPolygon(normalizedPolygon, true);
      final normalizedAnchor = _point(rawTarget['anchor']);
      if (!normalizedPath.contains(normalizedAnchor)) {
        throw FormatException(
          'Target $targetId has an anchor outside its path.',
        );
      }
      final rawCrop = rawTarget['crop'];
      if (rawCrop is! List || rawCrop.length != 4) {
        throw const FormatException('A target needs a source crop rectangle.');
      }
      final crop = Rect.fromLTRB(
        _unit(rawCrop[0]),
        _unit(rawCrop[1]),
        _unit(rawCrop[2]),
        _unit(rawCrop[3]),
      );
      final bounds = normalizedPath.getBounds();
      const epsilon = 1e-7;
      if (crop.width <= 0 ||
          crop.height <= 0 ||
          crop.left > bounds.left + epsilon ||
          crop.top > bounds.top + epsilon ||
          crop.right < bounds.right - epsilon ||
          crop.bottom < bounds.bottom - epsilon) {
        throw FormatException(
          'Target $targetId has a crop outside its bounds.',
        );
      }
      Offset toPixels(Offset point) =>
          Offset(point.dx * imageSize.width, point.dy * imageSize.height);
      targets.add(
        HiddenPictureTarget._(
          id: targetId,
          name: name,
          polygon: normalizedPolygon.map(toPixels).toList(growable: false),
          anchor: toPixels(normalizedAnchor),
          cropRect: Rect.fromLTRB(
            crop.left * imageSize.width,
            crop.top * imageSize.height,
            crop.right * imageSize.width,
            crop.bottom * imageSize.height,
          ),
        ),
      );
    }
    return HiddenPictureSpec._(
      id: id,
      asset: asset,
      imageSize: imageSize,
      imageSha256: (rawFingerprint as String?)?.toLowerCase(),
      targets: targets,
    );
  }

  /// Ordering is authored in the spec: large, visible friends precede the
  /// smaller, more concealed ones rather than being chosen randomly.
  List<HiddenPictureTarget> targetsFor(AgeBand ageBand) => List.unmodifiable(
    targets.take(switch (ageBand) {
      AgeBand.preschool => 2,
      AgeBand.primary => 4,
      AgeBand.advanced => 8,
    }),
  );
}

class HiddenPictureSession {
  HiddenPictureSession(this.spec, this.ageBand, {Map<String, dynamic>? draft})
    : activeTargets = spec.targetsFor(ageBand) {
    if (draft == null ||
        draft['version'] != 3 ||
        draft['kind'] != 'hiddenAnimals' ||
        draft['engine'] != 'rasterHidden' ||
        draft['specId'] != spec.id ||
        draft['asset'] != spec.asset ||
        draft['imageSha256'] != spec.imageSha256 ||
        !AgeBand.values.any((band) => band.name == draft['ageBand'])) {
      return;
    }
    final rawFound = draft['found'];
    if (rawFound is! List || rawFound.length > 8) return;
    final activeIds = activeTargets.map((target) => target.id).toSet();
    _found.addAll(rawFound.whereType<String>().where(activeIds.contains));
  }

  final HiddenPictureSpec spec;
  final AgeBand ageBand;
  final List<HiddenPictureTarget> activeTargets;
  final Set<String> _found = {};

  Set<String> get found => UnmodifiableSetView(_found);
  bool get isComplete => _found.length == activeTargets.length;
  List<HiddenPictureTarget> get remainingTargets => List.unmodifiable(
    activeTargets.where((target) => !_found.contains(target.id)),
  );

  /// [sourcePoint] and [tolerance] are in original bitmap pixels. The caller
  /// converts a short screen-space allowance through the image/zoom scale.
  /// Far background never succeeds merely because some target is nearest.
  HiddenPictureTarget? findAt(Offset sourcePoint, {double tolerance = 0}) {
    if (!sourcePoint.dx.isFinite ||
        !sourcePoint.dy.isFinite ||
        !tolerance.isFinite ||
        tolerance < 0 ||
        sourcePoint.dx < 0 ||
        sourcePoint.dy < 0 ||
        sourcePoint.dx > spec.imageSize.width ||
        sourcePoint.dy > spec.imageSize.height) {
      return null;
    }
    // Repeatedly tapping a found animal must not jump to an adjacent one just
    // because the younger child's touch allowance reaches its silhouette.
    if (activeTargets.any(
      (target) =>
          _found.contains(target.id) && target._path.contains(sourcePoint),
    )) {
      return null;
    }
    final remaining = remainingTargets;
    final directHits = remaining
        .where((target) => target._path.contains(sourcePoint))
        .toList(growable: false);
    if (directHits.length == 1) return directHits.single;
    // Ambiguous overlapping contours should be corrected or zoomed in; their
    // declaration order must not silently decide which animal gets awarded.
    if (directHits.length > 1 || tolerance == 0) return null;

    HiddenPictureTarget? closest;
    var bestDistance = double.infinity;
    var ambiguous = false;
    for (final target in remaining) {
      final distance = _distanceToPolygon(sourcePoint, target.polygon);
      final epsilon = math.max(1e-7, tolerance * 1e-7);
      if (distance > tolerance + epsilon) continue;
      if ((distance - bestDistance).abs() <= epsilon) {
        ambiguous = true;
      } else if (distance < bestDistance) {
        closest = target;
        bestDistance = distance;
        ambiguous = false;
      }
    }
    return ambiguous ? null : closest;
  }

  bool discover(String targetId) {
    if (!activeTargets.any((target) => target.id == targetId)) return false;
    return _found.add(targetId);
  }

  Map<String, dynamic> toJson() => {
    'version': 3,
    'kind': 'hiddenAnimals',
    'engine': 'rasterHidden',
    'specId': spec.id,
    'asset': spec.asset,
    if (spec.imageSha256 != null) 'imageSha256': spec.imageSha256,
    'ageBand': ageBand.name,
    'found': [
      for (final target in activeTargets)
        if (_found.contains(target.id)) target.id,
    ],
  };
}

String _identifier(Object? value, String label) {
  if (value is! String || !RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(value)) {
    throw FormatException('Invalid hidden-picture $label.');
  }
  return value;
}

String _name(Object? value, String language) {
  if (value is! String || value.trim().isEmpty || value.length > 80) {
    throw FormatException('Invalid hidden-picture name in $language.');
  }
  return value.trim();
}

double _dimension(Object? value, String label) {
  if (value is! num ||
      !value.isFinite ||
      value < 1 ||
      value > 16384 ||
      value.toDouble() != value.roundToDouble()) {
    throw FormatException('Invalid hidden-picture $label.');
  }
  return value.toDouble();
}

double _unit(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException(
      'Hotspot coordinates must be within the image.',
    );
  }
  return value.toDouble();
}

Offset _point(Object? value) {
  if (value is! List || value.length != 2) {
    throw const FormatException(
      'A hotspot point must contain two coordinates.',
    );
  }
  return Offset(_unit(value[0]), _unit(value[1]));
}

double _cross(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

void _validatePolygon(List<Offset> points) {
  if (points.length < 3) {
    throw const FormatException('A hotspot needs three distinct vertices.');
  }
  var twiceArea = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    if ((a - b).distanceSquared < 1e-16) {
      throw const FormatException('A hotspot has duplicate adjacent vertices.');
    }
    twiceArea += a.dx * b.dy - b.dx * a.dy;
  }
  if (twiceArea.abs() < 1e-7) {
    throw const FormatException('A hotspot must have nonzero area.');
  }
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      if (j == i + 1 || (i == 0 && j == points.length - 1)) continue;
      if (_segmentsIntersect(
        points[i],
        points[(i + 1) % points.length],
        points[j],
        points[(j + 1) % points.length],
      )) {
        throw const FormatException('A hotspot polygon must not cross itself.');
      }
    }
  }
}

bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  const epsilon = 1e-12;
  final abC = _cross(a, b, c);
  final abD = _cross(a, b, d);
  final cdA = _cross(c, d, a);
  final cdB = _cross(c, d, b);
  bool onSegment(Offset p, Offset q, Offset r) =>
      q.dx >= math.min(p.dx, r.dx) - epsilon &&
      q.dx <= math.max(p.dx, r.dx) + epsilon &&
      q.dy >= math.min(p.dy, r.dy) - epsilon &&
      q.dy <= math.max(p.dy, r.dy) + epsilon;
  if (abC.abs() <= epsilon && onSegment(a, c, b)) return true;
  if (abD.abs() <= epsilon && onSegment(a, d, b)) return true;
  if (cdA.abs() <= epsilon && onSegment(c, a, d)) return true;
  if (cdB.abs() <= epsilon && onSegment(c, b, d)) return true;
  return ((abC > 0) != (abD > 0)) && ((cdA > 0) != (cdB > 0));
}

double _distanceToPolygon(Offset point, List<Offset> polygon) {
  var bestSquared = double.infinity;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    final edge = b - a;
    final projection =
        ((point.dx - a.dx) * edge.dx + (point.dy - a.dy) * edge.dy) /
        edge.distanceSquared;
    final nearest = a + edge * projection.clamp(0.0, 1.0);
    bestSquared = math.min(bestSquared, (point - nearest).distanceSquared);
  }
  return math.sqrt(bestSquared);
}
