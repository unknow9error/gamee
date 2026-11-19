import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/content/dots_rope_layouts.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/connect_dots_activity.dart';
import 'package:tiny_trails/features/play/engines/dots_engine.dart';
import 'package:tiny_trails/features/play/engines/rope_engine.dart';
import 'package:tiny_trails/features/play/rope_activity.dart';

LevelDefinition _level(String id, ActivityKind kind, String asset) =>
    LevelDefinition(
      id: id,
      worldId: 'creative',
      kind: kind,
      scene: id.contains('13')
          ? 'rocket'
          : id.contains('17')
          ? 'river'
          : 'crocodile',
      variant: 0,
      difficulty: 1,
      title: const LocalizedText('a', 'b', 'c'),
      instruction: const LocalizedText('a', 'b', 'c'),
      order: 0,
      illustrationAsset: 'assets/images/levels/$asset.png',
    );
final _croc = _level('v2_03crocdots', ActivityKind.connectDots, '03-crocodile');
final _rocket = _level(
  'v2_13rocketdots',
  ActivityKind.connectDots,
  '13-rocket',
);
final _kites = _level(
  'v2_07kitesropetrace',
  ActivityKind.ropeTrace,
  '07-kites',
);
final _river = _level('v2_17river', ActivityKind.ropeTrace, '17-river');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all rope markers retain full54dp bounds on their actual registered paths',
    () {
      for (final level in [_kites, _river]) {
        for (final band in AgeBand.values) {
          final layout = RopeLayout.forLevel(level, band);
          for (final side in [220.0, 310.0]) {
            final art = ropeArtworkRect(side);
            for (final route in layout.routes) {
              for (final point in route.samples) {
                final center = ropeMarkerCenter(point, side);
                final target = Rect.fromCircle(
                  center: center,
                  radius: ropeMarkerRadius,
                );
                expect(target.left, greaterThanOrEqualTo(0));
                expect(target.top, greaterThanOrEqualTo(0));
                expect(target.right, lessThanOrEqualTo(side));
                expect(target.bottom, lessThanOrEqualTo(side));
                expect(
                  ((center - art.topLeft) / art.width - point).distance,
                  lessThan(.0000001),
                );
              }
            }
          }
        }
      }
    },
  );
  testWidgets(
    'river edge source shares image registration and accepts a real drag',
    (tester) async {
      tester.view.physicalSize = const Size(320, 430);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? draft;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: RopeActivity(
              config: ActivityConfig(
                level: _river,
                language: 'ru',
                childAge: 7,
                reducedMotion: true,
                onChanged: (data) => draft = data,
                onCompleted: (_) {},
                onFeedback: () {},
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          AssetImage(_river.illustrationAsset!),
          tester.element(find.byType(RopeActivity)),
        ),
      );
      await tester.pump();
      final canvas = tester.getRect(find.byKey(const ValueKey('rope-canvas')));
      final image = tester.getRect(find.byType(Image));
      final expectedImage = canvas.deflate(ropeArtworkInset);
      expect(image.left, closeTo(expectedImage.left, .0001));
      expect(image.top, closeTo(expectedImage.top, .0001));
      expect(image.right, closeTo(expectedImage.right, .0001));
      expect(image.bottom, closeTo(expectedImage.bottom, .0001));
      final route = RopeLayout.forLevel(_river, AgeBand.primary).routes.single;
      final source =
          canvas.topLeft + ropeMarkerCenter(route.samples.first, canvas.width);
      expect(
        (source - (image.topLeft + route.samples.first * image.width)).distance,
        lessThan(.0001),
      );
      final gesture = await tester.startGesture(source);
      for (final point in route.samples.skip(1).take(16)) {
        await gesture.moveTo(
          canvas.topLeft + ropeMarkerCenter(point, canvas.width),
        );
      }
      await gesture.up();
      await tester.pump();
      expect(draft, isNotNull);
      expect(((draft!['routes'] as List).first as List).last, greaterThan(0));
      expect(find.text('От старта — к отметке'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  group('curated dots rules', () {
    for (final level in [_croc, _rocket]) {
      for (final band in AgeBand.values) {
        test(
          '${level.id} ${band.name}: real ordered targets, no skipping, age-safe restore',
          () {
            final layout = DotsLayout.forLevel(level, band);
            expect(layout.points.length, switch (band) {
              AgeBand.preschool => 12,
              AgeBand.primary => 20,
              AgeBand.advanced => 30,
            });
            expect(
              layout.points.every(
                (p) => p.dx > 0 && p.dx < 1 && p.dy > 0 && p.dy < 1,
              ),
              isTrue,
            );
            expect(layout.points.toSet().length, layout.points.length);
            expect(
              layout.labelStep,
              band == AgeBand.advanced ? (level.id.contains('13') ? 5 : 2) : 1,
            );
            final session = DotsSession(layout);
            expect(session.select(3), isFalse);
            expect(session.selectAt(const Offset(.99, .01), .02), isFalse);
            for (var i = 0; i < layout.points.length; i++) {
              expect(session.selectAt(layout.points[i], .01), isTrue);
              expect(session.complete, i == layout.points.length - 1);
            }
            expect(session.select(0), isFalse);
            final restored = DotsSession(layout, saved: session.toJson());
            expect(restored.complete, isTrue);
            final otherBand =
                AgeBand.values[(band.index + 1) % AgeBand.values.length];
            expect(
              DotsSession(
                DotsLayout.forLevel(level, otherBand),
                saved: session.toJson(),
              ).visited,
              0,
            );
            expect(
              utf8.encode(jsonEncode(session.toJson())).length,
              lessThan(2048),
            );
            session.undo();
            expect(session.complete, isFalse);
            session.reset();
            expect(session.visited, 0);
          },
        );
      }
    }
    test('malformed route truncates and incompatible schema resets', () {
      final layout = DotsLayout.forLevel(_croc, AgeBand.primary);
      expect(
        DotsSession(
          layout,
          saved: {
            'schema': 2,
            'type': 'connectDots',
            'revision': layout.revision,
            'visited': [0, 1, 9, 2],
          },
        ).visited,
        2,
      );
      expect(
        DotsSession(
          layout,
          saved: {
            'schema': 1,
            'type': 'connectDots',
            'revision': layout.revision,
            'visited': [0, 1, 2],
          },
        ).visited,
        0,
      );
    });
  });
  test('all advanced number labels remain separated on a small phone', () {
    for (final level in [_croc, _rocket]) {
      final layout = DotsLayout.forLevel(level, AgeBand.advanced);
      for (final side in [172.0, 260.0, 500.0]) {
        final labels = dotLabelPositions(layout.points, side);
        expect(labels.length, 30);
        for (var i = 0; i < labels.length; i++) {
          expect(labels[i].dx * side, greaterThanOrEqualTo(12.99));
          expect(labels[i].dy * side, greaterThanOrEqualTo(12.99));
          for (var j = i + 1; j < labels.length; j++) {
            expect(
              (labels[i] - labels[j]).distance * side,
              greaterThanOrEqualTo(27.99),
            );
          }
        }
      }
    }
  });
  group('annotated rope corridors', () {
    for (final level in [_kites, _river]) {
      for (final band in AgeBand.values) {
        test(
          '${level.id} ${band.name}: valid complete route, no jumps, bounded saves',
          () {
            final layout = RopeLayout.forLevel(level, band);
            final session = RopeSession(layout);
            expect(session.begin(const Offset(.5, .5), .03), isFalse);
            while (!session.complete) {
              final routeIndex = session.routeIndex;
              final route = session.route;
              expect(session.begin(session.position, .03), isTrue);
              expect(session.move(route.samples.last, .025), RopeMove.ignored);
              for (
                var index = 1;
                index <= 160 &&
                    session.routeIndex == routeIndex &&
                    !session.complete;
                index++
              ) {
                if (session.awaitingSymbol) {
                  expect(
                    session.confirmWaypoint(session.requiredSymbol!),
                    RopeMove.checkpoint,
                  );
                }
                session.move(route.samples[index], .025);
              }
              expect(
                session.complete || session.routeIndex > routeIndex,
                isTrue,
              );
            }
            expect(session.progress, 1);
            expect(
              RopeSession(layout, saved: session.toJson()).complete,
              isTrue,
            );
            expect(
              utf8.encode(jsonEncode(session.toJson())).length,
              lessThan(5000),
            );
            expect(session.move(const Offset(.1, .1), .03), RopeMove.ignored);
            session.undo();
            expect(session.complete, isFalse);
          },
        );
      }
    }
    test(
      'preschool stop taps are an ordered alternative; older users trace',
      () {
        final small = RopeSession(
          RopeLayout.forLevel(_kites, AgeBand.preschool),
        );
        expect(small.tapCheckpoint(160), RopeMove.ignored);
        while (!small.complete) {
          small.tapCheckpoint(small.nextCheckpoint);
        }
        expect(small.complete, isTrue);
        final big = RopeSession(RopeLayout.forLevel(_kites, AgeBand.advanced));
        expect(big.tapCheckpoint(40), RopeMove.ignored);
        expect(big.layout.routes.every((r) => r.branches.isNotEmpty), isTrue);
      },
    );
    test('advanced stops require explicit correct choices before motor progress resumes', () {
      final session = RopeSession(
        RopeLayout.forLevel(_river, AgeBand.advanced),
      );
      expect(session.confirmWaypoint('leaf'), RopeMove.ignored);
      session.begin(session.position, .03);
      for (var index = 1; index <= 40; index++) {
        session.move(session.route.samples[index], .025);
      }
      expect(session.awaitingSymbol, isTrue);
      expect(session.positionIndex, 40);
      expect(session.move(session.route.samples[55], .05), RopeMove.ignored);
      expect(session.confirmWaypoint('flower'), RopeMove.ignored);
      expect(session.awaitingSymbol, isTrue);
      expect(session.confirmWaypoint('leaf'), RopeMove.checkpoint);
      expect(session.awaitingSymbol, isFalse);
      expect(session.confirmedSymbols, ['leaf']);
      final restored = RopeSession(session.layout, saved: session.toJson());
      expect(restored.confirmedSymbols, ['leaf']);
      expect(restored.positionIndex, 40);
      final forged = {
        ...session.toJson(),
        'routes': [
          [0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160],
        ],
        'confirmed': [
          ['leaf', 'star', 'flower'],
        ],
      };
      final invalid = RopeSession(session.layout, saved: forged);
      expect(invalid.complete, isFalse);
      expect(invalid.positionIndex, lessThanOrEqualTo(40));
    });
    test(
      'off-corridor branch movement never completes and hints own no mutation',
      () {
        final session = RopeSession(
          RopeLayout.forLevel(_kites, AgeBand.advanced),
        );
        session.begin(session.position, .03);
        for (var i = 0; i < 100; i++) {
          session.move(const Offset(.5, .4), .03);
        }
        expect(session.positionIndex, 0);
        expect(session.complete, isFalse);
        final snapshot = session.toJson();
        final bad = {
          ...snapshot,
          'routes': [
            [0, 160],
          ],
        };
        expect(RopeSession(session.layout, saved: bad).positionIndex, 0);
        expect(
          RopeSession(
            RopeLayout.forLevel(_kites, AgeBand.primary),
            saved: snapshot,
          ).positionIndex,
          0,
        );
      },
    );
    test(
      'master coordinates correspond to visible sources and destinations',
      () {
        final kites = RopeLayout.forLevel(_kites, AgeBand.primary);
        expect(
          (kites.routes.first.samples.first - const Offset(.185, .741))
              .distance,
          lessThan(.001),
        );
        expect(
          (kites.routes.first.samples.last - const Offset(.122, .218)).distance,
          lessThan(.001),
        );
        expect(
          (kites.routes.last.samples.first - const Offset(.812, .75)).distance,
          lessThan(.001),
        );
        final river = RopeLayout.forLevel(_river, AgeBand.primary);
        expect(river.routes.single.samples.first.dy, greaterThan(.98));
        expect(river.routes.single.samples.last.dy, lessThan(.14));
      },
    );
  });
  for (final size in const [Size(320, 430), Size(844, 310)]) {
    for (final kind in [ActivityKind.connectDots, ActivityKind.ropeTrace]) {
      testWidgets('$kind has a usable ImageGen canvas at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final config = ActivityConfig(
          level: kind == ActivityKind.connectDots ? _croc : _kites,
          language: 'kk',
          childAge: 4,
          reducedMotion: true,
          onChanged: (_) {},
          onCompleted: (_) {},
          onFeedback: () {},
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: kind == ActivityKind.connectDots
                  ? ConnectDotsActivity(config: config)
                  : RopeActivity(config: config),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final canvas = find.byKey(
          ValueKey(
            kind == ActivityKind.connectDots ? 'dots-canvas' : 'rope-canvas',
          ),
        );
        expect(tester.getSize(canvas).shortestSide, greaterThanOrEqualTo(220));
        expect(find.byType(Image), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'real dots taps resume an interrupted illustration and finish exactly once',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? draft;
      var complete = 0;
      final layout = DotsLayout.forLevel(_croc, AgeBand.preschool);
      Widget app(String key, Map<String, dynamic>? data) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ConnectDotsActivity(
            key: ValueKey(key),
            config: ActivityConfig(
              level: _croc,
              language: 'ru',
              childAge: 4,
              reducedMotion: true,
              initialData: data,
              onChanged: (value) => draft = value,
              onCompleted: (_) => complete++,
              onFeedback: () {},
            ),
          ),
        ),
      );
      Future<void> loaded() async {
        await tester.runAsync(
          () => precacheImage(
            AssetImage(_croc.illustrationAsset!),
            tester.element(find.byType(ConnectDotsActivity)),
          ),
        );
        await tester.pump();
      }

      await tester.pumpWidget(app('initial', null));
      await loaded();
      Future<void> select(int index) async {
        final rect = tester.getRect(find.byKey(const ValueKey('dots-canvas')));
        await tester.tapAt(
          rect.topLeft +
              const Offset(dotsCanvasInset, dotsCanvasInset) +
              layout.points[index] * (rect.width - 2 * dotsCanvasInset),
        );
        await tester.pump();
      }

      await select(4);
      expect(draft, isNull);
      expect(complete, 0);
      for (var index = 0; index < 5; index++) {
        await select(index);
      }
      expect(draft!['visited'], [0, 1, 2, 3, 4]);
      await tester.pumpWidget(app('restored', draft));
      await loaded();
      for (var index = 5; index < layout.points.length; index++) {
        await select(index);
      }
      expect(complete, 1);
      expect(draft!['visited'], hasLength(12));
      await select(11);
      expect(complete, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real preschool rope stops finish both kite strings, not the first only',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var complete = 0;
      Map<String, dynamic>? draft;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: RopeActivity(
              config: ActivityConfig(
                level: _kites,
                language: 'en',
                childAge: 4,
                reducedMotion: true,
                onChanged: (data) => draft = data,
                onCompleted: (_) => complete++,
                onFeedback: () {},
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          AssetImage(_kites.illustrationAsset!),
          tester.element(find.byType(RopeActivity)),
        ),
      );
      await tester.pump();
      for (var route = 0; route < 2; route++) {
        for (final checkpoint in [40, 80, 120, 160]) {
          await tester.tap(find.byKey(ValueKey('rope-checkpoint-$checkpoint')));
          await tester.pump();
        }
        expect(complete, route == 0 ? 0 : 1);
      }
      expect(draft!['routes'], hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(320, 430), Size(844, 310)]) {
    testWidgets('advanced rope decisions retain a usable canvas at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final layout = RopeLayout.forLevel(_river, AgeBand.advanced);
      final session = RopeSession(layout);
      session.begin(session.position, .025);
      for (var index = 1; index <= 40; index++) {
        session.move(session.route.samples[index], .025);
      }
      expect(session.awaitingSymbol, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: RopeActivity(
              config: ActivityConfig(
                level: _river,
                language: 'kk',
                childAge: 10,
                reducedMotion: true,
                initialData: session.toJson(),
                onChanged: (_) {},
                onCompleted: (_) {},
                onFeedback: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('rope-symbol-leaf')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('rope-canvas'))).shortestSide,
        greaterThanOrEqualTo(220),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
