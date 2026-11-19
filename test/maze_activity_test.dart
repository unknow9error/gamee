import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/engines/maze_engine.dart';
import 'package:tiny_trails/features/play/maze_activity.dart';

const _level = LevelDefinition(
  id: 'maze-test',
  worldId: 'ocean',
  kind: ActivityKind.maze,
  scene: 'school',
  illustrationAsset: 'assets/images/levels/08-school.png',
  variant: 0,
  difficulty: 1,
  title: LocalizedText('Дорога', 'Жол', 'Road'),
  instruction: LocalizedText('Веди', 'Жүр', 'Go'),
  order: 0,
);

void main() {
  testWidgets('changing age resets the route while preserving 48 dp controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saves = <Map<String, dynamic>>[];
    Widget app(int age, {Map<String, dynamic>? saved}) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: MazeActivity(
          config: ActivityConfig(
            level: _level,
            language: 'ru',
            childAge: age,
            initialData: saved,
            onChanged: saves.add,
            onCompleted: (_) {},
            onFeedback: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(7));
    await tester.tap(find.byKey(const ValueKey('maze-node-1')));
    await tester.pump();
    expect(saves.last['route'], [0, 1]);
    for (final age in [4, 10]) {
      await tester.pumpWidget(app(age, saved: saves.last));
      final map = tester.getRect(find.byKey(const ValueKey('maze-canvas')));
      expect(
        tester.getCenter(find.byKey(const ValueKey('maze-player'))),
        map.topLeft + const Offset(.34, .87) * map.width,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('maze-node-1'))),
        const Size(48, 48),
      );
      expect(map.size.shortestSide, greaterThanOrEqualTo(220));
    }
    expect(tester.takeException(), isNull);
  });
  for (final scene in ['school', 'park']) {
    testWidgets(
      '$scene displays its ImageGen master and requires advanced stops',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final asset = scene == 'school'
            ? 'assets/images/levels/08-school.png'
            : 'assets/images/levels/18-park.png';
        final level = LevelDefinition(
          id: 'art-$scene',
          worldId: 'forest',
          kind: ActivityKind.maze,
          scene: scene,
          variant: 0,
          difficulty: 1,
          title: const LocalizedText('', '', ''),
          instruction: const LocalizedText('', '', ''),
          order: 0,
          illustrationAsset: asset,
        );
        final saves = <Map<String, dynamic>>[];
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: MazeActivity(
                config: ActivityConfig(
                  level: level,
                  language: 'ru',
                  childAge: 10,
                  showHint: true,
                  onChanged: saves.add,
                  onCompleted: (_) => completions++,
                  onFeedback: () {},
                ),
              ),
            ),
          ),
        );
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('maze-canvas')),
            matching: find.byType(Image),
          ),
        );
        expect((image.image as AssetImage).assetName, asset);
        expect(completions, 0);
        expect(saves, isEmpty, reason: 'A hint never performs a child action.');
        final maze = MazeNetwork.forLevel(
          levelId: level.id,
          scene: scene,
          ageBand: AgeBand.advanced,
        );
        final map = tester.getRect(find.byKey(const ValueKey('maze-canvas')));
        Future<void> tapRoute(Iterable<int> nodes) async {
          for (final node in nodes) {
            await tester.tapAt(map.topLeft + maze.nodes[node] * map.width);
            await tester.pump();
          }
        }

        await tapRoute(maze.routeToGoal(maze.start).skip(1));
        expect(completions, 0);
        expect(
          find.textContaining('Сначала собери оба флажка'),
          findsOneWidget,
        );
        final resumed = MazeSession(maze, saved: saves.last);
        await tapRoute(resumed.hintRoute.skip(1));
        expect(completions, 1);
        expect(saves.last['ageBand'], 'advanced');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a persisted arrival recovers completion once after rebuilding', (
    tester,
  ) async {
    final network = MazeNetwork.forLevel(
      levelId: _level.id,
      scene: 'school',
      ageBand: AgeBand.primary,
    );
    final solved = MazeSession(network);
    for (final node in solved.hintRoute.skip(1)) {
      solved.tapNode(node);
    }
    final saved = solved.toJson();
    var completions = 0;
    Widget app(String language) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: MazeActivity(
          config: ActivityConfig(
            level: _level,
            language: language,
            initialData: saved,
            onChanged: (_) {},
            onCompleted: (data) {
              completions++;
              expect(data['route'], saved['route']);
            },
            onFeedback: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app('ru'));
    expect(completions, 1);
    await tester.pumpWidget(app('kk'));
    await tester.pump();
    expect(completions, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dragging follows a road through the real gesture recognizer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saves = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: MazeActivity(
            config: ActivityConfig(
              level: _level,
              language: 'en',
              onChanged: saves.add,
              onCompleted: (_) {},
              onFeedback: () {},
            ),
          ),
        ),
      ),
    );
    final maze = MazeNetwork.forLevel(
      levelId: _level.id,
      scene: 'school',
      ageBand: AgeBand.primary,
    );
    final next = maze.routeToGoal(maze.start)[1];
    final road = maze.roadBetween(maze.start, next)!;
    final map = tester.getRect(find.byKey(const ValueKey('maze-canvas')));
    Offset point(Offset p) => map.topLeft + p * map.width;
    final gesture = await tester.startGesture(point(maze.nodes[maze.start]));
    for (var i = 1; i <= 30; i++) {
      await gesture.moveTo(
        point(road.point(road.a == maze.start ? i / 30 : 1 - i / 30)),
      );
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    expect(saves.last['route'], [maze.start, next]);
  });
  testWidgets(
    'maze tap route validates each junction and saves only legal progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var completions = 0;
      final saves = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SafeArea(
              child: MazeActivity(
                config: ActivityConfig(
                  level: _level,
                  language: 'ru',
                  onChanged: saves.add,
                  onCompleted: (_) => completions++,
                  onFeedback: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final maze = MazeNetwork.forLevel(
        levelId: _level.id,
        scene: 'school',
        ageBand: AgeBand.primary,
      );
      final map = tester.getRect(find.byKey(const ValueKey('maze-canvas')));
      Offset point(int node) => map.topLeft + maze.nodes[node] * map.width;
      await tester.tapAt(point(maze.goal));
      await tester.pump();
      expect(completions, 0);
      expect(saves, isEmpty);
      for (final node in maze.routeToGoal(maze.start).skip(1)) {
        await tester.tapAt(point(node));
        await tester.pump();
      }
      expect(completions, 1);
      expect(saves.last['route'], maze.routeToGoal(maze.start));
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in const [
    Size(320, 430),
    Size(844, 310),
    Size(320, 480),
    Size(768, 1024),
    Size(1024, 768),
  ]) {
    testWidgets('maze adapts to $size without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: MazeActivity(
              config: ActivityConfig(
                level: _level,
                language: 'kk',
                onChanged: (_) {},
                onCompleted: (_) {},
                onFeedback: () {},
                showHint: true,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('maze-canvas'))).shortestSide,
        greaterThanOrEqualTo(220),
      );
    });
  }
}
