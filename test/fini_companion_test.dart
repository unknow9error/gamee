import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/shared/widgets/fini_companion.dart';

const _captureKey = ValueKey('fini-behavior-capture');
const _finiKey = ValueKey('fini-behavior-character');
const _paper = Color(0xFFFFFBF3);

Widget _host({
  bool animate = true,
  bool reducedMotion = false,
  bool systemReducedMotion = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: systemReducedMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          color: _paper,
          child: FiniCompanion(
            key: _finiKey,
            size: 240,
            height: 280,
            animate: animate,
            reducedMotion: reducedMotion,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _waitForRealSprite(WidgetTester tester) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byKey(const Key('fini-wave-sprite')).evaluate().isNotEmpty &&
        imageCache.pendingImageCount == 0) {
      return;
    }
  }
  fail('The actual bundled Fini sprite did not finish decoding.');
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  await tester.pump();
  final result = await tester.runAsync<Uint8List>(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw StateError('Could not capture the rendered Fini frame.');
      }
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
  return result!;
}

int _changedPixels(Uint8List before, Uint8List after) {
  expect(after.length, before.length);
  var changed = 0;
  for (var offset = 0; offset < before.length; offset += 4) {
    var difference = 0;
    for (var channel = 0; channel < 4; channel++) {
      difference += (before[offset + channel] - after[offset + channel]).abs();
    }
    if (difference > 24) changed++;
  }
  return changed;
}

void main() {
  testWidgets(
    'Fini renders different poses without moving its canvas, then settles',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(_host(animate: false));
      await _waitForRealSprite(tester);
      final initialRect = tester.getRect(find.byKey(_captureKey));
      expect(initialRect.size, const Size(240, 280));
      final first = await _pixels(tester);

      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final waving = await _pixels(tester);
      expect(
        _changedPixels(first, waving),
        greaterThan(200),
        reason: 'Time must change the rendered character, not only a controller value.',
      );
      expect(tester.getRect(find.byKey(_captureKey)), initialRect);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        _changedPixels(paused, await _pixels(tester)),
        0,
        reason: 'The greeting must not advance while the app is paused.',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(_changedPixels(paused, await _pixels(tester)), greaterThan(200));
      expect(tester.getRect(find.byKey(_captureKey)), initialRect);

      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      final settled = await _pixels(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(
        _changedPixels(settled, await _pixels(tester)),
        0,
        reason: 'The finite greeting must stay still after it finishes.',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'app and system reduced motion keep the actual rendered frame still',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (final system in [false, true]) {
        await tester.pumpWidget(
          _host(reducedMotion: !system, systemReducedMotion: system),
        );
        await _waitForRealSprite(tester);
        final initialRect = tester.getRect(find.byKey(_captureKey));
        final still = await _pixels(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expect(_changedPixels(still, await _pixels(tester)), 0);
        await tester.pump(const Duration(seconds: 3));
        expect(_changedPixels(still, await _pixels(tester)), 0);
        expect(tester.getRect(find.byKey(_captureKey)), initialRect);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
