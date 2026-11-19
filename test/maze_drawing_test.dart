import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/content/tracing_layouts.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/artwork_limits.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/drawing_activity.dart';
import 'package:tiny_trails/features/play/engines/trace_engine.dart';

LevelDefinition lesson(String scene) => LevelDefinition(
  id: scene == 'duck' ? 'v2_09' : 'v2_19',
  worldId: 'meadow',
  kind: ActivityKind.guidedDraw,
  scene: scene,
  variant: 0,
  difficulty: 1,
  title: const LocalizedText('Рисуй', 'Сал', 'Draw'),
  instruction: const LocalizedText('Рисуй', 'Сал', 'Draw'),
  order: 0,
  illustrationAsset:
      'assets/images/levels/${scene == 'duck' ? '09-duck' : '19-cat'}.png',
);

Future<void> loadLessonArtwork(WidgetTester tester, String scene) async {
  await tester.runAsync(
    () => precacheImage(
      AssetImage(lesson(scene).illustrationAsset!),
      tester.element(find.byType(DrawingActivity)),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> completeTraceDraft(String scene, int age) {
  final band = AgeBand.fromAge(age),
      layout = guidedDrawingLayout(scene, AgeBand.fromAge(age));
  return {
    'version': 2,
    'type': 'guidedDraw',
    'levelId': lesson(scene).id,
    'layoutId': layout.id,
    'ageBand': band.name,
    'childAge': age,
    'stepStrokes': [
      for (final action in layout.actions)
        encodeTraceStrokes([simplifyTraceStroke(sampleTracePath(action.path))]),
    ],
    'stepModes': [for (final _ in layout.actions) 'trace'],
    'checkpointProofs': [for (final _ in layout.actions) <int>[]],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('RENDER_GAME_PREVIEWS')) {
    for (final scene in ['duck', 'cat']) {
      testWidgets('render actual $scene ImageGen lesson for visual review', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(420, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await (FontLoader(
            'Nunito',
          )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: Scaffold(
                appBar: AppBar(
                  title: Text(
                    scene == 'duck' ? 'Рисуем утёнка' : 'Рисуем котёнка',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DrawingActivity(
                    config: ActivityConfig(
                      level: lesson(scene),
                      language: 'ru',
                      childAge: 7,
                      reducedMotion: true,
                      onChanged: (_) {},
                      onCompleted: (_) {},
                      onFeedback: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await loadLessonArtwork(tester, scene);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('/tmp/tinytrails-v2-$scene-guided.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
  test(
    'actual tracing, imprecise tracing and multi-stroke tracing complete',
    () {
      final circle = Path()..addOval(const Rect.fromLTWH(70, 65, 140, 140));
      final target = sampleTracePath(circle),
          validator = TraceValidator(circle);
      expect(validator.evaluate([target]).complete, isTrue);
      expect(
        validator.evaluate([
          target.map((p) => p + const Offset(8, 8)).toList(),
        ]).complete,
        isTrue,
      );
      expect(
        validator.evaluate([
          target.take(target.length ~/ 2).toList(),
          target.skip(target.length ~/ 2 - 1).toList(),
        ]).complete,
        isTrue,
      );
    },
  );
  test(
    'blank, dot, unrelated scribble, partial curve and jumps cannot complete',
    () {
      final oval = Path()..addOval(const Rect.fromLTWH(70, 65, 170, 150));
      final validator = TraceValidator(oval), points = sampleTracePath(oval);
      expect(validator.evaluate([]).complete, isFalse);
      expect(
        validator.evaluate([
          [const Offset(90, 90)],
        ]).complete,
        isFalse,
      );
      expect(
        validator.evaluate([
          List.generate(
            90,
            (i) => Offset(320 + math.sin(i) * 20, 320 + math.cos(i) * 20),
          ),
        ]).complete,
        isFalse,
      );
      expect(
        validator.evaluate([points.take(points.length ~/ 3).toList()]).complete,
        isFalse,
      );
      final line = Path()
        ..moveTo(20, 200)
        ..lineTo(380, 200);
      expect(
        TraceValidator(line).evaluate([
          [const Offset(20, 200), const Offset(380, 200)],
        ]).complete,
        isFalse,
      );
    },
  );
  test('normalized drafts reject invalid values and bound points', () {
    final original = [
      [const Offset(12, 24), const Offset(200, 240), const Offset(399, 399)],
    ];
    expect(decodeTraceStrokes(encodeTraceStrokes(original)), original);
    expect(decodeTraceStrokes('bad'), isEmpty);
    final decoded = decodeTraceStrokes([
      [
        [0, 0],
        [1, 1],
        [double.nan, 0],
        [-1, .4],
        [1.1, .2],
        ['x', 2],
      ],
      [
        [0],
      ],
    ]);
    expect(decoded.first, [Offset.zero, const Offset(400, 400)]);
    expect(
      decodeTraceStrokes([
        List.generate(10000, (_) => [.2, .3]),
      ]).first.length,
      ArtworkLimits.maxPointsPerStroke,
    );
  });
  test('checkpoint proofs require every index in order', () {
    expect(orderedCheckpointProof([0, 1, 2, 3], 4), [0, 1, 2, 3]);
    expect(orderedCheckpointProof([2, 3], 4), isEmpty);
    expect(orderedCheckpointProof([0, 2, 3], 4), [0]);
    expect(orderedCheckpointProof([0, 1, 1, 2], 4), [0, 1]);
    expect(orderedCheckpointProof('4', 4), isEmpty);
  });

  for (final scene in ['duck', 'cat']) {
    for (final band in AgeBand.values) {
      test(
        '$scene ${band.name} has four to six actual image-aligned teaching actions',
        () {
          final layout = guidedDrawingLayout(scene, band);
          expect(File(layout.asset).existsSync(), isTrue);
          expect(layout.actions.length, switch (band) {
            AgeBand.preschool => 4,
            AgeBand.primary => 5,
            AgeBand.advanced => 6,
          });
          expect(
            layout.actions.map((a) => a.id).toSet().length,
            layout.actions.length,
          );
          for (final action in layout.actions) {
            expect(
              action.path.computeMetrics().length,
              1,
              reason: 'Each action is one short, continuous teaching gesture',
            );
            expect(action.path.getBounds().left, greaterThanOrEqualTo(0));
            expect(action.path.getBounds().right, lessThanOrEqualTo(400));
            expect(action.path.getBounds().top, greaterThanOrEqualTo(0));
            expect(action.path.getBounds().bottom, lessThanOrEqualTo(400));
            for (final language in ['ru', 'kk', 'en']) {
              expect(action.title.resolve(language), isNotEmpty);
              expect(action.instruction.resolve(language), isNotEmpty);
            }
            final raw = sampleTracePath(action.path),
                simplified = simplifyTraceStroke(raw);
            expect(simplified.length, lessThanOrEqualTo(400));
            final validator = TraceValidator(
              action.path,
              tolerance: band == AgeBand.preschool ? 29 : 22,
              requiredCoverage: band == AgeBand.preschool ? .66 : .76,
              requiredHorizontalRuns: action.requiredHorizontalRuns,
              minimumPatternHeight: action.minimumPatternHeight,
            );
            expect(
              validator.evaluate([simplified]).complete,
              isTrue,
              reason:
                  '${action.id} remains traceable after persistence simplification',
            );
            expect(action.checkpoints.length, action.checkpointCount);
          }
          if (band == AgeBand.advanced) {
            expect(layout.actions.last.id, contains('pattern'));
          }
        },
      );
    }
    testWidgets(
      '$scene preschool has an ordered tap alternative and optional decoration',
      (tester) async {
        tester.view.physicalSize = const Size(420, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic> draft = {};
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: DrawingActivity(
                config: ActivityConfig(
                  level: lesson(scene),
                  language: 'en',
                  childAge: 3,
                  reducedMotion: true,
                  onChanged: (d) => draft = d,
                  onCompleted: (_) => completions++,
                  onFeedback: () {},
                ),
              ),
            ),
          ),
        );
        await loadLessonArtwork(tester, scene);
        final layout = guidedDrawingLayout(scene, AgeBand.preschool),
            canvas = find.byKey(const ValueKey('drawing-canvas'));
        expect(find.byType(Image), findsOneWidget);
        for (var index = 0; index < layout.actions.length; index++) {
          final origin = tester.getTopLeft(canvas),
              side = tester.getSize(canvas).width;
          final targets = layout.actions[index].checkpoints;
          if (index == 0) {
            await tester.tapAt(origin + targets.last * (side / 400));
            await tester.pump();
            expect(draft['step'], isNull);
          }
          for (final point in targets) {
            await tester.tapAt(origin + point * (side / 400));
            await tester.pump();
          }
          expect(draft['step'], index + 1);
          expect(draft['stepModes'], everyElement('checkpoints'));
        }
        expect(completions, 0);
        expect(find.byKey(const ValueKey('drawing-finish')), findsOneWidget);
        // Decoration is creative and optional. Finished tracing can be accepted directly.
        await tester.tap(find.byKey(const ValueKey('drawing-finish')));
        await tester.pump();
        expect(completions, 1);
        expect(utf8.encode(jsonEncode(draft)).length, lessThan(300 * 1024));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$scene primary genuinely traces every action', (tester) async {
      tester.view.physicalSize = const Size(420, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> draft = {};
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: DrawingActivity(
              config: ActivityConfig(
                level: lesson(scene),
                language: 'ru',
                childAge: 7,
                reducedMotion: true,
                onChanged: (d) => draft = d,
                onCompleted: (_) => completions++,
                onFeedback: () {},
              ),
            ),
          ),
        ),
      );
      await loadLessonArtwork(tester, scene);
      final layout = guidedDrawingLayout(scene, AgeBand.primary),
          canvas = find.byKey(const ValueKey('drawing-canvas'));
      for (var index = 0; index < layout.actions.length; index++) {
        final origin = tester.getTopLeft(canvas),
            side = tester.getSize(canvas).width;
        final points = sampleTracePath(layout.actions[index].path);
        final gesture = await tester.startGesture(
          origin + points.first * (side / 400),
        );
        for (final point in points.skip(1)) {
          await gesture.moveTo(origin + point * (side / 400));
        }
        await gesture.up();
        await tester.pump();
        expect(draft['step'], index + 1, reason: layout.actions[index].id);
      }
      expect(completions, 0);
      await tester.tap(find.byKey(const ValueKey('drawing-finish')));
      await tester.pump();
      expect(completions, 1);
      expect(draft['illustrationAsset'], lesson(scene).illustrationAsset);
    });
  }
  for (final size in [const Size(320, 430), const Size(844, 310)]) {
    for (final done in [false, true]) {
      testWidgets('image lesson keeps canvas at least220 at$size done=$done', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: DrawingActivity(
                config: ActivityConfig(
                  level: lesson('cat'),
                  language: 'kk',
                  childAge: 10,
                  reducedMotion: true,
                  initialData: done ? completeTraceDraft('cat', 10) : null,
                  onChanged: (_) {},
                  onCompleted: (_) {},
                  onFeedback: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('drawing-canvas')))
              .shortestSide,
          greaterThanOrEqualTo(220),
        );
        expect(
          find.byKey(const ValueKey('drawing-finish')),
          done ? findsOneWidget : findsNothing,
        );
      });
    }
  }
  testWidgets('age, schema and layout changes reject stale completion', (
    tester,
  ) async {
    final draft = completeTraceDraft('duck', 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrawingActivity(
            config: ActivityConfig(
              level: lesson('duck'),
              language: 'en',
              childAge: 10,
              initialData: draft,
              reducedMotion: true,
              onChanged: (_) {},
              onCompleted: (_) => fail('No reward from a stale age'),
              onFeedback: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('drawing-finish')), findsNothing);
    expect(find.text('A gentle head curve'), findsOneWidget);
  });
  test('advanced patterns require three alternating gestures, not one straight line', () {
    for (final scene in ['duck', 'cat']) {
      final action = guidedDrawingLayout(scene, AgeBand.advanced).actions.last;
      final validator = TraceValidator(
        action.path,
        tolerance: 22,
        requiredCoverage: .76,
        requiredHorizontalRuns: action.requiredHorizontalRuns,
        minimumPatternHeight: action.minimumPatternHeight,
      );
      final shortcut = scene == 'duck'
          ? (Path()
              ..moveTo(94, 227)
              ..lineTo(180, 227))
          : (Path()
              ..moveTo(201, 195)
              ..lineTo(201, 252));
      expect(validator.evaluate([sampleTracePath(shortcut)]).complete, isFalse);
      expect(
        validator.evaluate([sampleTracePath(action.path)]).complete,
        isTrue,
      );
    }
  });
  test(
    'every preschool guide retains a complete50dp target inside a220dp canvas',
    () {
      for (final scene in ['duck', 'cat']) {
        for (final action in guidedDrawingLayout(
          scene,
          AgeBand.preschool,
        ).actions) {
          for (final point in action.checkpointsForCanvas(220)) {
            final logical = point * (220 / 400);
            expect(logical.dx, inInclusiveRange(25, 195));
            expect(logical.dy, inInclusiveRange(25, 195));
          }
        }
      }
    },
  );
  testWidgets(
    'creative replay requires visible input and undo removes permission to save',
    (tester) async {
      final original = lesson('duck');
      final replay = LevelDefinition(
        id: original.id,
        worldId: original.worldId,
        kind: original.kind,
        scene: original.scene,
        variant: original.variant,
        difficulty: original.difficulty,
        title: original.title,
        instruction: original.instruction,
        order: original.order,
        illustrationAsset: original.illustrationAsset,
        activityData: const {'creativeReplay': true},
      );
      Map<String, dynamic>? result;
      var completionCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawingActivity(
              config: ActivityConfig(
                level: replay,
                language: 'en',
                childAge: 7,
                reducedMotion: true,
                onChanged: (_) {},
                onCompleted: (data) {
                  result = data;
                  completionCount++;
                },
                onFeedback: () {},
              ),
            ),
          ),
        ),
      );
      await loadLessonArtwork(tester, 'duck');
      final finish = find.byKey(const ValueKey('drawing-finish'));
      expect(tester.widget<FilledButton>(finish).onPressed, isNull);
      await tester.tap(finish);
      await tester.pump();
      expect(completionCount, 0);
      final canvas = find.byKey(const ValueKey('drawing-canvas'));
      await tester.tapAt(tester.getCenter(canvas));
      await tester.pump();
      expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(tester.widget<FilledButton>(finish).onPressed, isNull);
      expect(completionCount, 0);
      await tester.tapAt(tester.getCenter(canvas));
      await tester.pump();
      await tester.tap(finish);
      await tester.pump();
      await tester.tap(finish);
      await tester.pump();
      expect(completionCount, 1);
      expect(result?['stamps'], hasLength(1));
      expect(result?['creativeReplay'], isTrue);
      expect(result?['stepStrokes'], isEmpty);
      expect(result?['stepModes'], isEmpty);
    },
  );
  testWidgets(
    'saved artwork preview uses the real master and has no game input',
    (tester) async {
      final data = {
        ...completeTraceDraft('duck', 7),
        'strokes': [
          {
            'color': AppColors.green.toARGB32(),
            'width': 3.5,
            'points': [
              [.1, .1],
              [.3, .1],
            ],
          },
        ],
        'stamps': [
          {
            'point': [.8, .1],
            'color': AppColors.peach.toARGB32(),
            'shape': 1,
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 220,
                child: DrawingArtworkPreview(level: lesson('duck'), data: data),
              ),
            ),
          ),
        ),
      );
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(provider.width, lessThanOrEqualTo(1254));
      expect(
        (provider.imageProvider as AssetImage).assetName,
        'assets/images/levels/09-duck.png',
      );
      expect(
        find.descendant(
          of: find.byType(DrawingArtworkPreview),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
