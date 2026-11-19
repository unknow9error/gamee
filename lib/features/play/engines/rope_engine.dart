import 'dart:math' as math;
import 'dart:ui';

import '../../../content/dots_rope_layouts.dart';
import '../../../domain/models.dart';

enum RopeMove { ignored, moved, checkpoint, routeComplete, complete }

/// Continuous motor input and ordered symbol decisions have separate contracts.
/// Preschool may tap the next stop; advanced routes pause at three mandatory
/// stops until the matching symbol is explicitly chosen. Hints never mutate it.
class RopeSession {
  RopeSession(this.layout, {Map<String, dynamic>? saved}) {
    _histories.add([0]);
    _confirmed.add([]);
    if (saved?['schema'] != 2 ||
        saved?['type'] != 'ropeTrace' ||
        saved?['revision'] != layout.revision) {
      return;
    }
    final rawRoutes = saved?['routes'];
    final rawChoices = saved?['confirmed'];
    if (rawRoutes is! List) return;
    _histories.clear();
    _confirmed.clear();
    for (
      var routeIndex = 0;
      routeIndex < math.min(rawRoutes.length, layout.routes.length);
      routeIndex++
    ) {
      final raw = rawRoutes[routeIndex];
      if (raw is! List || raw.isEmpty || raw.first != 0) break;
      final choices = <String>[];
      if (layout.band == AgeBand.advanced &&
          rawChoices is List &&
          rawChoices.length > routeIndex &&
          rawChoices[routeIndex] is List) {
        final expected = layout.routes[routeIndex].symbols;
        for (final value in (rawChoices[routeIndex] as List).take(
          expected.length,
        )) {
          if (value != expected[choices.length]) break;
          choices.add(value as String);
        }
      }
      final history = <int>[0];
      for (final value in raw.skip(1).take(1000)) {
        if (value is! int || value < history.last || value > 160) break;
        final delta = value - history.last;
        final tap =
            layout.band == AgeBand.preschool &&
            _checkpoints.firstWhere(
                  (p) => p > history.last,
                  orElse: () => 160,
                ) ==
                value;
        if (delta > maxAdvance && !tap) break;
        if (layout.band == AgeBand.advanced &&
            choices.length < 3 &&
            value > _checkpoints[choices.length + 1]) {
          break;
        }
        history.add(value);
      }
      final reachedChoices = choices
          .takeWhile(
            (choice) =>
                history.contains(_checkpoints[choices.indexOf(choice) + 1]),
          )
          .toList();
      if (layout.band == AgeBand.advanced && reachedChoices.length < 3) {
        history.removeWhere(
          (point) => point > _checkpoints[reachedChoices.length + 1],
        );
      }
      _histories.add(history);
      _confirmed.add(reachedChoices);
      if (history.last != 160) break;
    }
    if (_histories.isEmpty) {
      _histories.add([0]);
      _confirmed.add([]);
    }
    if (_histories.last.last == 160 &&
        _histories.length < layout.routes.length) {
      _histories.add([0]);
      _confirmed.add([]);
    }
  }

  static const maxAdvance = 16;
  final RopeLayout layout;
  final List<List<int>> _histories = [];
  final List<List<String>> _confirmed = [];
  bool _dragging = false;
  List<int> get _checkpoints => switch (layout.band) {
    AgeBand.preschool => const [0, 40, 80, 120, 160],
    AgeBand.primary => const [0, 32, 64, 96, 128, 160],
    AgeBand.advanced => const [0, 40, 80, 120, 160],
  };
  List<int> get checkpoints => List.unmodifiable(_checkpoints);
  int get routeIndex => _histories.length - 1;
  RopeRoute get route => layout.routes[routeIndex];
  int get positionIndex => _histories.last.last;
  Offset get position => route.samples[positionIndex];
  bool get complete =>
      _histories.length == layout.routes.length &&
      positionIndex == 160 &&
      (layout.band != AgeBand.advanced || _confirmed.last.length == 3);
  int get completedRoutes => complete ? layout.routes.length : routeIndex;
  int get nextCheckpoint =>
      _checkpoints.firstWhere((p) => p > positionIndex, orElse: () => 160);
  bool get awaitingSymbol =>
      layout.band == AgeBand.advanced &&
      !complete &&
      _confirmed.last.length < 3 &&
      positionIndex == _checkpoints[_confirmed.last.length + 1];
  String? get requiredSymbol =>
      awaitingSymbol ? route.symbols[_confirmed.last.length] : null;
  List<String> get confirmedSymbols => List.unmodifiable(_confirmed.last);
  double get progress =>
      (completedRoutes + (complete ? 0 : positionIndex / 160)) /
      layout.routes.length;
  List<List<int>> get histories => [
    for (final h in _histories) List.unmodifiable(h),
  ];

