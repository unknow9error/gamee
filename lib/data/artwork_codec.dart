import '../domain/artwork_limits.dart';

/// Compacts oversampled brush paths, retaining every stroke and its endpoints.
/// Shared budgets apply to the engine as well as drafts created before a save.
Map<String, dynamic> compactBrushArtwork(Map<String, dynamic> data) {
  final rawStrokes = data['strokes'];
  if (rawStrokes is! List) return data;
  if (rawStrokes.length > ArtworkLimits.maxBrushStrokes) {
    throw const FormatException('Artwork has too many strokes');
  }
  final strokes = <Map<String, dynamic>>[];
  for (final raw in rawStrokes) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) return data;
    final points = raw['points'];
    if (points is! List ||
        points.any(
          (point) =>
              point is! List ||
              point.length != 2 ||
              point[0] is! num ||
              point[1] is! num,
        )) {
      return data;
    }
    strokes.add({
      ...Map<String, dynamic>.from(raw),
      'points': _simplify(points, ArtworkLimits.maxPointsPerStroke),
    });
  }
  final total = strokes.fold<int>(
    0,
    (sum, stroke) => sum + (stroke['points'] as List).length,
  );
  if (total > ArtworkLimits.maxTotalBrushPoints) {
    // Each stroke gets a proportional share. No complete painted mark is lost.
    var remainingBudget = ArtworkLimits.maxTotalBrushPoints;
    var remainingPoints = total;
    for (var i = 0; i < strokes.length; i++) {
      final points = strokes[i]['points'] as List;
      final minimumForRest = strokes
          .skip(i + 1)
          .fold<int>(
            0,
            (sum, stroke) =>
                sum +
                ((stroke['points'] as List).length < 2
                    ? (stroke['points'] as List).length
                    : 2),
          );
      final share = remainingPoints == 0
          ? 0
          : (points.length * remainingBudget / remainingPoints).floor();
      final minimum = points.length <= 1 ? points.length : 2;
      final budget = share.clamp(minimum, remainingBudget - minimumForRest);
      strokes[i]['points'] = _simplify(points, budget);
      remainingBudget -= (strokes[i]['points'] as List).length;
      remainingPoints -= points.length;
    }
  }
  return {...data, 'strokes': strokes};
}

List<List<double>> _simplify(List raw, int budget) {
  final points = <List<double>>[
    for (final point in raw)
      [
        double.parse((point[0] as num).toDouble().toStringAsFixed(4)),
        double.parse((point[1] as num).toDouble().toStringAsFixed(4)),
      ],
  ];
  if (points.length <= budget) return points;
  var tolerance = 0.0006;
  var simplified = points;
  for (var pass = 0; pass < 16 && simplified.length > budget; pass++) {
    simplified = _douglasPeucker(points, tolerance * tolerance);
    tolerance *= 1.7;
  }
  if (simplified.length <= budget) return simplified;
  // A pathological zigzag still has a bounded representation with endpoints.
  return List.generate(
    budget,
    (i) => simplified[(i * (simplified.length - 1) / (budget - 1)).round()],
  );
}

List<List<double>> _douglasPeucker(
  List<List<double>> points,
  double toleranceSquared,
) {
  if (points.length < 3) return points;
  final keep = <int>{0, points.length - 1};
  final pending = <(int, int)>[(0, points.length - 1)];
  while (pending.isNotEmpty) {
    final (start, end) = pending.removeLast();
    final a = points[start], b = points[end];
    final dx = b[0] - a[0], dy = b[1] - a[1];
    final lengthSquared = dx * dx + dy * dy;
    var farthest = -1;
    var largestDistance = toleranceSquared;
    for (var i = start + 1; i < end; i++) {
      final point = points[i];
      final t = lengthSquared == 0
          ? 0.0
          : (((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / lengthSquared)
                .clamp(0.0, 1.0);
      final distanceX = point[0] - a[0] - t * dx;
      final distanceY = point[1] - a[1] - t * dy;
      final distance = distanceX * distanceX + distanceY * distanceY;
      if (distance > largestDistance) {
        largestDistance = distance;
        farthest = i;
      }
    }
    if (farthest >= 0) {
      keep.add(farthest);
      pending.add((start, farthest));
      pending.add((farthest, end));
    }
  }
  final indices = keep.toList()..sort();
  return [for (final i in indices) points[i]];
}
