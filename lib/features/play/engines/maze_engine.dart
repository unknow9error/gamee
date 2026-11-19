import 'dart:ui';

import '../../../domain/models.dart';

/// Hand-authored corridors in normalized coordinates, registered to the actual
/// ImageGen school and park masters (1254 × 1254, inspected 2026-11-17).
class MazeNetwork {
  MazeNetwork._({
    required this.levelId,
    required this.scene,
    required this.ageBand,
    required this.nodes,
    required this.roads,
    required this.start,
    required this.goal,
    required this.requiredStops,
  });

  static const layoutRevision = 'imagegen-20261117-r1';
  final String levelId;
  final String scene;
  final AgeBand ageBand;
  final List<Offset> nodes;
  final List<MazeRoad> roads;
  final int start;
  final int goal;
  final Set<int> requiredStops;
  String get identity => '$layoutRevision:$scene:${ageBand.name}';

  factory MazeNetwork.forLevel({
    required String levelId,
    required String scene,
    required AgeBand ageBand,
  }) {
    if (scene != 'school' && scene != 'park') {
      throw ArgumentError.value(scene, 'scene', 'Unknown curated maze');
    }
    final park = scene == 'park';
    final nodes = park
        ? const [
            Offset(.25, .77),
            Offset(.35, .67),
            Offset(.28, .51),
            Offset(.40, .38),
            Offset(.39, .22),
            Offset(.58, .28),
            Offset(.71, .20),
            Offset(.70, .39),
            Offset(.77, .48),
            Offset(.59, .53),
            Offset(.46, .65),
            Offset(.63, .70),
            Offset(.70, .79),
            Offset(.47, .82),
            Offset(.67, .61),
          ]
        : const [
            Offset(.34, .87),
            Offset(.46, .78),
            Offset(.32, .65),
            Offset(.35, .49),
            Offset(.30, .35),
            Offset(.47, .30),
            Offset(.63, .34),
            Offset(.78, .28),
            Offset(.72, .46),
            Offset(.55, .48),
            Offset(.48, .63),
            Offset(.65, .67),
            Offset(.72, .79),
            Offset(.52, .89),
            Offset(.71, .58),
          ];
    final goal = park ? 12 : 7;
    MazeRoad road(int a, int b, List<Offset> via, {bool blocked = false}) =>
        MazeRoad(a, b, [nodes[a], ...via, nodes[b]], blocked: blocked);
    final roads = park
        ? [
            road(0, 1, const [Offset(.27, .73), Offset(.31, .69)]),
            road(1, 2, const [Offset(.32, .61), Offset(.28, .56)]),
            road(2, 3, const [Offset(.29, .44), Offset(.34, .40)]),
            road(3, 4, const [Offset(.42, .31), Offset(.40, .26)]),
            road(4, 5, const [Offset(.47, .22), Offset(.53, .25)]),
            road(5, 6, const [Offset(.64, .26), Offset(.68, .23)]),
            road(5, 7, const [Offset(.64, .31), Offset(.68, .35)]),
            road(7, 8, const [Offset(.74, .43)]),
            road(8, 14, const [Offset(.75, .54), Offset(.71, .58)]),
            road(14, 9, const [Offset(.63, .58)]),
            road(9, 3, const [Offset(.53, .46), Offset(.46, .41)]),
            road(9, 10, const [Offset(.53, .57), Offset(.48, .61)]),
            road(10, 1, const [
              Offset(.40, .68),
            ], blocked: ageBand == AgeBand.advanced),
            road(10, 11, const [
              Offset(.54, .66),
            ], blocked: ageBand == AgeBand.advanced),
            road(11, 12, const [Offset(.66, .75)]),
            road(12, 13, const [Offset(.61, .82), Offset(.53, .83)]),
            road(13, 0, const [Offset(.37, .84), Offset(.29, .80)]),
            road(14, 11, const [Offset(.65, .66)]),
          ]
        : [
            road(0, 1, const [Offset(.39, .85), Offset(.44, .82)]),
            road(1, 2, const [Offset(.38, .75), Offset(.34, .70)]),
            road(2, 3, const [Offset(.30, .59), Offset(.32, .53)]),
            road(3, 4, const [Offset(.33, .42)]),
            road(4, 5, const [Offset(.37, .31), Offset(.42, .30)]),
            road(5, 6, const [Offset(.54, .31), Offset(.59, .33)]),
            road(6, 7, const [Offset(.68, .32), Offset(.73, .29)]),
            road(6, 8, const [Offset(.69, .38)]),
            road(8, 14, const [Offset(.74, .52)]),
            road(14, 11, const [Offset(.69, .63)]),
            road(11, 12, const [Offset(.69, .72)]),
            road(12, 13, const [Offset(.66, .85), Offset(.59, .88)]),
            road(13, 0, const [Offset(.43, .92), Offset(.38, .90)]),
            road(1, 10, const [
              Offset(.49, .71),
            ], blocked: ageBand == AgeBand.advanced),
            road(10, 11, const [
              Offset(.56, .65),
            ], blocked: ageBand == AgeBand.advanced),
            road(10, 9, const [Offset(.50, .55)]),
            road(9, 3, const [Offset(.45, .47), Offset(.40, .47)]),
            road(9, 8, const [Offset(.63, .45), Offset(.68, .45)]),
            road(9, 5, const [Offset(.53, .40), Offset(.50, .35)]),
          ];
    List<MazeRoad> selected = roads;
    if (ageBand == AgeBand.preschool) {
      // One real decision with a safe dead end. Long single roads are composed
      // from the same inspected corridor, keeping art and input registered.
      final main = park ? [1, 10, 11, 12] : [1, 10, 9, 8, 6, 7];
      final points = <Offset>[nodes[main.first]];
      for (var i = 1; i < main.length; i++) {
        final segment = roads.firstWhere(
          (r) => r.key == MazeRoad.keyFor(main[i - 1], main[i]),
        );
        points.addAll(
          segment.a == main[i - 1]
              ? segment.points.skip(1)
              : segment.points.reversed.skip(1),
        );
      }
      selected = [
        roads.firstWhere((r) => r.key == '0-1'),
        MazeRoad(1, goal, points),
        roads.firstWhere((r) => r.key == '1-2'),
        MazeRoad(
          2,
          3,
          roads.firstWhere((r) => r.key == '2-3').points,
          blocked: true,
        ),
      ];
    } else if (ageBand == AgeBand.primary) {
      // Preserve genuine cycles while marking one tempting shortcut as works.
      selected = [
        for (final r in roads)
          MazeRoad(
            r.a,
            r.b,
            r.points,
            blocked: r.key == (park ? '0-13' : '5-9'),
          ),
      ];
    }
    return MazeNetwork._(
      levelId: levelId,
      scene: scene,
      ageBand: ageBand,
      nodes: List.unmodifiable(nodes),
      roads: List.unmodifiable(selected),
      start: 0,
      goal: goal,
      requiredStops: ageBand == AgeBand.advanced
          ? (park ? const {6, 8} : const {4, 12})
          : const {},
    );
  }

