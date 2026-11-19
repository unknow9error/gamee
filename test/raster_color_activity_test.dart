import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/color_activity.dart';
import 'package:tiny_trails/features/play/engines/raster_color_asset.dart';
import 'package:tiny_trails/features/play/engines/raster_color_document.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';
import 'package:tiny_trails/features/play/raster_color_activity.dart';
import 'package:tiny_trails/features/play/raster_color_painter.dart';

const _captureMasks = bool.fromEnvironment('CAPTURE_COLOR_MASKS');
const _canvasKey = ValueKey('color-canvas');
const _finishKey = ValueKey('color-finish');
const _maskKey = ValueKey('color-mask-capture');
const _liveKey = ValueKey('color-live-capture');

LevelDefinition _level(String id) =>
    levels.firstWhere((level) => level.id == id);

Finder _painterFinder() => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is RasterColorPainter,
);

RasterColorPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_painterFinder()).painter! as RasterColorPainter;

Finder _icon(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == tooltip,
);

bool _canFinish(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_finishKey)).onPressed != null;

bool _insideRect(Rect inner, Rect outer) =>
    inner.left >= outer.left - .000001 &&
    inner.top >= outer.top - .000001 &&
    inner.right <= outer.right + .000001 &&
    inner.bottom <= outer.bottom + .000001;

Future<LoadedColorScene> _warm(
  WidgetTester tester,
  LevelDefinition level,
) async {
  final scene = await tester.runAsync(
    () => ColorSceneAssets.load(
      colorSpecAsset(level),
      expectedIllustrationAsset: level.illustrationAsset,
    ),
  );
  expect(scene, isNotNull);
  final loaded = scene!;
  addTearDown(loaded.dispose);
  return loaded;
}

