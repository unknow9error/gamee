import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/engines/maze_engine.dart';

const _scenes = [
  (levelId: 'v2_08', scene: 'school'),
  (levelId: 'v2_18', scene: 'park'),
];

MazeNetwork _network(String scene, AgeBand ageBand) => MazeNetwork.forLevel(
  levelId: scene == 'school' ? 'v2_08' : 'v2_18',
  scene: scene,
  ageBand: ageBand,
);

List<MazeMove> _walk(MazeSession session, Iterable<int> nodes) => [
  for (final node in nodes) session.tapNode(node),
];

void _expectLegalRoute(MazeNetwork maze, List<int> route) {
  expect(route, isNotEmpty);
  for (var index = 1; index < route.length; index++) {
    final road = maze.roadBetween(route[index - 1], route[index]);
    expect(road, isNotNull, reason: 'A route cannot jump over a junction.');
    expect(road!.blocked, isFalse, reason: 'A route cannot cross road works.');
  }
}

void main() {
  group('six curated age-aware configurations', () {
    for (final specification in _scenes) {
      for (final ageBand in AgeBand.values) {
        final name = '${specification.scene} / ${ageBand.name}';

        test('$name can be solved fresh and after a halfway restore', () {
          final maze = _network(specification.scene, ageBand);
          final session = MazeSession(maze);
          final solution = session.hintRoute;
          expect(solution.first, maze.start);
          expect(solution.last, maze.goal);
          _expectLegalRoute(maze, solution);
          expect(solution.toSet(), containsAll(maze.requiredStops));
          final halfway = solution.length ~/ 2;
          _walk(session, solution.skip(1).take(halfway));
          expect(session.isComplete, isFalse);
          final saved = session.toJson();
          expect(saved['version'], 2);
          expect(saved['levelId'], specification.levelId);
          expect(saved['layoutId'], maze.identity);
          expect(saved['ageBand'], ageBand.name);
          expect(saved['position'], [
            maze.nodes[session.current].dx,
            maze.nodes[session.current].dy,
          ]);
          final restored = MazeSession(maze, saved: saved);
          expect(restored.route, session.route);
          expect(restored.collectedStops, session.collectedStops);
          expect(restored.busPosition, session.busPosition);
          final remaining = restored.hintRoute;
          expect(remaining.first, restored.current);
          _expectLegalRoute(maze, remaining);
          final moves = _walk(restored, remaining.skip(1));
          expect(moves.last, MazeMove.completed);
          expect(restored.isComplete, isTrue);
          expect(restored.allStopsCollected, isTrue);
          final completedRestore = MazeSession(maze, saved: restored.toJson());
          expect(completedRestore.isComplete, isTrue);
          expect(completedRestore.route, restored.route);
          expect(completedRestore.tapNode(maze.start), MazeMove.ignored);
        });

        test(
          '$name has normalized geometry and no duplicate road identities',
          () {
            final maze = _network(specification.scene, ageBand);
            expect(
              maze.roads.map((road) => road.key).toSet().length,
              maze.roads.length,
            );
            for (final point in [
              ...maze.nodes,
              for (final road in maze.roads) ...road.points,
            ]) {
              expect(point.dx.isFinite && point.dy.isFinite, isTrue);
              expect(point.dx, inInclusiveRange(0, 1));
              expect(point.dy, inInclusiveRange(0, 1));
            }
            for (final road in maze.roads) {
              expect(road.points.first, maze.nodes[road.a]);
              expect(road.points.last, maze.nodes[road.b]);
              expect(road.point(0), road.points.first);
              expect(road.point(1), road.points.last);
            }
          },
        );

        test('$name refuses teleportation and blocked roads', () {
          final maze = _network(specification.scene, ageBand);
          final session = MazeSession(maze);
          expect(session.tapNode(maze.goal), MazeMove.ignored);
          expect(session.beginDrag(maze.nodes[maze.goal]), isFalse);
          expect(session.beginDrag(session.busPosition), isTrue);
          final original = session.busPosition;
          expect(session.dragTo(const Offset(1.8, -1)), MazeMove.ignored);
          expect(session.busPosition, original);
          session.endDrag();
          final endpoints = maze.roads
              .where((road) => road.blocked)
              .expand((road) => [(road.a, road.b), (road.b, road.a)])
              .firstWhere((edge) {
                final approach = maze.routeTo(maze.start, edge.$1);
                return approach.isNotEmpty && !approach.contains(maze.goal);
              });
          final approach = maze.routeTo(maze.start, endpoints.$1);
          _expectLegalRoute(maze, approach);
          _walk(session, approach.skip(1));
          expect(session.isComplete, isFalse);
          final before = List<int>.of(session.route);
          expect(session.tapNode(endpoints.$2), MazeMove.blocked);
          expect(session.route, before);
          expect(session.current, endpoints.$1);
        });

        test(
          '$name accepts continuous finger traversal of its real corridors',
          () {
            final maze = _network(specification.scene, ageBand);
            final session = MazeSession(maze);
            final solution = session.hintRoute;
            expect(session.beginDrag(session.busPosition), isTrue);
            for (var index = 1; index < solution.length; index++) {
              final from = solution[index - 1];
              final to = solution[index];
              final road = maze.roadBetween(from, to)!;
              final forward = road.a == from;
              for (var sample = 1; sample <= 50; sample++) {
                final fraction = sample / 50;
                session.dragTo(road.point(forward ? fraction : 1 - fraction));
              }
              expect(session.current, to);
              expect(session.isComplete, index == solution.length - 1);
            }
            expect(session.isComplete, isTrue);
            expect(session.collectedStops, maze.requiredStops);
            session.endDrag();
            expect(session.busPosition, maze.nodes[maze.goal]);
            expect(session.isDragging, isFalse);
          },
        );
      }
    }
  });

  group('age adaptation changes reasoning rather than input precision', () {
    for (final specification in _scenes) {
      test(
        '${specification.scene}: preschool has one decision, primary has cycles',
        () {
          final preschool = _network(specification.scene, AgeBand.preschool);
          final primary = _network(specification.scene, AgeBand.primary);
          final preschoolNodes = {
            preschool.start,
            for (final road in preschool.roads.where(
              (road) => !road.blocked,
            )) ...[road.a, road.b],
          };
          final junctions = preschoolNodes.where(
            (node) => preschool.roadsFrom(node).length > 2,
          );
          expect(junctions.length, 1);
          expect(preschoolNodes.length, lessThanOrEqualTo(4));
          expect(preschool.requiredStops, isEmpty);
          expect(primary.requiredStops, isEmpty);
          final open = primary.roads.where((road) => !road.blocked).toList();
          final primaryNodes = {
            for (final road in open) ...[road.a, road.b],
          };
          for (final node in primaryNodes) {
            expect(primary.routeTo(primary.start, node), isNotEmpty);
          }
          expect(
            open.length - primaryNodes.length + 1,
            greaterThan(0),
            reason: 'The older child must see actual alternate routes, not a tree with more dots.',
          );
          expect(primaryNodes.length, greaterThan(preschoolNodes.length));
        },
      );
    }
  });

  group('advanced pickup-aware planning', () {
    for (final specification in _scenes) {
      test(
        '${specification.scene}: early goal stays playable and hints collect all stops',
        () {
          final maze = _network(specification.scene, AgeBand.advanced);
          final session = MazeSession(maze);
          expect(maze.requiredStops.length, 2);
          final earlyGoal = maze.routeToGoal(maze.start);
          final moves = _walk(session, earlyGoal.skip(1));
          expect(session.current, maze.goal);
          expect(session.allStopsCollected, isFalse);
          expect(session.isComplete, isFalse);
          expect(moves.last, MazeMove.needsStops);
          final restored = MazeSession(maze, saved: session.toJson());
          expect(restored.current, maze.goal);
          expect(restored.isComplete, isFalse);
          final hint = restored.hintRoute;
          expect(hint.first, maze.goal);
          expect(hint.length, greaterThan(2));
          expect({...restored.route, ...hint}, containsAll(maze.requiredStops));
          _expectLegalRoute(maze, hint);
          _walk(restored, hint.skip(1));
          expect(restored.isComplete, isTrue);
        },
      );

      test(
        '${specification.scene}: undo and reset derive pickups from the legal route',
        () {
          final maze = _network(specification.scene, AgeBand.advanced);
          final session = MazeSession(maze);
          final stop = maze.requiredStops.first;
          final route = maze.routeTo(maze.start, stop);
          _walk(session, route.skip(1));
          expect(session.collectedStops, contains(stop));
          session.undo();
          expect(session.collectedStops, isNot(contains(stop)));
          expect(session.isComplete, isFalse);
          final last = session.route.last;
          expect(session.tapNode(stop), MazeMove.arrived);
          expect(session.collectedStops, contains(stop));
          expect(session.route[session.route.length - 2], last);
          session.reset();
          expect(session.route, [maze.start]);
          expect(session.collectedStops, isEmpty);
          expect(session.isDragging, isFalse);
        },
      );
    }
  });

  group('saved state is tied to the actual curated layout', () {
    final maze = _network('school', AgeBand.advanced);
    Map<String, dynamic> partialSave() {
      final session = MazeSession(maze);
      session.tapNode(1);
      return session.toJson();
    }

    for (final entry in <String, dynamic>{
      'version': 1,
      'type': 'different-activity',
      'levelId': 'v2_18',
      'layoutId': 'imagegen-old-layout:school:advanced',
      'ageBand': AgeBand.preschool.name,
    }.entries) {
      test('a foreign ${entry.key} cannot inherit route or completion', () {
        final saved = partialSave()..[entry.key] = entry.value;
        final restored = MazeSession(maze, saved: saved);
        expect(restored.route, [maze.start]);
        expect(restored.collectedStops, isEmpty);
        expect(restored.isComplete, isFalse);
      });
    }

    test('forged position and reward flags never override route replay', () {
      final saved = partialSave()
        ..['position'] = [maze.nodes[maze.goal].dx, maze.nodes[maze.goal].dy]
        ..['collectedStops'] = maze.requiredStops.toList()
        ..['complete'] = true;
      final restored = MazeSession(maze, saved: saved);
      expect(restored.route, [maze.start, 1]);
      expect(restored.busPosition, maze.nodes[1]);
      expect(restored.collectedStops, isEmpty);
      expect(restored.isComplete, isFalse);
    });

    test('a damaged tail preserves only its legal prefix', () {
      for (final invalid in [-1, 900, '7', null]) {
        final saved = partialSave()
          ..['route'] = [maze.start, 1, invalid, maze.goal];
        final restored = MazeSession(maze, saved: saved);
        expect(restored.route, [maze.start, 1]);
        expect(restored.isComplete, isFalse);
      }
      final wrongStart = partialSave()..['route'] = [maze.goal];
      expect(MazeSession(maze, saved: wrongStart).route, [maze.start]);
    });

    test('a blocked saved edge cannot confer progress beyond its endpoint', () {
      final blocked = maze.roads.firstWhere((road) => road.blocked);
      final route = maze.routeTo(maze.start, blocked.a);
      final saved = partialSave()..['route'] = [...route, blocked.b, maze.goal];
      final restored = MazeSession(maze, saved: saved);
      expect(restored.route, route);
      expect(restored.current, blocked.a);
      expect(restored.isComplete, isFalse);
    });

    test('same-age draft is rejected when the level or scene changes', () {
      final saved = partialSave();
      final otherLevel = MazeNetwork.forLevel(
        levelId: 'another-school-level',
        scene: 'school',
        ageBand: AgeBand.advanced,
      );
      final otherScene = _network('park', AgeBand.advanced);
      expect(MazeSession(otherLevel, saved: saved).route, [otherLevel.start]);
      expect(MazeSession(otherScene, saved: saved).route, [otherScene.start]);
    });
  });
}
