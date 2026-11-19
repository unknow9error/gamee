import 'dart:ui';
import 'dart:math' as math;

import '../../../content/dots_rope_layouts.dart';

/// The point order, rather than the gesture's length, is the success criterion.
/// A tap is an intentional accessible alternative to dragging between points.
class DotsSession {
  DotsSession(this.layout, {Map<String, dynamic>? saved}) {
    if (saved?['schema'] != 2 ||
        saved?['type'] != 'connectDots' ||
        saved?['revision'] != layout.revision) {
      return;
    }
    final route = saved?['visited'];
    if (route is! List) return;
    for (final value in route.take(layout.points.length)) {
      if (value is! int || value != _visited) break;
      _visited++;
    }
  }
  final DotsLayout layout;
  int _visited = 0;
  int get visited => _visited;
  int get expected => _visited;
  bool get complete => _visited == layout.points.length;
  double get progress => _visited / layout.points.length;

  bool select(int index) {
    if (complete || index != _visited) return false;
    _visited++;
    return true;
  }

  bool selectAt(Offset position, double radius) {
    if (!position.dx.isFinite ||
        !position.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      return false;
    }
    if (complete || (position - layout.points[expected]).distance > radius) {
      return false;
    }
    return select(expected);
  }

  void undo() {
    if (_visited > 0) _visited--;
  }

  void reset() => _visited = 0;
  Map<String, dynamic> toJson() => {
    'schema': 2,
    'version': 2,
    'type': 'connectDots',
    'revision': layout.revision,
    'ageBand': layout.band.name,
    'scene': layout.id,
    'visited': List.generate(_visited, (index) => index),
  };
}

/// Number discs use a minimum 28px packing distance. Thin leaders preserve the
/// exact annotated outline anchors without overlapping labels or shrinking the
/// active tap target into a tiny nearest-neighbour region.
List<Offset> dotLabelPositions(List<Offset> points, double side) {
  final columns = math.max(
    math.sqrt(points.length).ceil(),
    ((side - 26) / 28).floor() + 1,
  );
  final spacing = (side - 26) / (columns - 1);
  final available = <Offset>[
    for (var row = 0; row < columns; row++)
      for (var column = 0; column < columns; column++)
        Offset(13 + column * spacing, 13 + row * spacing),
  ];
  final result = <Offset>[];
  for (final point in points) {
    final anchor = point * side;
    var best = 0;
    var distance = double.infinity;
    for (var index = 0; index < available.length; index++) {
      final candidate = (available[index] - anchor).distanceSquared;
      if (candidate < distance) {
        distance = candidate;
        best = index;
      }
    }
    result.add(available.removeAt(best) / side);
  }
  return result;
}
