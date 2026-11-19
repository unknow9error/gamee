import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/hidden_activity.dart';
import 'package:tiny_trails/shared/art/art_scene.dart';

const _level = LevelDefinition(
  id: 'hidden-test',
  worldId: 'ocean',
  kind: ActivityKind.hiddenAnimals,
  scene: 'whale',
  variant: 0,
  difficulty: 1,
  title: LocalizedText('Тайные друзья', 'Жасырын достар', 'Hidden friends'),
  instruction: LocalizedText(
    'Найди животных',
    'Жануарларды тап',
    'Find animals',
  ),
  order: 0,
);

Future<void> _pumpGame(
  WidgetTester tester, {
  Map<String, dynamic>? draft,
  bool hint = false,
  ValueChanged<Map<String, dynamic>>? changed,
  ValueChanged<Map<String, dynamic>>? completed,
  String language = 'ru',
  double? playHeight,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: playHeight,
          child: HiddenActivity(
            config: ActivityConfig(
              level: _level,
              language: language,
              initialData: draft,
              showHint: hint,
              reducedMotion: true,
              onChanged: changed ?? (_) {},
              onCompleted: completed ?? (_) {},
              onFeedback: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Find an actual exposed region point, rather than trusting a bounding box.
Offset _pointFor(ArtScene scene, Set<String> regionIds) {
  for (var y = 4.0; y < scene.viewBox.height; y += 3) {
    for (var x = 4.0; x < scene.viewBox.width; x += 3) {
      final point = Offset(x, y);
      for (final region in scene.regions.reversed) {
        if (!region.path.contains(point)) continue;
        if (regionIds.contains(region.id)) return point;
        break;
      }
    }
  }
  throw StateError('No exposed hit area for $regionIds');
}

Future<void> _tapScenePoint(
  WidgetTester tester,
  ArtScene scene,
  Offset point,
) async {
  final rect = tester.getRect(find.byKey(const Key('hidden-canvas')));
  await tester.tapAt(
    rect.topLeft +
        Offset(
          point.dx * rect.width / scene.viewBox.width,
          point.dy * rect.height / scene.viewBox.height,
        ),
  );
  await tester.pump();
}

void main() {
  testWidgets('background and hint never award an animal', (tester) async {
    var changes = 0;
    var completions = 0;
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    final animalRegions = scene.hiddenAnimals
        .expand((animal) => animal.regionIds)
        .toSet();
    final background = scene.regions
        .where((region) => !animalRegions.contains(region.id))
        .map((region) => region.id)
        .toSet();
    await _pumpGame(
      tester,
      hint: true,
      changed: (_) => changes++,
      completed: (_) => completions++,
    );
    await _tapScenePoint(tester, scene, _pointFor(scene, background));
    expect(changes, 0);
    expect(completions, 0);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('hidden-finish')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('0 / ${scene.hiddenAnimals.length}'), findsOneWidget);
  });

  testWidgets('discoveries alone do not color or complete the picture', (
    tester,
  ) async {
    final snapshots = <Map<String, dynamic>>[];
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    await _pumpGame(tester, changed: snapshots.add);
    for (final animal in scene.hiddenAnimals) {
      await _tapScenePoint(
        tester,
        scene,
        _pointFor(scene, animal.regionIds.toSet()),
      );
    }
    expect(snapshots, hasLength(scene.hiddenAnimals.length));
    expect(snapshots.last['fills'], isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
          .onPressed,
      isNull,
    );
    // The last discovered animal's paint is selected. A different animal's
    // piece must not be colored until its own paint is selected.
    final first = scene.hiddenAnimals.first;
    await _tapScenePoint(
      tester,
      scene,
      _pointFor(scene, first.regionIds.toSet()),
    );
    expect(snapshots.last['fills'], isEmpty);
  });

  testWidgets('every animal piece must be painted before completion', (
    tester,
  ) async {
    final snapshots = <Map<String, dynamic>>[];
    final completions = <Map<String, dynamic>>[];
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    await _pumpGame(tester, changed: snapshots.add, completed: completions.add);
    for (final animal in scene.hiddenAnimals) {
      final point = _pointFor(scene, animal.regionIds.toSet());
      await _tapScenePoint(tester, scene, point);
    }
    for (final animal in scene.hiddenAnimals) {
      await tester.tap(find.byKey(ValueKey('hidden-target-${animal.id}')));
      await tester.pump();
      for (final id in animal.regionIds) {
        final point = _pointFor(scene, {id});
        await _tapScenePoint(tester, scene, point);
        final countAfterFirstTap = snapshots.length;
        await _tapScenePoint(tester, scene, point);
        expect(
          snapshots.length,
          countAfterFirstTap,
          reason: 'The same region must not count twice',
        );
      }
    }
    expect(
      completions,
      isEmpty,
      reason: 'The child chooses when to leave the finished picture',
    );
    final allPieces = scene.hiddenAnimals
        .expand((animal) => animal.regionIds)
        .toSet();
    expect((snapshots.last['fills'] as Map).keys, unorderedEquals(allPieces));
    await tester.tap(find.byKey(const Key('hidden-finish')));
    await tester.pump();
    expect(completions, hasLength(1));
    expect(
      completions.single['found'],
      unorderedEquals(scene.hiddenAnimals.map((animal) => animal.id)),
    );
    expect((completions.single['fills'] as Map).length, allPieces.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored discoveries without painted pieces cannot finish', (
    tester,
  ) async {
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    await _pumpGame(
      tester,
      draft: {
        'version': 2,
        'found': scene.hiddenAnimals.map((animal) => animal.id).toList(),
        'fills': {'unknown-region': 0xFF000000},
      },
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        '0/${scene.hiddenAnimals.expand((animal) => animal.regionIds).length} деталей',
      ),
      findsOneWidget,
    );
  });

  testWidgets('restore ignores unknown IDs and keeps valid discoveries', (
    tester,
  ) async {
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    final first = scene.hiddenAnimals.first;
    await _pumpGame(
      tester,
      language: 'en',
      draft: {
        'found': [first.id, first.id, 'not-an-animal', 42],
      },
    );
    expect(find.text('1 / ${scene.hiddenAnimals.length}'), findsOneWidget);
    expect(find.text(first.nameEn), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone and tablet layouts fit their bounded play area', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 600), const Size(1024, 700)]) {
      tester.view.physicalSize = size;
      await _pumpGame(tester, hint: true);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(const Key('hidden-canvas')));
      expect(rect.width, greaterThan(80));
      expect(rect.width, closeTo(rect.height, 0.1));
    }
  });

  testWidgets('short landscape shows every target above the finish button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpGame(tester, playHeight: 342);
    final scene = SceneFactory.create(
      'whale',
      geometric: true,
      worldId: 'ocean',
    );
    final finish = tester.getRect(find.byKey(const Key('hidden-finish')));
    for (final target in scene.hiddenAnimals) {
      final rect = tester.getRect(
        find.byKey(ValueKey('hidden-target-${target.id}')),
      );
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(finish.top),
        reason: 'All three paint targets must be visible without scrolling',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
