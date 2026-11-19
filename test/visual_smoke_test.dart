import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/content/tracing_layouts.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';
import 'package:tiny_trails/features/play/engines/raster_color_asset.dart';
import 'package:tiny_trails/main.dart';
import 'package:tiny_trails/features/play/play_screen.dart';

const _captureFixtures = bool.fromEnvironment('CAPTURE_FIXTURES');
const _captureKey = ValueKey('visual-smoke-app');
final _colorSpecs = <String, ColorSceneSpec>{};

String _boardKey(ActivityKind kind) => switch (kind) {
  ActivityKind.numberColor || ActivityKind.freeColor => 'color-canvas',
  ActivityKind.oddFragment ||
  ActivityKind.patternSequence ||
  ActivityKind.missingPuzzle => 'choice-board',
  ActivityKind.matchPairs => 'matching-canvas',
  ActivityKind.connectDots => 'dots-canvas',
  ActivityKind.ropeTrace => 'rope-canvas',
  ActivityKind.maze => 'maze-canvas',
  ActivityKind.guidedDraw => 'drawing-canvas',
  ActivityKind.hiddenAnimals => 'hidden-canvas',
};

Future<void> _showTarget(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isEmpty) {
    // With the default zero duration the viewport jumps synchronously. Pump
    // afterwards rather than waiting for a future on the fake scheduler.
    unawaited(tester.ensureVisible(target));
  }
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _settle(WidgetTester tester) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (!tester.binding.hasScheduledFrame &&
        imageCache.pendingImageCount == 0 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
  fail('The screen did not settle after waiting for real bitmap decoding.');
}