  Iterable<MazeRoad> roadsFrom(int node) =>
      roads.where((r) => !r.blocked && (r.a == node || r.b == node));
  MazeRoad? roadBetween(int a, int b) {
    for (final road in roads) {
      if (road.key == MazeRoad.keyFor(a, b)) {
        return road;
      }
    }
    return null;
  }

  List<int> routeTo(int from, int target) {
    final queue = <int>[from];
    final previous = <int, int?>{from: null};
    for (var i = 0; i < queue.length; i++) {
      final current = queue[i];
      if (current == target) {
        break;
      }
      for (final road in roadsFrom(current)) {
        final next = road.other(current);
        if (previous.containsKey(next)) {
          continue;
        }
        previous[next] = current;
        queue.add(next);
      }
    }
    if (!previous.containsKey(target)) {
      return [];
    }
    final route = <int>[target];
    while (route.last != from) {
      route.add(previous[route.last]!);
    }
    return route.reversed.toList(growable: false);
  }

  List<int> routeToGoal(int from) => routeTo(from, goal);
}

class MazeRoad {
  MazeRoad(this.a, this.b, List<Offset> points, {this.blocked = false})
    : points = List.unmodifiable(points) {
    if (points.length < 2) {
      throw ArgumentError('A corridor needs two points');
    }
    var length = 0.0;
    _lengths = [0];
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
      _lengths.add(length);
    }
    _totalLength = length;
  }
  final int a, b;
  final List<Offset> points;
  final bool blocked;
  late final List<double> _lengths;
  late final double _totalLength;
  String get key => keyFor(a, b);
  static String keyFor(int a, int b) => a < b ? '$a-$b' : '$b-$a';
  int other(int node) => node == a ? b : a;
  Offset point(double t) {
    final target = t.clamp(0.0, 1.0) * _totalLength;
    for (var i = 1; i < points.length; i++) {
      if (_lengths[i] >= target) {
        final segment = _lengths[i] - _lengths[i - 1];
        return Offset.lerp(
          points[i - 1],
          points[i],
          segment == 0 ? 0 : (target - _lengths[i - 1]) / segment,
        )!;
      }
    }
    return points.last;
  }

  Path get path => Path()..addPolygon(points, false);
}

enum MazeMove { ignored, moving, arrived, blocked, needsStops, completed }

