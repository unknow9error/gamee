import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/artwork_limits.dart';

const maxTracePointsPerStage = ArtworkLimits.maxTotalBrushPoints;

/// Every checkpoint is evidence of an ordered action, never a stored score.
/// Gaps, duplicates and out-of-order indices invalidate the remaining proof.
List<int> orderedCheckpointProof(Object? value, int count) {
  if (value is! List) return [];
  final proof = <int>[];
  for (final entry in value.take(count)) {
    if (entry is! int || entry != proof.length) break;
    proof.add(entry);
  }
  return proof;
}

List<Offset> sampleTracePath(Path path, {double endFraction = 1}) {
  final metrics = path.computeMetrics().toList();
  final total = metrics.fold(0.0, (sum, item) => sum + item.length);
  var remaining = total * endFraction.clamp(0.0, 1.0);
  final points = <Offset>[];
  for (final metric in metrics) {
    final until = math.min(remaining, metric.length);
    for (var distance = 0.0; distance < until; distance += 5) {
      points.add(metric.getTangentForOffset(distance)!.position);
    }
    if (until > 0) {
      points.add(
        metric
            .getTangentForOffset(math.min(until, metric.length - .001))!
            .position,
      );
    }
    remaining -= until;
    if (remaining <= 0) break;
  }
  return points;
}

/// Removes redundant pointer samples while preserving the child's line shape.
/// This is geometric simplification, not truncation of a finished contour.
List<Offset> simplifyTraceStroke(List<Offset> stroke) {
  if (stroke.length < 3) return List.of(stroke);
  final keep = <int>{0, stroke.length - 1};
  final pending = <(int, int)>[(0, stroke.length - 1)];
  while (pending.isNotEmpty) {
    final (first, last) = pending.removeLast();
    var farthest = -1;
    var greatest = 1.1;
    for (var index = first + 1; index < last; index++) {
      final distance = TraceValidator.distanceToSegment(
        stroke[index],
        stroke[first],
        stroke[last],
      );
      if (distance > greatest) {
        greatest = distance;
        farthest = index;
      }
    }
    if (farthest < 0) continue;
    keep.add(farthest);
    pending.add((first, farthest));
    pending.add((farthest, last));
  }
  final indices = keep.toList()..sort();
  final corners = [for (final index in indices) stroke[index]];
  final simplified = <Offset>[corners.first];
  for (var index = 1; index < corners.length; index++) {
    final a = corners[index - 1];
    final b = corners[index];
    final divisions = math.max(1, ((b - a).distance / 28).ceil());
    for (var part = 1; part <= divisions; part++) {
      simplified.add(Offset.lerp(a, b, part / divisions)!);
    }
  }
  if (simplified.length <= ArtworkLimits.maxPointsPerStroke) return simplified;
  return List.generate(
    ArtworkLimits.maxPointsPerStroke,
    (index) =>
        simplified[(index *
                (simplified.length - 1) /
                (ArtworkLimits.maxPointsPerStroke - 1))
            .round()],
  );
}

/// Evaluates the child's actual stroke segments against a vector contour.
/// Coordinates use the artwork's 400-unit view box, independent of screen size.
class TraceEvaluation {
  const TraceEvaluation({
    required this.coverage,
    required this.inCorridor,
    required this.drawnLength,
    required this.targetLength,
    required this.complete,
  });
  final double coverage;
  final double inCorridor;
  final double drawnLength;
  final double targetLength;
  final bool complete;
}

class TraceValidator {
  TraceValidator(
    Path target, {
    this.tolerance = 17,
    this.requiredCoverage = .78,
    this.requiredHorizontalRuns = const [],
    this.minimumPatternHeight = 0,
  }) {
    for (final metric in target.computeMetrics()) {
      if (metric.length < .1) continue;
      final part = <Offset>[];
      final count = math.max(2, (metric.length / 5).ceil());
      for (var index = 0; index <= count; index++) {
        final tangent = metric.getTangentForOffset(
          math.min(metric.length - .001, metric.length * index / count),
        );
        if (tangent != null) part.add(tangent.position);
      }
      _parts.add(part);
      _partLengths.add(metric.length);
      _samples.addAll(part);
    }
  }

  final double tolerance;
  final double requiredCoverage;
  final List<int> requiredHorizontalRuns;
  final double minimumPatternHeight;
  final List<Offset> _samples = [];
  final List<List<Offset>> _parts = [];
  final List<double> _partLengths = [];
  List<Offset> get samples => List.unmodifiable(_samples);
  double get targetLength => _partLengths.fold(0, (sum, value) => sum + value);