Future<void> _ready(WidgetTester tester, ActivityKind kind) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (find.byKey(ValueKey(_boardKey(kind))).evaluate().isNotEmpty &&
        imageCache.pendingImageCount == 0 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(find.byKey(ValueKey(_boardKey(kind))), findsOneWidget);
  await _settle(tester);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureFixtures) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('output/qa/fixture-v2-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _traceAction(WidgetTester tester, DrawingAction action) async {
  for (final metric in action.path.computeMetrics()) {
    if (find.text(action.title.ru).evaluate().isEmpty) break;
    final rect = tester.getRect(find.byKey(const Key('drawing-canvas')));
    Offset screen(Offset point) => rect.topLeft + point * (rect.width / 400);
    final gesture = await tester.startGesture(
      screen(metric.getTangentForOffset(0)!.position),
    );
    for (var distance = 4.0; distance < metric.length; distance += 4) {
      await gesture.moveTo(
        screen(metric.getTangentForOffset(distance)!.position),
      );
    }
    final end = metric.length > .001 ? metric.length - .001 : 0.0;
    await gesture.moveTo(screen(metric.getTangentForOffset(end)!.position));
    await gesture.up();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Source-render checks do not install a native speech plugin. Native audio
    // and decoder events are exercised separately by integration_test/app_test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('tiny_trails/speech'),
          (call) async => call.method == 'isAvailable' ? false : true,
        );
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final level in levels) {
      final colorMetadata = level.activityData['colorSpecAsset'];
      final hiddenMetadata = level.activityData['hiddenSpecAsset'];
      if (colorMetadata is String) {
        _colorSpecs[level.id] = ColorSceneSpec.fromJson(
          jsonDecode(await rootBundle.loadString(colorMetadata))
              as Map<String, dynamic>,
        );
        final loaded = await ColorSceneAssets.load(
          colorMetadata,
          expectedIllustrationAsset: level.illustrationAsset,
        );
        loaded.dispose();
      }
      if (hiddenMetadata is String) await rootBundle.loadString(hiddenMetadata);
    }
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('tiny_trails/speech'),
          null,
        );
  });

  testWidgets(
    'the authored 20-level app stays usable through navigation and rotation',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390, 844) * 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      final c = GameController.inMemory();
      try {
        await c.setReducedMotion(true);
        await c.setSound(false);
        await c.setHaptics(false);
        await c.setVoice(false);
        await c.setGuidanceEnabled(false);
        await c.setBreakReminders(false);
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureKey,
            child: TinyTrailsApp(controller: c),
          ),
        );
        await _settle(tester);
        await _capture(tester, 'onboarding-phone');
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await _settle(tester);
        await _showTarget(
          tester,
          find.byKey(const ValueKey('onboarding-age-6')),
        );
        await tester.tap(find.byKey(const ValueKey('onboarding-age-6')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await _settle(tester);
        expect(c.onboardingComplete, isTrue);
        expect(find.byKey(const Key('fini-interface-tour')), findsOneWidget);
        final guideSkip = find.byKey(const Key('fini-tour-skip'));
        expect(guideSkip, findsOneWidget);
        await tester.tap(guideSkip);
        await _settle(tester);
        expect(find.byKey(const Key('fini-interface-tour')), findsNothing);
        expect(guideSkip, findsNothing);
        expect(find.byKey(const Key('continue-adventure')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('home-catalog-count'))).data,
          contains('20'),
        );
        await _capture(tester, 'home-phone');
        tester.view.physicalSize = const Size(1024, 768) * 2;
        await _settle(tester);
        expect(find.byType(NavigationRail), findsOneWidget);
        await _capture(tester, 'home-tablet');
        tester.view.physicalSize = const Size(390, 844) * 2;
        await _settle(tester);

        final visited = <String>{};
        for (final world in worlds) {
          final worldCard = find.byKey(ValueKey('world-card-${world.id}'));
          await _showTarget(tester, worldCard);
          await tester.tap(worldCard);
          await _settle(tester);
          for (final level in levels.where(
            (level) => level.worldId == world.id,
          )) {
            final levelCard = find.byKey(ValueKey('level-card-${level.id}'));
            await _showTarget(tester, levelCard);
            await tester.tap(levelCard);
            await _ready(tester, level.kind);
            final canvas = find.byKey(ValueKey(_boardKey(level.kind)));
            await _capture(tester, '${level.id}-phone');
            expect(
              tester.getSize(canvas).shortestSide,
              greaterThanOrEqualTo(220),
              reason: '${level.id} must have a usable finger-sized play area.',
            );
            tester.view.physicalSize = const Size(844, 390) * 2;
            await _ready(tester, level.kind);
            await _capture(tester, '${level.id}-landscape');
            expect(
              tester.getSize(canvas).shortestSide,
              greaterThanOrEqualTo(220),
              reason:
                  'Rotation must preserve the actual ${level.id} play area.',
            );
            tester.view.physicalSize = const Size(390, 844) * 2;
            await _ready(tester, level.kind);

            if (level.id == 'v2_01') {
              final spec = _colorSpecs[level.id]!;
              final region = spec.regionsFor(c.ageBand).first;
              final palette = find.byKey(
                ValueKey(
                  'raster-palette-${spec.acceptedPaletteIdFor(region, c.ageBand)}',
                ),
              );
              await _showTarget(tester, palette);
              await tester.tap(palette);
              await tester.pump();
              final rect = tester.getRect(canvas);
              await tester.tapAt(
                rect.topLeft +
                    Offset(
                      region.anchor.dx * rect.width,
                      region.anchor.dy * rect.height,
                    ),
              );
              await tester.pump();
              tester.view.physicalSize = const Size(844, 390) * 2;
              await _ready(tester, level.kind);
              tester.view.physicalSize = const Size(390, 844) * 2;
              await _ready(tester, level.kind);
              await _capture(tester, 'color-progress-after-rotation');
            }
            await tester.tap(find.byTooltip('Сохранить и выйти'));
            await _settle(tester);
            if (level.id == 'v2_01') {
              expect(
                c.draftFor(level.id)?['fills'],
                isNotEmpty,
                reason: 'Painting must survive rotation and leaving the game.',
              );
            }
            visited.add(level.id);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byType(BackButton).last);
          await _settle(tester);
        }
        expect(visited, levels.map((level) => level.id).toSet());
        expect(visited, hasLength(20));
        await tester.tap(find.byType(NavigationDestination).at(1));
        await _settle(tester);
        await _capture(tester, 'studio-phone');
        await tester.tap(find.byType(NavigationDestination).at(2));
        await _settle(tester);
        await _capture(tester, 'collection-phone');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await c.flush();
      } finally {
        semantics.dispose();
        c.dispose();
      }
    },
  );

  testWidgets(
    'advanced drawing shows the real pattern and rejects a straight-line substitute',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390, 844) * 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final c = GameController.inMemory();
      try {
        await c.setChildAge(9);
        await c.setReducedMotion(true);
        await c.setSound(false);
        await c.setHaptics(false);
        await c.setVoice(false);
        await c.setGuidanceEnabled(false);
        await c.setBreakReminders(false);
        await c.finishOnboarding();
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureKey,
            child: TinyTrailsApp(controller: c),
          ),
        );
        await _settle(tester);
        for (final id in ['v2_09', 'v2_19']) {
          final level = levelIndex[id]!;
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => PlayScreen(controller: c, level: level),
            ),
          );
          await _ready(tester, level.kind);
          final layout = guidedDrawingLayout(level.scene, c.ageBand);
          expect(layout.actions.length, 6);
          for (final action in layout.actions.take(layout.actions.length - 1)) {
            expect(find.text(action.title.ru), findsOneWidget);
            await _traceAction(tester, action);
          }
          final pattern = layout.actions.last;
          expect(find.text(pattern.title.ru), findsOneWidget);
          final rect = tester.getRect(find.byKey(const Key('drawing-canvas')));
          final bounds = pattern.path.getBounds();
          final wrong = await tester.startGesture(
            rect.topLeft +
                Offset(bounds.left, bounds.center.dy) * (rect.width / 400),
          );
          for (var x = bounds.left + 4; x <= bounds.right; x += 4) {
            await wrong.moveTo(
              rect.topLeft + Offset(x, bounds.center.dy) * (rect.width / 400),
            );
          }
          await wrong.up();
          await tester.pump();
          expect(find.text(pattern.title.ru), findsOneWidget);
          expect(find.byKey(const Key('drawing-finish')), findsNothing);
          await tester.tap(find.byTooltip('Отменить'));
          await tester.pump();
          await _capture(tester, '$id-advanced-pattern');
          await _traceAction(tester, pattern);
          expect(find.byKey(const Key('drawing-finish')), findsOneWidget);
          final canvas = tester.getRect(
            find.byKey(const Key('drawing-canvas')),
          );
          await tester.tapAt(
            canvas.topLeft + Offset(canvas.width * .86, canvas.height * .15),
          );
          await tester.pump();
          await _capture(tester, '$id-advanced-finished');
          await tester.tap(find.byKey(const Key('drawing-finish')));
          await _settle(tester);
          expect(c.progress, contains(id));
          await _capture(tester, '$id-advanced-reward');
          await tester.tap(find.text('На карту приключений'));
          await _settle(tester);
        }
        expect(c.artworks.length, 2);
        expect(c.progress.keys.toSet(), {'v2_09', 'v2_19'});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await c.flush();
      } finally {
        c.dispose();
      }
    },
  );
}