/// Replays the legal route to derive collected stops. Saved reward flags are
/// never trusted, and age/map/level changes cannot inherit a solved draft.
class MazeSession {
  MazeSession(this.network, {Map<String, dynamic>? saved})
    : route = [network.start] {
    if (saved?['version'] != 2 ||
        saved?['type'] != 'maze' ||
        saved?['levelId'] != network.levelId ||
        saved?['layoutId'] != network.identity ||
        saved?['ageBand'] != network.ageBand.name) {
      return;
    }
    final stored = saved?['route'];
    if (stored is! List || stored.isEmpty || stored.first != network.start) {
      return;
    }
    for (final next in stored.skip(1).take(2000)) {
      if (next is! int || next < 0 || next >= network.nodes.length) {
        break;
      }
      final road = network.roadBetween(route.last, next);
      if (road == null || road.blocked) {
        break;
      }
      route.add(next);
      if (isComplete) {
        break;
      }
    }
  }
  final MazeNetwork network;
  final List<int> route;
  MazeRoad? _active;
  double _progress = 0;
  bool _dragging = false;
  int get current => route.last;
  Set<int> get collectedStops =>
      network.requiredStops.intersection(route.toSet());
  bool get allStopsCollected =>
      collectedStops.length == network.requiredStops.length;
  bool get isComplete => current == network.goal && allStopsCollected;
  bool get isDragging => _dragging;
  Offset get busPosition =>
      _active?.point(current == _active!.a ? _progress : 1 - _progress) ??
      network.nodes[current];
  MazeRoad? get activeRoad => _active;
  double get edgeProgress => _progress;
  Map<String, dynamic> toJson() => {
    'version': 2,
    'type': 'maze',
    'levelId': network.levelId,
    'layoutId': network.identity,
    'ageBand': network.ageBand.name,
    'route': List<int>.of(route),
    'position': [network.nodes[current].dx, network.nodes[current].dy],
  };

  /// Breadth-first planning in (node, collected-stop-mask) state space. A hint
  /// can never direct an advanced child to an invalid premature finish.
  List<int> get hintRoute {
    final stops = network.requiredStops.toList()..sort();
    int maskFor(int node) =>
        !stops.contains(node) ? 0 : 1 << stops.indexOf(node);
    var initial = 0;
    for (final node in route) {
      initial |= maskFor(node);
    }
    final goalMask = (1 << stops.length) - 1;
    final start = (current, initial);
    final queue = <(int, int)>[start];
    final previous = <(int, int), (int, int)?>{start: null};
    (int, int)? end;
    for (var i = 0; i < queue.length; i++) {
      final state = queue[i];
      if (state.$1 == network.goal && state.$2 == goalMask) {
        end = state;
        break;
      }
      for (final road in network.roadsFrom(state.$1)) {
        final next = road.other(state.$1);
        final nextState = (next, state.$2 | maskFor(next));
        if (previous.containsKey(nextState)) {
          continue;
        }
        previous[nextState] = state;
        queue.add(nextState);
      }
    }
    if (end == null) {
      return [];
    }
    final result = <(int, int)>[end];
    while (result.last != start) {
      result.add(previous[result.last]!);
    }
    return result.reversed.map((s) => s.$1).toList(growable: false);
  }

  bool beginDrag(Offset point) {
    if (isComplete || (point - busPosition).distance > .085) {
      return false;
    }
    _dragging = true;
    return true;
  }

  MazeMove dragTo(Offset point) {
    if (!_dragging || isComplete) {
      return MazeMove.ignored;
    }
    MazeRoad? nearest = _active;
    var best = double.infinity;
    var progress = _progress;
    final candidates = nearest == null ? network.roadsFrom(current) : [nearest];
    for (final road in candidates) {
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        final p = current == road.a ? t : 1 - t;
        if ((p - _progress).abs() > .20) {
          continue;
        }
        final distance = (point - road.point(t)).distance;
        if (distance < best) {
          best = distance;
          nearest = road;
          progress = p;
        }
      }
    }
    if (nearest == null || best > .055) {
      return MazeMove.ignored;
    }
    if (progress < .025 && _active == null) {
      return MazeMove.moving;
    }
    _active = nearest;
    _progress = progress;
    if (_progress >= .97) {
      route.add(nearest.other(current));
      _active = null;
      _progress = 0;
      return _arrival();
    }
    return MazeMove.moving;
  }

  MazeMove _arrival() => isComplete
      ? MazeMove.completed
      : current == network.goal
      ? MazeMove.needsStops
      : MazeMove.arrived;
  MazeMove tapNode(int node) {
    if (isComplete || node == current) {
      return MazeMove.ignored;
    }
    final road = network.roadBetween(current, node);
    if (road == null) {
      return MazeMove.ignored;
    }
    if (road.blocked) {
      return MazeMove.blocked;
    }
    route.add(node);
    _active = null;
    _progress = 0;
    return _arrival();
  }

  void endDrag() {
    _active = null;
    _progress = 0;
    _dragging = false;
  }

  void undo() {
    endDrag();
    if (route.length > 1) {
      route.removeLast();
    }
  }

  void reset() {
    endDrag();
    route
      ..clear()
      ..add(network.start);
  }
}