Future<void> _pumpGame(
  WidgetTester tester,
  LevelDefinition level, {
  int age = 7,
  bool hint = false,
  Map<String, dynamic>? draft,
  ValueChanged<Map<String, dynamic>>? changed,
  ValueChanged<Map<String, dynamic>>? completed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: RepaintBoundary(
          key: _liveKey,
          child: ColoredBox(
            color: AppColors.paper,
            child: ColorActivity(
              key: UniqueKey(),
              config: ActivityConfig(
                level: level,
                childAge: age,
                language: 'en',
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
    ),
  );
  await _awaitRasterPainter(tester, 'game ${level.id}, age $age');
  expect(find.byType(RasterColorActivity), findsOneWidget);
  expect(find.byKey(_canvasKey), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> _awaitRasterPainter(WidgetTester tester, String subject) async {
  // Cached source decoding happens in runAsync. Yield its real event loop
  // before pumping framework frames; a spinning animation cannot settle
  // while an image-clone continuation is still waiting in that other zone.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    if (find.text('Could not open this picture.').evaluate().isNotEmpty) {
      fail('$subject exposed the public picture-load failure UI');
    }
    final painters = _painterFinder().evaluate().length;
    if (painters == 1) {
      await tester.pumpAndSettle();
      return;
    }
    expect(
      painters,
      0,
      reason: '$subject must have exactly one raster painter',
    );
  }
  final labels = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((label) => label.isNotEmpty)
      .take(12)
      .join(' | ');
  fail(
    '$subject did not expose a raster painter after real async yields. '
    'Spinner: ${find.byType(CircularProgressIndicator).evaluate().length}; '
    'retry action: ${find.text("Try again").evaluate().length}; '
    'visible text: $labels',
  );
}

Future<void> _choose(WidgetTester tester, String paletteId) async {
  final swatch = find.byKey(ValueKey('raster-palette-$paletteId'));
  expect(swatch, findsOneWidget);
  await tester.ensureVisible(swatch);
  await tester.pumpAndSettle();
  await tester.tap(swatch);
  await tester.pump();
}

Offset _screenPoint(WidgetTester tester, Offset unit) {
  final rect = tester.getRect(find.byKey(_canvasKey));
  return rect.topLeft + Offset(unit.dx * rect.width, unit.dy * rect.height);
}

Future<void> _tapRegion(WidgetTester tester, ColorRegionSpec region) async {
  await tester.tapAt(_screenPoint(tester, region.anchor));
  await tester.pump();
}

Future<void> _solve(
  WidgetTester tester,
  ColorSceneSpec spec,
  AgeBand band,
) async {
  for (final region in spec.regionsFor(band)) {
    await _choose(tester, spec.acceptedPaletteIdFor(region, band));
    await _tapRegion(tester, region);
  }
}

Offset _brushEnd(ColorRegionSpec region) {
  for (final direction in const [
    Offset(-1, 0),
    Offset(1, 0),
    Offset(0, -1),
    Offset(0, 1),
    Offset(-.7, -.7),
    Offset(.7, .7),
  ]) {
    final end = region.anchor + direction * .08;
    if (List.generate(
      17,
      (i) => ui.Offset.lerp(region.anchor, end, i / 16)!,
    ).every(region.path.contains)) {
      return end;
    }
  }
  throw StateError('Reviewed region has no short interior brush path');
}

Future<void> _draw(WidgetTester tester, ColorRegionSpec region) async {
  final start = _screenPoint(tester, region.anchor);
  final end = _screenPoint(tester, _brushEnd(region));
  final pointer = await tester.startGesture(start);
  for (var step = 1; step <= 20; step++) {
    await pointer.moveTo(Offset.lerp(start, end, step / 20)!);
    await tester.pump();
  }
  await pointer.up();
  await tester.pump();
}

Future<void> _confirmClear(WidgetTester tester) async {
  final clear = _icon('Clear');
  await tester.ensureVisible(clear);
  await tester.tap(clear);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final id in ['v2_01', 'v2_11']) {
    for (final age in [4, 7, 10]) {
      testWidgets(
        '$id age $age shows its verified bitmap and completes only real regions',
        (tester) async {
          final level = _level(id);
          final loaded = await _warm(tester, level);
          final snapshots = <Map<String, dynamic>>[];
          final completions = <Map<String, dynamic>>[];
          final band = AgeBand.fromAge(age);
          await _pumpGame(
            tester,
            level,
            age: age,
            changed: snapshots.add,
            completed: completions.add,
          );
          final initial = _painter(tester);
          expect(
            initial.image.isCloneOf(loaded.image),
            isTrue,
            reason: 'The game must paint the actual generated source image',
          );
          expect(initial.image.width, 1254);
          expect(initial.image.height, 1254);
          expect(initial.spec.asset, level.illustrationAsset);
          expect(initial.ageBand, band);
          expect(initial.fills, isEmpty);
          const smallCanvas = Size(220, 220);
          final viewport = Offset.zero & smallCanvas;
          final layouts = initial.clueLayouts(smallCanvas);
          for (final region in loaded.spec.regionsFor(band)) {
            final measured = layouts[region.id];
            expect(
              measured,
              isNotNull,
              reason: '$id age $age needs a visible clue for ${region.id}',
            );
            final layout = measured!;
            final rect = layout.bounds;
            expect(rect.width, greaterThan(0));
            expect(rect.height, greaterThan(0));
            final path = region.path;
            if (layout.isCallout) {
              final badge = layout.badgeBounds!;
              expect(layout.fontSize, greaterThanOrEqualTo(16));
              expect(_insideRect(rect, viewport), isTrue);
              expect(_insideRect(badge, viewport), isTrue);
              expect(_insideRect(rect, badge), isTrue);
              expect(
                loaded.spec.labelSlots.any((slot) {
                  final pixels = Rect.fromLTWH(
                    slot.left * smallCanvas.width,
                    slot.top * smallCanvas.height,
                    slot.width * smallCanvas.width,
                    slot.height * smallCanvas.height,
                  );
                  return _insideRect(badge, pixels);
                }),
                isTrue,
                reason: '$id callout must occupy reviewed empty paper',
              );
              expect(
                layout.leaderTarget,
                Offset(
                  region.anchor.dx * smallCanvas.width,
                  region.anchor.dy * smallCanvas.height,
                ),
              );
              expect(
                path.contains(
                  Offset(
                    layout.leaderTarget.dx / smallCanvas.width,
                    layout.leaderTarget.dy / smallCanvas.height,
                  ),
                ),
                isTrue,
              );
            } else {
              expect(layout.fontSize, greaterThanOrEqualTo(14));
              // Corners, edge centers and interior samples must remain inside
              // the true region, including its holes and concave boundaries.
              for (var row = 0; row <= 4; row++) {
                for (var column = 0; column <= 8; column++) {
                  final point = Offset(
                    (rect.left + rect.width * column / 8) / smallCanvas.width,
                    (rect.top + rect.height * row / 4) / smallCanvas.height,
                  );
                  expect(
                    path.contains(point),
                    isTrue,
                    reason:
                        '$id age $age inline clue for ${region.id} escapes '
                        'its mask at sample ($column, $row)',
                  );
                }
              }
            }
          }
          final visible = initial
              .visibleClueLayouts(smallCanvas)
              .values
              .toList();
          expect(
            visible.where((layout) => layout.isCallout).length,
            lessThanOrEqualTo(1),
          );
          for (var first = 0; first < visible.length; first++) {
            for (var second = first + 1; second < visible.length; second++) {
              final a = visible[first].badgeBounds ?? visible[first].bounds;
              final b = visible[second].badgeBounds ?? visible[second].bounds;
              expect(
                a.overlaps(b),
                isFalse,
                reason:
                    '$id visible clues ${visible[first].regionId} and '
                    '${visible[second].regionId} must not overlap',
              );
            }
          }
          expect(_canFinish(tester), isFalse);
          expect(
            tester.widget<IconButton>(_icon('Your colors and brush')).onPressed,
            isNull,
            reason: 'Creative replay unlocks after the lesson is solved',
          );

          final target = loaded.spec.regionsFor(band).first;
          final wrong = loaded.spec
              .paletteFor(band)
              .firstWhere((entry) => entry.id != target.paletteId);
          await _choose(tester, wrong.id);
          await _tapRegion(tester, target);
          expect(snapshots, isEmpty);
          expect(_painter(tester).fills, isEmpty);
          expect(_canFinish(tester), isFalse);

          await _solve(tester, loaded.spec, band);
          final requiredIds = loaded.spec
              .regionsFor(band)
              .map((region) => region.id)
              .toSet();
          expect(_painter(tester).fills.keys.toSet(), requiredIds);
          expect(snapshots, hasLength(requiredIds.length));
          expect(
            completions,
            isEmpty,
            reason: 'The child decides when to leave the finished picture',
          );
          expect(_canFinish(tester), isTrue);
          expect(
            tester.widget<IconButton>(_icon('Your colors and brush')).onPressed,
            isNotNull,
          );
          await tester.tap(find.byKey(_finishKey));
          await tester.pump();
          expect(completions, hasLength(1));
          final data = completions.single;
          expect(data['version'], 2);
          expect(data['kind'], 'rasterColor');
          expect(data['ageBand'], band.name);
          expect(data['assetSha256'], loaded.spec.assetSha256);
          expect(data['specSha256'], loaded.specSha256);
          expect(data['specAsset'], colorSpecAsset(level));
          expect((data['fills'] as Map).keys.toSet(), requiredIds);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('$id hints do not paint or award progress', (tester) async {
      final level = _level(id);
      await _warm(tester, level);
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      await _pumpGame(
        tester,
        level,
        age: 4,
        hint: true,
        changed: snapshots.add,
        completed: completions.add,
      );
      expect(_painter(tester).hintRegionId, isNotNull);
      expect(_painter(tester).fills, isEmpty);
      expect(snapshots, isEmpty);
      expect(completions, isEmpty);
      expect(_canFinish(tester), isFalse);
    });

    testWidgets('$id advanced lookup needs both independent clues', (
      tester,
    ) async {
      final level = _level(id);
      final loaded = await _warm(tester, level);
      final snapshots = <Map<String, dynamic>>[];
      await _pumpGame(tester, level, age: 10, changed: snapshots.add);
      final rule = loaded.spec.ruleFor(AgeBand.advanced);
      final target = loaded.spec.regionsFor(AgeBand.advanced).first;
      bool sameFirst(ColorRuleLookup entry) =>
          rule.mode == ColorRuleMode.numberAndShape
          ? entry.value == target.advancedValue
          : entry.parity == (target.advancedValue.isOdd ? 'odd' : 'even');
      final sameValueWrongShape = rule.lookup.firstWhere(
        (entry) => sameFirst(entry) && entry.paletteId != target.paletteId,
      );
      final sameShapeWrongValue = rule.lookup.firstWhere(
        (entry) =>
            entry.symbol == target.advancedSymbol &&
            entry.paletteId != target.paletteId,
      );
      for (final incorrect in [sameValueWrongShape, sameShapeWrongValue]) {
        await _choose(tester, incorrect.paletteId);
        await _tapRegion(tester, target);
        expect(_painter(tester).fills, isEmpty);
        expect(snapshots, isEmpty);
      }
      await _choose(tester, target.paletteId);
      await _tapRegion(tester, target);
      expect(_painter(tester).fills, {target.id: target.paletteId});
      expect(snapshots, hasLength(1));
      expect(_canFinish(tester), isFalse);
    });

    testWidgets('$id source anchors correspond to the metadata palette', (
      tester,
    ) async {
      final loaded = await _warm(tester, _level(id));
      final bytes = await tester.runAsync(
        () => loaded.image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(bytes, isNotNull);
      for (final region in loaded.spec.regions) {
        final x = (region.anchor.dx * loaded.image.width).floor();
        final y = (region.anchor.dy * loaded.image.height).floor();
        final pixel = (y * loaded.image.width + x) * 4;
        final color = loaded.spec.paletteById(region.paletteId).color;
        final channels = [color.r, color.g, color.b];
        for (var channel = 0; channel < 3; channel++) {
          final actual = bytes!.getUint8(pixel + channel);
          final expected = (channels[channel] * 255).round();
          expect(
            (actual - expected).abs(),
            lessThanOrEqualTo(45),
            reason:
                '${region.id} must retain its source color, not a global palette',
          );
        }
      }
    });
  }

  testWidgets(
    'readable callout badges keep exact region and palette semantics',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 310);
      final level = _level('v2_01');
      final loaded = await _warm(tester, level);
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      await _pumpGame(
        tester,
        level,
        age: 4,
        changed: snapshots.add,
        completed: completions.add,
      );
      // Exercise the actual UI at its minimum reviewed artboard size without
      // changing the palette width or relying on guessed header dimensions.
      final initialSize = tester.getSize(find.byKey(_canvasKey));
      tester.view.physicalSize = Size(844, 310 - (initialSize.height - 220));
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byKey(_canvasKey));
      expect(size.shortestSide, closeTo(220, .1));
      final cab = loaded.spec.regionById('cab');
      expect(_painter(tester).clueLayouts(size)[cab.id]!.isCallout, isTrue);
      final badge = find.byKey(ValueKey('raster-clue-${cab.id}'));
      expect(badge, findsOneWidget);
      expect(tester.getSize(badge).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(badge).height, greaterThanOrEqualTo(48));

      final wrong = loaded.spec
          .paletteFor(AgeBand.preschool)
          .firstWhere((entry) => entry.id != cab.paletteId);
      await _choose(tester, wrong.id);
      await tester.tap(badge);
      await tester.pump();
      expect(_painter(tester).fills, isEmpty);
      expect(snapshots, isEmpty);
      expect(completions, isEmpty);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.selected == true &&
              widget.properties.label == wrong.names.en,
        ),
        findsOneWidget,
        reason: 'Selecting a badge must not automatically select its answer',
      );

      await _choose(tester, cab.paletteId);
      await tester.tap(badge);
      await tester.pump();
      expect(_painter(tester).fills, {cab.id: cab.paletteId});
      expect(snapshots, hasLength(1));
      expect(completions, isEmpty);
      expect(_canFinish(tester), isFalse);
      expect(find.byKey(ValueKey('raster-clue-${cab.id}')), findsNothing);

      final other = loaded.spec
          .regionsFor(AgeBand.preschool)
          .firstWhere((region) => region.id != cab.id);
      await _choose(tester, other.paletteId);
      await _tapRegion(tester, other);
      expect(_painter(tester).fills, {
        cab.id: cab.paletteId,
        other.id: other.paletteId,
      });
      expect(
        snapshots,
        hasLength(2),
        reason: 'Direct touches on the real body remain valid alongside badges',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all six numeric legend choices stay visible and contrast on a short landscape',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 310);
      final level = _level('v2_01');
      final loaded = await _warm(tester, level);
      await _pumpGame(tester, level, age: 10);
      final first = tester.getSize(find.byKey(_canvasKey));
      tester.view.physicalSize = Size(844, 310 - (first.height - 220));
      await tester.pumpAndSettle();
      final actionsTop = tester.getRect(_icon('Undo')).top;
      for (final entry in loaded.spec.paletteFor(AgeBand.advanced)) {
        final choice = find.byKey(ValueKey('raster-palette-${entry.id}'));
        final rect = tester.getRect(choice);
        expect(rect.bottom, lessThanOrEqualTo(actionsTop));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        final label = tester.widget<Text>(
          find.descendant(of: choice, matching: find.byType(Text)),
        );
        final foreground = label.style!.color!.computeLuminance();
        final background = entry.color.computeLuminance();
        final contrast =
            (foreground > background ? foreground + .05 : background + .05) /
            (foreground > background ? background + .05 : foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
      expect(
        tester.getRect(find.byKey(_finishKey)).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('garden clothes outside the age rule are decoration', (
    tester,
  ) async {
    final level = _level('v2_11');
    final loaded = await _warm(tester, level);
    final active = loaded.spec
        .regionsFor(AgeBand.primary)
        .map((region) => region.id)
        .toSet();
    final inactive = loaded.spec.regions.firstWhere(
      (region) =>
          !active.contains(region.id) &&
          loaded.spec
              .paletteFor(AgeBand.primary)
              .any((entry) => entry.id == region.paletteId),
    );
    final snapshots = <Map<String, dynamic>>[];
    await _pumpGame(tester, level, changed: snapshots.add);
    await _choose(tester, inactive.paletteId);
    await _tapRegion(tester, inactive);
    expect(snapshots, isEmpty);
    expect(_painter(tester).fills, isEmpty);
    expect(_canFinish(tester), isFalse);
  });

  testWidgets(
    'partial masks restore only for matching image and metadata versions',
    (tester) async {
      final level = _level('v2_01');
      final loaded = await _warm(tester, level);
      final document = RasterColorDocument(
        spec: loaded.spec,
        ageBand: AgeBand.primary,
        specSha256: loaded.specSha256,
      );
      addTearDown(document.dispose);
      final first = loaded.spec.regionsFor(AgeBand.primary).first;
      document.selectPalette(first.paletteId);
      document.fillRegion(first.id);
      final data = document.toJson();
      await _pumpGame(tester, level, draft: data);
      expect(_painter(tester).fills, {first.id: first.paletteId});
      expect(_canFinish(tester), isFalse);
      await _pumpGame(
        tester,
        level,
        draft: {...data, 'assetSha256': List.filled(64, '0').join()},
      );
      expect(_painter(tester).fills, isEmpty);
      await _pumpGame(
        tester,
        level,
        draft: {...data, 'specSha256': List.filled(64, '0').join()},
      );
      expect(_painter(tester).fills, isEmpty);
      expect(_canFinish(tester), isFalse);
    },
  );

  testWidgets(
    'creative replay brushes, erases, undoes and restores inside one level',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 520);
      final level = _level('v2_01');
      final loaded = await _warm(tester, level);
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      await _pumpGame(
        tester,
        level,
        changed: snapshots.add,
        completed: completions.add,
      );
      await _solve(tester, loaded.spec, AgeBand.primary);
      await tester.tap(_icon('Your colors and brush'));
      await tester.pump();
      expect(_painter(tester).creative, isTrue);
      await _confirmClear(tester);
      expect(_painter(tester).fills, isEmpty);
      expect(_canFinish(tester), isFalse);
      await tester.tap(_icon('Undo'));
      await tester.pump();
      expect(_canFinish(tester), isTrue);
      await tester.tap(_icon('Redo'));
      await tester.pump();
      expect(_canFinish(tester), isFalse);
      await tester.ensureVisible(_icon('Brush'));
      await tester.tap(_icon('Brush'));
      await tester.pump();
      final target = loaded.spec.regions.first;
      await _draw(tester, target);
      expect(_painter(tester).strokes, hasLength(1));
      expect(_painter(tester).strokes.single.clipRegionId, target.id);
      expect(_canFinish(tester), isTrue);
      await tester.tap(_icon('Undo'));
      await tester.pump();
      expect(_canFinish(tester), isFalse);
      await tester.tap(_icon('Redo'));
      await tester.pump();
      expect(_canFinish(tester), isTrue);
      await tester.ensureVisible(_icon('Eraser'));
      await tester.tap(_icon('Eraser'));
      await tester.pump();
      await _draw(tester, target);
      expect(_painter(tester).strokes.last.eraser, isTrue);
      expect(
        _canFinish(tester),
        isFalse,
        reason: 'Historic erased ink must not count as a picture',
      );
      await tester.tap(_icon('Undo'));
      await tester.pump();
      final draft = snapshots.last;
      await _pumpGame(tester, level, draft: draft, completed: completions.add);
      expect(_painter(tester).creative, isTrue);
      expect(_painter(tester).strokes, hasLength(1));
      expect(_canFinish(tester), isTrue);
      await tester.tap(find.byKey(_finishKey));
      await tester.pump();
      expect(completions, hasLength(1));
      expect(completions.single['creative'], isTrue);
      expect(
        level.id,
        'v2_01',
        reason: 'Creative play is a replay, not a new level',
      );
    },
  );

  testWidgets(
    'phone and tablet layouts retain a usable bitmap canvas at all ages',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final id in ['v2_01', 'v2_11']) {
        final level = _level(id);
        await _warm(tester, level);
        for (final size in [
          const Size(320, 430),
          const Size(844, 310),
          const Size(1024, 700),
        ]) {
          tester.view.physicalSize = size;
          for (final age in [4, 7, 10]) {
            await _pumpGame(tester, level, age: age);
            final canvas = tester.getRect(find.byKey(_canvasKey));
            expect(
              canvas.shortestSide,
              greaterThanOrEqualTo(220),
              reason: '$id age $age needs room for real finger input at $size',
            );
            final finish = tester.getRect(find.byKey(_finishKey));
            expect(finish.bottom, lessThanOrEqualTo(size.height));
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'gallery uses the same bitmap painter with the saved preschool age',
    (tester) async {
      final level = _level('v2_11');
      final loaded = await _warm(tester, level);
      final completions = <Map<String, dynamic>>[];
      await _pumpGame(tester, level, age: 4, completed: completions.add);
      await _solve(tester, loaded.spec, AgeBand.preschool);
      await tester.tap(find.byKey(_finishKey));
      await tester.pump();
      expect(completions, hasLength(1));
      final data = completions.single;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 320,
                child: ColorArtworkPreview(level: level, data: data),
              ),
            ),
          ),
        ),
      );
      await _awaitRasterPainter(tester, 'gallery ${level.id}');
      expect(find.byType(RasterColorArtworkPreview), findsOneWidget);
      final painter = _painter(tester);
      expect(painter.image.isCloneOf(loaded.image), isTrue);
      expect(painter.ageBand, AgeBand.preschool);
      expect(painter.showClues, isFalse);
      expect(painter.fills, data['fills']);
      expect(painter.creative, isFalse);
      expect(painter.strokes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  if (_captureMasks) {
    testWidgets('capture readable connected callouts at the minimum artboard', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final example in [
        ('v2_01', 4, 'cab', 'toybox-preschool'),
        ('v2_01', 10, 'bearhead', 'toybox-advanced'),
        ('v2_11', 4, 'flower', 'garden-preschool'),
        ('v2_11', 10, 'flower', 'garden-advanced'),
      ]) {
        tester.view.physicalSize = const Size(844, 310);
        final level = _level(example.$1);
        final loaded = await _warm(tester, level);
        await _pumpGame(tester, level, age: example.$2);
        final initial = tester.getSize(find.byKey(_canvasKey));
        tester.view.physicalSize = Size(844, 310 - (initial.height - 220));
        await tester.pumpAndSettle();
        final target = loaded.spec.regionById(example.$3);
        final wrong = loaded.spec
            .paletteFor(AgeBand.fromAge(example.$2))
            .firstWhere((p) => p.id != target.paletteId);
        await _choose(tester, wrong.id);
        await _tapRegion(tester, target);
        expect(_painter(tester).fills, isEmpty);
        expect(
          find.byKey(ValueKey('raster-clue-${target.id}')),
          findsOneWidget,
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_liveKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('output/qa/color-${example.$4}-callout.png').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
        });
      }
    });
    testWidgets('capture reviewed region overlays over unchanged source art', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final pair in [('v2_01', 'toybox'), ('v2_11', 'garden')]) {
        final loaded = await _warm(tester, _level(pair.$1));
        final size = Size(
          loaded.image.width.toDouble(),
          loaded.image.height.toDouble(),
        );
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: _maskKey,
                child: CustomPaint(
                  size: size,
                  painter: RasterColorPainter(
                    image: loaded.image,
                    spec: loaded.spec,
                    ageBand: AgeBand.advanced,
                    creative: true,
                    showClues: false,
                    fills: {
                      for (final region in loaded.spec.regions)
                        region.id: region.paletteId,
                    },
                    strokes: const [],
                    debugRegions: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_maskKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final output = File('output/qa/color-${pair.$2}-masks.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