  TraceEvaluation evaluate(List<List<Offset>> strokes) {
    var length = 0.0;
    var corridorLength = 0.0;
    final segments = <(Offset, Offset)>[];
    for (final stroke in strokes) {
      for (var index = 1; index < stroke.length; index++) {
        final a = stroke[index - 1];
        final b = stroke[index];
        final distance = (b - a).distance;
        if (!distance.isFinite || distance > 60) continue;
        segments.add((a, b));
        length += distance;
        final midpoint = Offset.lerp(a, b, .5)!;
        if (_samples.any((p) => (p - midpoint).distance <= tolerance * 1.35)) {
          corridorLength += distance;
        }
      }
    }
    bool covered(Offset sample) => segments.any(
      (segment) =>
          distanceToSegment(sample, segment.$1, segment.$2) <= tolerance,
    );
    final hits = _samples.where(covered).length;
    final coverage = _samples.isEmpty ? 0.0 : hits / _samples.length;
    final inCorridor = length == 0 ? 0.0 : corridorLength / length;
    var allPartsVisited = true;
    for (var index = 0; index < _parts.length; index++) {
      if (_partLengths[index] < 10) continue;
      final part = _parts[index];
      if (part.where(covered).length / part.length < .35) {
        allPartsVisited = false;
        break;
      }
    }
    return TraceEvaluation(
      coverage: coverage,
      inCorridor: inCorridor,
      drawnLength: length,
      targetLength: targetLength,
      complete:
          coverage >= requiredCoverage &&
          inCorridor >= .58 &&
          length >= targetLength * .48 &&
          allPartsVisited &&
          _patternSatisfied(strokes) &&
          targetLength > 0,
    );
  }

  bool _patternSatisfied(List<List<Offset>> strokes) {
    if (requiredHorizontalRuns.isEmpty) return true;
    final runs = <int>[];
    var minimumY = double.infinity, maximumY = double.negativeInfinity;
    for (final stroke in strokes) {
      var direction = 0, travel = 0.0;
      for (var index = 1; index < stroke.length; index++) {
        final a = stroke[index - 1], b = stroke[index];
        if ((b - a).distance > 60) continue;
        minimumY = math.min(minimumY, math.min(a.dy, b.dy));
        maximumY = math.max(maximumY, math.max(a.dy, b.dy));
        final delta = b.dx - a.dx;
        if (delta.abs() < .5) continue;
        final sign = delta > 0 ? 1 : -1;
        if (sign == direction) {
          travel += delta.abs();
        } else {
          if (travel >= 14) runs.add(direction);
          direction = sign;
          travel = delta.abs();
        }
      }
      if (travel >= 14) runs.add(direction);
    }
    if (maximumY - minimumY < minimumPatternHeight) return false;
    var expected = 0;
    for (final run in runs) {
      if (run == requiredHorizontalRuns[expected]) expected++;
      if (expected == requiredHorizontalRuns.length) return true;
    }
    return false;
  }

  static double distanceToSegment(Offset point, Offset a, Offset b) {
    final delta = b - a;
    final square = delta.dx * delta.dx + delta.dy * delta.dy;
    if (square == 0) return (point - a).distance;
    final fraction =
        (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) / square)
            .clamp(0.0, 1.0);
    return (point - (a + delta * fraction)).distance;
  }
}

/// Bounded, finite draft decoding. Bad points cannot become phantom progress.
List<List<Offset>> decodeTraceStrokes(Object? value) {
  if (value is! List) return [];
  final result = <List<Offset>>[];
  var pointCount = 0;
  for (final rawStroke in value.take(80)) {
    if (pointCount >= maxTracePointsPerStage) break;
    if (rawStroke is! List) continue;
    final points = <Offset>[];
    for (final rawPoint in rawStroke.take(ArtworkLimits.maxPointsPerStroke)) {
      if (pointCount >= maxTracePointsPerStage) break;
      if (rawPoint is! List ||
          rawPoint.length != 2 ||
          rawPoint[0] is! num ||
          rawPoint[1] is! num) {
        continue;
      }
      final x = (rawPoint[0] as num).toDouble();
      final y = (rawPoint[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite || x < 0 || y < 0 || x > 1 || y > 1) {
        continue;
      }
      points.add(Offset(x * 400, y * 400));
      pointCount++;
    }
    if (points.length > 1) result.add(points);
  }
  return result;
}

List<List<List<double>>> encodeTraceStrokes(List<List<Offset>> strokes) => [
  for (final stroke in strokes)
    [
      for (final point in stroke)
        [
          normalizedTraceCoordinate(point.dx),
          normalizedTraceCoordinate(point.dy),
        ],
    ],
];

double normalizedTraceCoordinate(double coordinate) =>
    double.parse((coordinate / 400).toStringAsFixed(4));
