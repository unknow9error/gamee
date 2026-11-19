import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/color_activity.dart';
import 'package:tiny_trails/shared/art/art_scene.dart';

LevelDefinition _level(ActivityKind kind) => LevelDefinition(
  id: 'test-${kind.name}',
  worldId: 'ocean',
  kind: kind,
  scene: 'whale',
  variant: 0,
  difficulty: 1,
  title: const LocalizedText('Кит', 'Кит', 'Whale'),
  instruction: const LocalizedText('Раскрась', 'Боя', 'Color'),
  order: 0,
);
Future<void> _pump(
  WidgetTester tester,
  ActivityKind kind, {
  Map<String, dynamic>? draft,
  ValueChanged<Map<String, dynamic>>? changed,
  ValueChanged<Map<String, dynamic>>? completed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ColorActivity(
          key: ValueKey(kind),
          config: ActivityConfig(
            level: _level(kind),
            language: 'en',
            initialData: draft,
            reducedMotion: true,
            onChanged: changed ?? (_) {},
            onCompleted: completed ?? (_) {},
            onFeedback: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Offset _exposedPoint(ArtScene scene, String id) {
  final book = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, 400, 400),
    const Radius.circular(28),
  );
  final preferred = scene.regions.firstWhere((r) => r.id == id).labelPoint;
  final top = scene.regions.reversed
      .where((r) => r.path.contains(preferred))
      .firstOrNull;
  if (top?.id == id && book.contains(preferred)) return preferred;
  for (var y = 2.0; y < 400; y += 2) {
    for (var x = 2.0; x < 400; x += 2) {
      final p = Offset(x, y);
      if (!book.contains(p)) continue;
      for (final region in scene.regions.reversed) {
        if (!region.path.contains(p)) continue;
        if (region.id == id) return p;
        break;
      }
    }
  }
  throw StateError('Region has no exposed input area: $id');
}

Future<void> _tapRegion(WidgetTester tester, ArtScene scene, String id) async {
  final rect = tester.getRect(find.byKey(const Key('color-canvas')));
  final p = _exposedPoint(scene, id);
  await tester.tapAt(
    rect.topLeft + Offset(p.dx / 400 * rect.width, p.dy / 400 * rect.height),
  );
  await tester.pump();
}

bool _finishEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('color-finish')))
        .onPressed !=
    null;

