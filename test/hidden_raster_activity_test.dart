import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/engines/hidden_picture.dart';
import 'package:tiny_trails/features/play/hidden_activity.dart';
import 'package:tiny_trails/features/play/raster_hidden_activity.dart';

const _capture = bool.fromEnvironment('CAPTURE_HIDDEN_HOTSPOTS');
const _captureKey = ValueKey('hidden-raster-qa');

LevelDefinition _level(String scene) => LevelDefinition(
  id: 'hidden-raster-$scene',
  worldId: scene == 'reef' ? 'ocean' : 'forest',
  kind: ActivityKind.hiddenAnimals,
  scene: scene,
  variant: 0,
  difficulty: 1,
  title: const LocalizedText('Найди друзей', 'Достарды тап', 'Find friends'),
  instruction: const LocalizedText(
    'Сравни картинки',
    'Суреттерді салыстыр',
    'Match pictures',
  ),
  order: 0,
  illustrationAsset:
      'assets/images/levels/${scene == 'reef' ? '10-reef' : '20-forest'}.png',
  activityData: {'hiddenSpecAsset': 'assets/content/hidden-$scene.json'},
);

HiddenPictureSpec _spec(String scene) => HiddenPictureSpec.fromJson(
  jsonDecode(File('assets/content/hidden-$scene.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<void> _pumpRaster(
  WidgetTester tester, {
  String scene = 'reef',
  int age = 6,
  bool hint = false,
  bool debug = false,
  double? height,
  Map<String, dynamic>? draft,
  ValueChanged<Map<String, dynamic>>? changed,
  ValueChanged<Map<String, dynamic>>? completed,
}) async {
  final config = ActivityConfig(
    level: _level(scene),
    language: 'ru',
    childAge: age,
    reducedMotion: true,
    showHint: hint,
    initialData: draft,
    onChanged: changed ?? (_) {},
    onCompleted: completed ?? (_) {},
    onFeedback: () {},
  );
  // Start the asset/codec Future chain in the real asynchronous zone as well
  // as waiting there. Starting it in FakeAsync then only delaying outside can
  // strand cached asset futures or engine-codec callbacks between test clocks.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: RepaintBoundary(
            key: _captureKey,
            child: ColoredBox(
              color: AppColors.paper,
              child: SizedBox(
                height: height,
                child: debug
                    ? RasterHiddenActivity(config: config, debugHotspots: true)
                    : HiddenActivity(config: config),
              ),
            ),
          ),
        ),
      ),
    );
  });
  // The engine decodes a genuine bundled bitmap on Flutter's codec worker.
  // Yield real time instead of settling the loading indicator indefinitely.
  final wait = Stopwatch()..start();
  while (find.byKey(const Key('hidden-canvas')).evaluate().isEmpty &&
      find.byKey(const Key('hidden-load-error')).evaluate().isEmpty &&
      wait.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  final state = tester.state(find.byType(RasterHiddenActivity));
  expect(
    find.byKey(const Key('hidden-load-error')),
    findsNothing,
    reason:
        'Source image $scene failed to load: ${state.toDiagnosticsNode().toStringDeep()}',
  );
  expect(
    find.byKey(const Key('hidden-canvas')),
    findsOneWidget,
    reason:
        'Source image $scene did not become ready in ${wait.elapsed}: ${state.toDiagnosticsNode().toStringDeep()}',
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSource(
  WidgetTester tester,
  HiddenPictureSpec spec,
  Offset point,
) async {
  final box = tester.renderObject<RenderBox>(
    find.byKey(const Key('hidden-canvas')),
  );
  await tester.tapAt(
    box.localToGlobal(
      Offset(
        point.dx / spec.imageSize.width * box.size.width,
        point.dy / spec.imageSize.height * box.size.height,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final entry in [(3, 2), (6, 4), (9, 8)]) {
    testWidgets('age ${entry.$1} has ${entry.$2} genuine picture targets', (
      tester,
    ) async {
      await _pumpRaster(tester, age: entry.$1);
      expect(find.text('0 / ${entry.$2}'), findsOneWidget);
      final spec = _spec('reef');
      for (final target in spec.targets.take(entry.$2)) {
        expect(
          find.byKey(ValueKey('hidden-target-${target.id}')),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'matching the selected picture is required; hints award nothing',
    (tester) async {
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      final spec = _spec('reef');
      await _pumpRaster(
        tester,
        hint: true,
        changed: snapshots.add,
        completed: completions.add,
      );
      await _tapSource(tester, spec, spec.targets[1].anchor);
      await _tapSource(tester, spec, const Offset(1240, 20));
      expect(snapshots, isEmpty);
      expect(completions, isEmpty);
      expect(find.text('0 / 4'), findsOneWidget);
      await _tapSource(tester, spec, spec.targets.first.anchor);
      expect(snapshots, hasLength(1));
      expect(snapshots.single['found'], [spec.targets.first.id]);
      await _tapSource(tester, spec, spec.targets.first.anchor);
      expect(snapshots, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scene in ['reef', 'forest']) {
    testWidgets(
      '$scene completes by finding every actual source-image target',
      (tester) async {
        final snapshots = <Map<String, dynamic>>[];
        final completions = <Map<String, dynamic>>[];
        final spec = _spec(scene);
        await _pumpRaster(
          tester,
          scene: scene,
          age: 9,
          changed: snapshots.add,
          completed: completions.add,
        );
        for (final target in spec.targets) {
          await _tapSource(tester, spec, target.anchor);
        }
        expect(find.text('8 / 8'), findsOneWidget);
        expect(completions, isEmpty);
        await tester.tap(find.byKey(const Key('hidden-finish')));
        await tester.pump();
        expect(completions, hasLength(1));
        expect(
          completions.single['found'],
          spec.targets.map((target) => target.id).toList(),
        );
        expect(completions.single['imageAsset'], spec.asset);
        expect(completions.single['imageSha256'], spec.imageSha256);
        expect(snapshots.last['found'], hasLength(8));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('older age keeps discoveries and requires additional targets', (
    tester,
  ) async {
    final spec = _spec('reef');
    await _pumpRaster(tester, age: 3);
    for (final target in spec.targets.take(2)) {
      await _tapSource(tester, spec, target.anchor);
    }
    expect(find.text('2 / 2'), findsOneWidget);
    await _pumpRaster(tester, age: 9);
    expect(find.text('2 / 8'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('real raster play area remains usable at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpRaster(tester, age: 9, height: size.height - 96);
      final rect = tester.getRect(find.byKey(const Key('hidden-canvas')));
      expect(rect.shortestSide, greaterThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('review actual painted images with precise hotspot overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scene in ['reef', 'forest']) {
      await _pumpRaster(tester, scene: scene, age: 9, debug: true);
      expect(tester.takeException(), isNull);
      if (_capture) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_captureKey),
          );
          final image = await boundary.toImage(pixelRatio: 1.5);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('output/qa/hidden-$scene-hotspots.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
