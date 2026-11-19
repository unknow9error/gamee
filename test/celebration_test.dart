import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/shared/widgets/activity_tutorial.dart';
import 'package:tiny_trails/shared/widgets/celebration.dart';

void main() {
  for (final ageBand in AgeBand.values) {
    for (final language in ['ru', 'kk', 'en']) {
      for (final kind in ActivityKind.values) {
        testWidgets(
          'tutorial ${ageBand.name} $language ${kind.name} at phone and large text',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var dismissed = false;
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(),
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(320, 568),
                      textScaler: TextScaler.linear(1.5),
                    ),
                    child: ActivityTutorial(
                      kind: kind,
                      ageBand: ageBand,
                      language: language,
                      reducedMotion: true,
                      onDismiss: () => dismissed = true,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byType(FilledButton)).height,
              greaterThanOrEqualTo(48),
            );
            await tester.ensureVisible(find.byType(FilledButton));
            await tester.tap(find.byType(FilledButton));
            expect(dismissed, isTrue);
            await tester.pumpAndSettle();
            expect(tester.hasRunningAnimations, isFalse);
          },
        );
      }
    }
  }

  for (final kind in ActivityKind.values) {
    testWidgets('celebration ${kind.name} is immediately navigable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var next = 0;
      final level = LevelDefinition(
        id: 'test',
        worldId: 'ocean',
        kind: kind,
        scene: 'whale',
        illustrationAsset: kind.index > ActivityKind.hiddenAnimals.index
            ? 'assets/images/levels/test-unavailable.png'
            : null,
        variant: 0,
        difficulty: 1,
        title: const LocalizedText('Тест', 'Тест', 'Test'),
        instruction: const LocalizedText('Тест', 'Тест', 'Test'),
        order: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showCelebration(
                  context,
                  level: level,
                  reward: const CompletionReward(
                    stars: 3,
                    newAchievements: [],
                    firstCompletion: true,
                  ),
                  language: 'ru',
                  reducedMotion: true,
                  onNext: () => next++,
                  onHome: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.ensureVisible(find.text('Дальше играть'));
      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Дальше играть'),
      );
      nextButton.onPressed!();
      nextButton.onPressed!();
      await tester.pumpAndSettle();
      expect(next, 1);
      expect(find.byType(Dialog), findsNothing);
    });
  }
  testWidgets('tutorial gesture ends after a short demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ActivityTutorial(
            kind: ActivityKind.ropeTrace,
            language: 'en',
            reducedMotion: false,
            onDismiss: () {},
          ),
        ),
      ),
    );
    for (var cycle = 0; cycle < 4; cycle++) {
      await tester.pump(const Duration(milliseconds: 2300));
    }
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