void main() {
  testWidgets('short landscape pins Done outside the scrolling color tools', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(848, 390);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const Key('short-color-board'),
              height: 250,
              child: ColorActivity(
                config: ActivityConfig(
                  level: _level(ActivityKind.freeColor),
                  language: 'ru',
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
    await tester.pump();
    final bounds = tester.getRect(find.byKey(const Key('short-color-board')));
    final finish = find.byKey(const Key('color-finish'));
    final before = tester.getRect(finish);
    expect(before.bottom, lessThanOrEqualTo(bounds.bottom));
    expect(before.top, greaterThanOrEqualTo(bounds.top));
    expect(before.height, greaterThanOrEqualTo(48));
    // The tools scroll independently while the final action stays anchored.
    final scroll = find.byType(SingleChildScrollView);
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -130));
    await tester.pump();
    expect(tester.getRect(finish), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'a near miss beside a small numbered bubble paints one matching detail',
    (tester) async {
      final scene = SceneFactory.create(
        'whale',
        segmented: true,
      ).withSemanticNumbers();
      final bubble = scene.regions.firstWhere((r) => r.id.contains('bubble2'));
      final changes = <Map<String, dynamic>>[];
      await _pump(tester, ActivityKind.numberColor, changed: changes.add);
      final color = scene.numberPalette[bubble.number]!;
      await tester.tap(
        find.byKey(ValueKey('color-swatch-${color.toARGB32()}')),
      );
      await tester.pump();
      final rect = tester.getRect(find.byKey(const Key('color-canvas')));
      final center = bubble.path.getBounds().center;
      final near =
          center +
          Offset(bubble.path.getBounds().width / 2 + 8 / (rect.width / 400), 0);
      expect(bubble.path.contains(near), isFalse);
      await tester.tapAt(
        rect.topLeft +
            Offset(near.dx / 400 * rect.width, near.dy / 400 * rect.height),
      );
      await tester.pump();
      expect(changes, hasLength(1));
      expect((changes.single['fills'] as Map).keys, [bubble.id]);
      expect(_finishEnabled(tester), isFalse);
    },
  );
  testWidgets('fully erased or clipped-away marks cannot finish free art', (
    tester,
  ) async {
    final stroke = {
      'color': 0xFF5375BD,
      'width': 22,
      'points': [
        [.1, .1],
        [.9, .1],
      ],
    };
    await _pump(
      tester,
      ActivityKind.freeColor,
      draft: {
        'strokes': [
          stroke,
          {...stroke, 'eraser': true},
        ],
      },
    );
    expect(_finishEnabled(tester), isFalse);
    await tester.pumpWidget(const SizedBox());
    final scene = SceneFactory.create('whale');
    final subject = scene.regions.firstWhere((r) => r.group == 'subject');
    await _pump(
      tester,
      ActivityKind.freeColor,
      draft: {
        'strokes': [
          {...stroke, 'clipRegionId': subject.id},
        ],
      },
    );
    expect(_finishEnabled(tester), isFalse);
  });
  testWidgets(
    'compact studio keeps a large canvas and changes brush through tools',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 420);
      final snapshots = <Map<String, dynamic>>[];
      await _pump(tester, ActivityKind.freeColor, changed: snapshots.add);
      final rect = tester.getRect(find.byKey(const Key('color-canvas')));
      expect(rect.width, greaterThanOrEqualTo(270));
      await tester.tap(find.byKey(const Key('color-tools')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Brush'));
      await tester.pump();
      await tester.ensureVisible(find.text('Let’s draw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let’s draw'));
      await tester.pumpAndSettle();
      final board = tester.getRect(find.byKey(const Key('color-canvas')));
      final gesture = await tester.startGesture(board.center);
      for (var i = 1; i <= 20; i++) {
        await gesture.moveTo(board.center + Offset(i.toDouble() * 2, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(snapshots, isNotEmpty);
      final strokes = snapshots.last['strokes'] as List;
      expect(strokes, hasLength(1));
      for (final point in (strokes.single as Map)['points'] as List) {
        expect(point[0], inInclusiveRange(0, 1));
        expect(point[1], inInclusiveRange(0, 1));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'wrong colors and repeated taps do not complete a numbered region',
    (tester) async {
      final scene = SceneFactory.create(
        'whale',
        segmented: true,
      ).withSemanticNumbers();
      final snapshots = <Map<String, dynamic>>[];
      await _pump(tester, ActivityKind.numberColor, changed: snapshots.add);
      final target = scene.regions.first;
      final wrong = scene.numberPalette.values.firstWhere(
        (c) => c != scene.numberPalette[target.number],
      );
      await tester.tap(
        find.byKey(ValueKey('color-swatch-${wrong.toARGB32()}')),
      );
      await _tapRegion(tester, scene, target.id);
      expect(snapshots, isEmpty);
      expect(_finishEnabled(tester), isFalse);
      final correct = scene.numberPalette[target.number]!;
      await tester.tap(
        find.byKey(ValueKey('color-swatch-${correct.toARGB32()}')),
      );
      await _tapRegion(tester, scene, target.id);
      await _tapRegion(tester, scene, target.id);
      expect(snapshots, hasLength(1));
      expect((snapshots.single['fills'] as Map)[target.id], correct.toARGB32());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all numbered regions are required; undo and redo preserve actual progress',
    (tester) async {
      final scene = SceneFactory.create(
        'whale',
        segmented: true,
      ).withSemanticNumbers();
      final completed = <Map<String, dynamic>>[];
      await _pump(tester, ActivityKind.numberColor, completed: completed.add);
      for (final region in scene.regions) {
        final color = scene.numberPalette[region.number]!;
        await tester.tap(
          find.byKey(ValueKey('color-swatch-${color.toARGB32()}')),
        );
        await _tapRegion(tester, scene, region.id);
      }
      expect(completed, isEmpty);
      expect(_finishEnabled(tester), isTrue);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(_finishEnabled(tester), isFalse);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(_finishEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('color-finish')));
      await tester.pump();
      expect(completed, hasLength(1));
      expect((completed.single['fills'] as Map).length, scene.regions.length);
    },
  );
  testWidgets(
    'blank free art cannot complete, fills survive draft restoration',
    (tester) async {
      final scene = SceneFactory.create('whale');
      final snapshots = <Map<String, dynamic>>[];
      await _pump(tester, ActivityKind.freeColor, changed: snapshots.add);
      expect(_finishEnabled(tester), isFalse);
      for (final region in scene.regions.take(3)) {
        await _tapRegion(tester, scene, region.id);
      }
      expect(_finishEnabled(tester), isTrue);
      final draft = snapshots.last;
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, ActivityKind.freeColor, draft: draft);
      expect(_finishEnabled(tester), isTrue);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(
        _finishEnabled(tester),
        isTrue,
        reason: 'History starts after restoring; saved work remains intact',
      );
    },
  );
  testWidgets('corrupt or unknown draft regions never count as solved', (
    tester,
  ) async {
    final scene = SceneFactory.create(
      'whale',
      segmented: true,
    ).withSemanticNumbers();
    await _pump(
      tester,
      ActivityKind.numberColor,
      draft: {
        'fills': {'unknown': 0xFF123456, scene.regions.first.id: 0xFF123456},
        'strokes': ['invalid'],
        'tool': 'invalid',
        'selectedColor': 0xFF123456,
      },
    );
    expect(_finishEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone and tablet layouts leave usable square canvas space', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 560), const Size(1024, 650)]) {
      tester.view.physicalSize = size;
      for (final kind in [ActivityKind.freeColor, ActivityKind.numberColor]) {
        await _pump(tester, kind);
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byKey(const Key('color-canvas')));
        expect(rect.width, greaterThan(150));
        expect(rect.width, closeTo(rect.height, .1));
      }
    }
  });
}
