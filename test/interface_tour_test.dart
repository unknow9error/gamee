import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/features/home/app_shell.dart';
import 'package:tiny_trails/features/home/interface_tour.dart';
import 'package:tiny_trails/features/settings/settings_screen.dart';
import 'package:tiny_trails/shared/widgets/fini_companion.dart';

const _capture = bool.fromEnvironment('CAPTURE_TOUR');
const _captureKey = ValueKey('tour-capture');

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(GameController controller, {double textScale = 1}) =>
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: AppShell(controller: controller),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var pass = 0; pass < 2; pass++) {
    await tester.pump();
    final companions = find.byType(FiniCompanion).evaluate();
    final images = find.byType(Image, skipOffstage: false).evaluate().toList();
    await tester.runAsync(() async {
      await Future.wait([
        for (final element in images)
          precacheImage((element.widget as Image).image, element),
        if (companions.isNotEmpty)
          precacheImage(
            const AssetImage('assets/images/fini-wave-sheet.png'),
            companions.first,
          ),
      ]);
    });
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(Key(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await _settle(tester);
}

Future<void> _captureStep(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('output/qa/fini-guide-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _close(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await controller.flush();
  controller.dispose();
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
  test(
    'a 2.0 save without a guide version is offered once after updating',
    () async {
      final store = MemoryProgressStore();
      final original = GameController.forTest(store: store);
      expect(original.needsInterfaceTour, isFalse);
      await original.finishOnboarding();
      await original.completeLevel(levels[1]);
      final oldSave = jsonDecode(
        store.values[GameController.storageKey]!,
      ) as Map<String, dynamic>;
      (oldSave['settings'] as Map<String, dynamic>).remove(
        'interfaceTourVersion',
      );
      store.values[GameController.storageKey] = jsonEncode(oldSave);
      original.dispose();

      final upgraded = await GameController.load(store: store);
      expect(upgraded.needsInterfaceTour, isTrue);
      await upgraded.markInterfaceTourSeen();
      await upgraded.setChildAge(4);
      expect(upgraded.needsInterfaceTour, isFalse);
      upgraded.dispose();

      final restarted = await GameController.load(store: store);
      expect(restarted.needsInterfaceTour, isFalse);
      expect(restarted.completedCount, 1);
      expect(restarted.progress, contains(levels[1].id));
      expect(restarted.totalStars, 3);
      expect(restarted.artworks, isEmpty);
      restarted.dispose();
    },
  );

  for (final language in ['ru', 'kk', 'en']) {
    testWidgets(
      'Fini visits real destinations and finishes once in $language',
      (tester) async {
        _viewport(tester, const Size(320, 568));
        final store = MemoryProgressStore();
        final controller = GameController.forTest(store: store);
        await controller.setLanguage(language);
        await controller.setReducedMotion(true);
        await controller.finishOnboarding();
        await tester.pumpWidget(_host(controller, textScale: 1.2));
        await _settle(tester);

        for (final step in InterfaceTourStep.values) {
          final tour = tester.widget<InterfaceTour>(find.byType(InterfaceTour));
          expect(tour.step, step);
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            step.tab,
          );
          expect(find.byKey(tour.target), findsOneWidget);
          for (final control in ['fini-tour-skip', 'fini-tour-next']) {
            expect(
              tester.getSize(find.byKey(Key(control))).height,
              greaterThanOrEqualTo(48),
            );
          }
          final target = tester.getRect(find.byKey(tour.target));
          expect(target.top, greaterThanOrEqualTo(0));
          expect(target.bottom, lessThanOrEqualTo(568));
          expect(tester.takeException(), isNull);
          await _captureStep(tester, '$language-phone-${step.name}');
          if (step == InterfaceTourStep.studio) {
            await _tap(tester, 'fini-tour-back');
            expect(
              tester.widget<InterfaceTour>(find.byType(InterfaceTour)).step,
              InterfaceTourStep.chapters,
            );
            await _tap(tester, 'fini-tour-next');
          }
          await _tap(tester, 'fini-tour-next');
        }
        expect(find.byType(InterfaceTour), findsNothing);
        expect(controller.needsInterfaceTour, isFalse);
        expect(controller.completedCount, 0);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        await _close(tester, controller);
        final restarted = await GameController.load(store: store);
        await tester.pumpWidget(_host(restarted));
        await _settle(tester);
        expect(find.byType(InterfaceTour), findsNothing);
        await _close(tester, restarted);
      },
    );
  }

  for (final size in [
    const Size(640, 320),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('tour survives rotation, lifecycle and back at ${size.width}', (
      tester,
    ) async {
      _viewport(tester, size);
      final controller = GameController.inMemory();
      await controller.setReducedMotion(true);
      await controller.finishOnboarding();
      await tester.pumpWidget(
        _host(controller, textScale: size.height <= 320 ? 1.5 : 1.3),
      );
      await _settle(tester);
      expect(
        find.byKey(const Key('fini-tour-next')).hitTestable(),
        findsOneWidget,
      );
      await _captureStep(tester, '${size.width.toInt()}-begin');
      await _tap(tester, 'fini-tour-next');
      expect(
        tester.widget<InterfaceTour>(find.byType(InterfaceTour)).step,
        InterfaceTourStep.chapters,
      );
      await _captureStep(tester, '${size.width.toInt()}-chapters');
      expect(
        find.byKey(const Key('fini-tour-next')).hitTestable(),
        findsOneWidget,
      );
      tester.view.physicalSize = Size(size.height, size.width);
      await _settle(tester);
      expect(
        tester.widget<InterfaceTour>(find.byType(InterfaceTour)).step,
        InterfaceTourStep.chapters,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      await _tap(tester, 'fini-tour-next');
      await _captureStep(tester, '${size.width.toInt()}-studio');
      tester.view.physicalSize = size;
      await _settle(tester);
      expect(
        tester.widget<InterfaceTour>(find.byType(InterfaceTour)).step,
        InterfaceTourStep.studio,
      );
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(InterfaceTour), findsNothing);
      expect(controller.needsInterfaceTour, isFalse);
      await _close(tester, controller);
    });
  }

  testWidgets('skip persists and Settings replays through the actual route', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final controller = GameController.inMemory();
    await controller.setReducedMotion(true);
    await controller.finishOnboarding();
    await tester.pumpWidget(_host(controller));
    await _settle(tester);
    await _tap(tester, 'fini-tour-skip');
    await _tap(tester, 'open-settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _tap(tester, 'settings-replay-fini-guide');
    expect(find.byType(SettingsScreen), findsNothing);
    expect(
      tester.widget<InterfaceTour>(find.byType(InterfaceTour)).step,
      InterfaceTourStep.begin,
    );
    await _tap(tester, 'fini-tour-skip');
    expect(controller.completedCount, 0);
    expect(tester.takeException(), isNull);
    await _close(tester, controller);
  });

  testWidgets(
    'sprite really changes frames, pauses in background and settles',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FiniCompanion(size: 120))),
      );
      await _settle(tester);
      final idle = tester
          .widget<CustomPaint>(find.byKey(const Key('fini-wave-sprite')))
          .painter;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FiniCompanion(size: 120))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      final waving = tester
          .widget<CustomPaint>(find.byKey(const Key('fini-wave-sprite')))
          .painter;
      expect(waving!.shouldRepaint(idle!), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 300));
      final paused = tester
          .widget<CustomPaint>(find.byKey(const Key('fini-wave-sprite')))
          .painter;
      expect(paused!.shouldRepaint(waving), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('system disabled animations holds the greeting frame still', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: FiniCompanion(size: 120)),
      ),
    );
    await _settle(tester);
    final before = tester
        .widget<CustomPaint>(find.byKey(const Key('fini-wave-sprite')))
        .painter;
    await tester.pump(const Duration(milliseconds: 750));
    final after = tester
        .widget<CustomPaint>(find.byKey(const Key('fini-wave-sprite')))
        .painter;
    expect(after!.shouldRepaint(before!), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