  bool begin(Offset point, double radius) {
    if (!point.dx.isFinite ||
        !point.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      return false;
    }
    if (complete || (point - position).distance > radius) return false;
    _dragging = true;
    return true;
  }

  RopeMove move(Offset point, double radius) {
    if (!_dragging ||
        complete ||
        awaitingSymbol ||
        !point.dx.isFinite ||
        !point.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      return RopeMove.ignored;
    }
    var nearest = -1;
    var distance = radius;
    var limit = math.min(160, positionIndex + maxAdvance);
    if (layout.band == AgeBand.advanced && _confirmed.last.length < 3) {
      limit = math.min(limit, _checkpoints[_confirmed.last.length + 1]);
    }
    for (var index = positionIndex; index <= limit; index++) {
      final candidate = (point - route.samples[index]).distance;
      if (candidate < distance) {
        distance = candidate;
        nearest = index;
      }
    }
    if (nearest <= positionIndex) return RopeMove.ignored;
    final before = positionIndex;
    _histories.last.add(nearest);
    return _afterMove(before);
  }

  RopeMove tapCheckpoint(int checkpoint) {
    if (layout.band != AgeBand.preschool ||
        complete ||
        checkpoint != nextCheckpoint) {
      return RopeMove.ignored;
    }
    final before = positionIndex;
    _histories.last.add(checkpoint);
    return _afterMove(before);
  }

  RopeMove confirmWaypoint(String symbol) {
    if (!awaitingSymbol || symbol != requiredSymbol) return RopeMove.ignored;
    _confirmed.last.add(symbol);
    return RopeMove.checkpoint;
  }

  RopeMove _afterMove(int before) {
    if (positionIndex == 160) {
      _dragging = false;
      if (_histories.length == layout.routes.length) return RopeMove.complete;
      _histories.add([0]);
      _confirmed.add([]);
      return RopeMove.routeComplete;
    }
    return _checkpoints.any((p) => p > before && p <= positionIndex)
        ? RopeMove.checkpoint
        : RopeMove.moved;
  }

  void end() => _dragging = false;
  void undo() {
    _dragging = false;
    if (_histories.last.length > 1) {
      final previousCheckpoint = _checkpoints.lastWhere(
        (p) => p < positionIndex,
        orElse: () => 0,
      );
      _histories.last.removeWhere((p) => p > previousCheckpoint);
      if (_histories.last.isEmpty) _histories.last.add(0);
      while (_confirmed.last.isNotEmpty &&
          _checkpoints[_confirmed.last.length] > positionIndex) {
        _confirmed.last.removeLast();
      }
    } else if (_histories.length > 1) {
      _histories.removeLast();
      _confirmed.removeLast();
      _histories.last.removeLast();
    }
  }

  void reset() {
    _dragging = false;
    _histories
      ..clear()
      ..add([0]);
    _confirmed
      ..clear()
      ..add([]);
  }

  Map<String, dynamic> toJson() => {
    'schema': 2,
    'version': 2,
    'type': 'ropeTrace',
    'revision': layout.revision,
    'ageBand': layout.band.name,
    'scene': layout.id,
    'routes': histories,
    'confirmed': [for (final c in _confirmed) List<String>.of(c)],
  };
}
