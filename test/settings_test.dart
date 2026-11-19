import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/legacy_catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/features/settings/settings_screen.dart';
import 'package:tiny_trails/features/settings/child_age_picker.dart';

import 'support/widget_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> showSettings(
    WidgetTester tester,
    GameController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: RepaintBoundary(
          key: captureKey,
          child: SettingsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openGate(WidgetTester tester) async {
    final open = find.byKey(const ValueKey('open-parent-area'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  Future<void> solveGate(WidgetTester tester) async {
    final expression = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .firstWhere((text) => RegExp(r'^\d+ × \d+ = \?$').hasMatch(text));
    final values = RegExp(r'\d+')
        .allMatches(expression)
        .map((match) => int.parse(match.group(0)!))
        .toList();
    await tester.enterText(
      find.byKey(const ValueKey('parent-gate-answer')),
      '${values[0] * values[1]}',
    );
    await tester.tap(find.byKey(const ValueKey('parent-gate-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('language changes all settings copy immediately', (tester) async {
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await showSettings(tester, controller);
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(controller.language, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Spoken hints'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-kk')));
    await tester.pumpAndSettle();
    expect(controller.language, 'kk');
    expect(find.text('Баптаулар'), findsOneWidget);
    expect(find.text('Дауыстық кеңестер'), findsOneWidget);
  });

  testWidgets(
    'age accessibility names use the right words and remain actionable',
    (tester) async {
      var chosenAge = 0;
      for (final language in ['ru', 'kk', 'en']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: ChildAgePicker(
                language: language,
                selectedAge: 3,
                onChanged: (age) => chosenAge = age,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final age in [3, 4, 5, 11]) {
          final expected = switch (language) {
            'ru' => '$age ${age == 3 || age == 4 ? 'года' : 'лет'}',
            'kk' => '$age жас',
            _ => 'Age $age',
          };
          final semantics = tester.widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('child-age-$age')),
                  matching: find.byType(Semantics),
                )
                .first,
          );
          expect(semantics.properties.label, expected);
          expect(semantics.excludeSemantics, isTrue);
          semantics.properties.onTap!();
          expect(chosenAge, age);
        }
      }
    },
  );

  testWidgets('wrong parent answer cannot expose destructive action', (
    tester,
  ) async {
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await controller.completeLevel(levels.first);
    await showSettings(tester, controller);
    expect(find.byKey(const ValueKey('reset-progress')), findsNothing);
    await openGate(tester);
    await tester.enterText(
      find.byKey(const ValueKey('parent-gate-answer')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('parent-gate-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Попробуйте ещё раз'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-progress')), findsNothing);
    expect(controller.completedCount, 1);
  });

  testWidgets('all preference switches persist after reopening', (
    tester,
  ) async {
    final store = MemoryProgressStore();
    final controller = GameController.forTest(store: store);
    addTearDown(controller.dispose);
    await showSettings(tester, controller);
    for (final setting in [
      'sound',
      'music',
      'voice',
      'guidance',
      'haptics',
      'reduced-motion',
      'break-reminders',
    ]) {
      final toggle = find.byKey(ValueKey('setting-$setting'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    await controller.flush();
    final restored = await GameController.load(store: store);
    addTearDown(restored.dispose);
    expect(restored.sound, isFalse);
    expect(restored.musicEnabled, isTrue);
    expect(restored.voice, isFalse);
    expect(restored.guidanceEnabled, isFalse);
    expect(restored.haptics, isFalse);
    expect(restored.reducedMotion, isTrue);
    expect(restored.breakReminders, isFalse);
  });

  testWidgets('age choice requires parent gate and persists all three bands', (
    tester,
  ) async {
    final store = MemoryProgressStore();
    final controller = GameController.forTest(store: store);
    addTearDown(controller.dispose);
    await showSettings(tester, controller);
    expect(find.byKey(const ValueKey('child-age-3')), findsNothing);
    await openGate(tester);
    await solveGate(tester);
    for (final age in [3, 8, 11]) {
      final choice = find.byKey(ValueKey('child-age-$age'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(controller.childAge, age);
    }
    await controller.flush();
    final restored = await GameController.load(store: store);
    addTearDown(restored.dispose);
    expect(restored.childAge, 11);
  });

  testWidgets(
    'parent session relocks on interruption and invalidates pending reset',
    (tester) async {
      final controller = GameController.forTest();
      addTearDown(controller.dispose);
      await controller.completeLevel(levels.first);
      await showSettings(tester, controller);
      await openGate(tester);
      await solveGate(tester);
      final reset = find.byKey(const ValueKey('reset-progress'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-reset-progress')));
      await tester.pumpAndSettle();
      expect(controller.completedCount, 1);
      expect(find.byKey(const ValueKey('child-age-3')), findsNothing);
      expect(find.byKey(const ValueKey('reset-progress')), findsNothing);
      expect(find.byKey(const ValueKey('open-parent-area')), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed reset removes active and archived history after reopening',
    (tester) async {
      final oldLevel = legacyLevels.first;
      final legacySnapshot = jsonEncode({
        'version': 1,
        'settings': {'language': 'en', 'onboardingComplete': true},
        'progress': {
          oldLevel.id: {
            'stars': 3,
            'attempts': 1,
            'completedAt': '2026-11-16T10:00:00.000',
          },
        },
        'drafts': <String, dynamic>{},
        'artworks': <dynamic>[],
      });
      final store = MemoryProgressStore({
        GameController.legacyStorageKey: legacySnapshot,
        GameController.legacyBackupKey: legacySnapshot,
      });
      final controller = await GameController.load(store: store);
      addTearDown(controller.dispose);
      await controller.setChildAge(9);
      await controller.completeLevel(levels.first);
      expect(controller.hasLegacyArchive, isTrue);
      await showSettings(tester, controller);
      await openGate(tester);
      await solveGate(tester);
      final reset = find.byKey(const ValueKey('reset-progress'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('previous version will also be deleted'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-reset-progress')));
      await tester.pumpAndSettle();
      await controller.flush();
      final restored = await GameController.load(store: store);
      addTearDown(restored.dispose);
      expect(restored.completedCount, 0);
      expect(restored.hasLegacyArchive, isFalse);
      expect(restored.playedDates, isEmpty);
      expect(restored.childAge, 9);
      expect(restored.language, 'en');
    },
  );

  testWidgets(
    'failed reset keeps an honest error and offers a confirmed retry',
    (tester) async {
      final store = _ResetFailureStore();
      final controller = GameController.forTest(store: store);
      addTearDown(controller.dispose);
      await controller.setLanguage('en');
      await controller.completeLevel(levels.first);
      await showSettings(tester, controller);
      await openGate(tester);
      await solveGate(tester);
      final reset = find.byKey(const ValueKey('reset-progress'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      store.failWrites = true;
      await tester.tap(find.byKey(const ValueKey('confirm-reset-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Ready for a fresh adventure'), findsNothing);
      expect(controller.persistenceError, isNotNull);
      expect(find.text(controller.persistenceError!), findsWidgets);
      expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      store.failWrites = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('confirm-reset-progress')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-reset-progress')));
      await tester.pumpAndSettle();
      expect(controller.persistenceError, isNull);
      expect(find.text('Ready for a fresh adventure'), findsOneWidget);
    },
  );

  testWidgets('parent gate and second confirmation protect learning data', (
    tester,
  ) async {
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await controller.setLanguage('en');
    await controller.setSound(false);
    await controller.completeLevel(levels.first);
    await showSettings(tester, controller);
    await openGate(tester);
    await solveGate(tester);
    final reset = find.byKey(const ValueKey('reset-progress'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(controller.completedCount, 1);
    await tester.tap(find.text('Keep them'));
    await tester.pumpAndSettle();
    expect(controller.completedCount, 1);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-reset-progress')));
    await tester.pumpAndSettle();
    expect(controller.completedCount, 0);
    expect(controller.language, 'en');
    expect(controller.sound, isFalse);
  });

  testWidgets(
    'settings and parent controls fit enlarged full fonts across device sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(320, 568),
        const Size(844, 390),
        const Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final language in ['ru', 'kk', 'en']) {
          final controller = GameController.forTest();
          await controller.setLanguage(language);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: SettingsScreen(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language settings',
          );
          await openGate(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language gate',
          );
          await solveGate(tester);
          final age = find.byKey(const ValueKey('child-age-11'));
          await tester.ensureVisible(age);
          await tester.tap(age);
          await tester.pumpAndSettle();
          expect(controller.childAge, 11);
          await tester.ensureVisible(
            find.byKey(const ValueKey('reset-progress')),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language parent controls',
          );
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
    },
  );

  testWidgets('parent gate scrolls with the small-phone keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
            viewInsets: const EdgeInsets.only(bottom: 260),
          ),
          child: child!,
        ),
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await openGate(tester);
    expect(tester.takeException(), isNull);
    final answer = find.byKey(const ValueKey('parent-gate-answer'));
    await tester.ensureVisible(answer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture real-font settings and the unlocked age panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await controller.completeLevel(levels.first, stars: 1);
    await showSettings(tester, controller);
    await captureWidgetFixture(
      tester,
      'output/qa/v2-widget-settings-phone.png',
    );
    await openGate(tester);
    await solveGate(tester);
    expect(find.text('день открытий'), findsOneWidget);
    expect(find.text('звезда'), findsOneWidget);
    final age = find.byKey(const ValueKey('child-age-9'));
    await tester.ensureVisible(age);
    await tester.tap(age);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Для родителей')),
      alignment: 0,
    );
    await captureWidgetFixture(
      tester,
      'output/qa/v2-widget-settings-parent.png',
    );
    expect(tester.takeException(), isNull);
  });
}

class _ResetFailureStore extends MemoryProgressStore {
  bool failWrites = false;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Synthetic storage failure');
    await super.write(key, value);
  }
}
