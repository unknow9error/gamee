import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/features/home/onboarding_screen.dart';
import 'package:tiny_trails/shared/widgets/fini_companion.dart';

import 'support/widget_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speechChannel = MethodChannel('tiny_trails/speech');
  setUp(() {
    // A cached loadString Future belongs to its originating FakeAsync zone.
    // Keep fixture instances independent while using the real bundled bytes.
    rootBundle.evict('assets/audio/narration/manifest.json');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          speechChannel,
          (call) async => call.method == 'isAvailable' ? false : true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, null);
  });

  void onboardingWidgetTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        // Dispose while the fake clock is still controlled by this test. The
        // bounded native-stop timeout must finish before invariant checking.
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      }
    });
  }

  setUpAll(() async {
    final fonts = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'the final Fini illustration is bundled and decodes as real artwork',
    () async {
      final bytes = await rootBundle.load('assets/images/fini.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 256,
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, greaterThan(200));
      frame.image.dispose();
      codec.dispose();
    },
  );

  Future<void> settleNarration(WidgetTester tester) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.byKey(const Key('onboarding-speak')).evaluate().isNotEmpty) {
        return;
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }
    expect(
      find.byKey(const Key('onboarding-speak')),
      findsOneWidget,
      reason: 'The bundled onboarding narration must be available without installed TTS',
    );
  }

  Future<void> showOnboarding(
    WidgetTester tester,
    GameController controller, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: OnboardingScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (controller.voice) await settleNarration(tester);
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
  }

  void expectLanguageLabelsCentered(WidgetTester tester, String scenario) {
    for (final language in const [
      ('ru', 'Русский'),
      ('kk', 'Қазақша'),
      ('en', 'English'),
    ]) {
      final button = find.byKey(ValueKey('onboarding-language-${language.$1}'));
      final label = find.descendant(
        of: button,
        matching: find.text(language.$2),
      );
      final buttonRect = tester.getRect(button);
      final labelRect = tester.getRect(label);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final naturalText = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: 1,
      )..layout(maxWidth: labelRect.width);
      final naturalHeight = naturalText.height;
      naturalText.dispose();
      // A paragraph stretched by minHeight can have a centered box while its
      // letters remain at the top. Check its natural line as well as its box.
      expect(
        labelRect.height,
        closeTo(naturalHeight, .1),
        reason:
            '$scenario ${language.$1} must not reserve space below its text',
      );
      expect(
        (labelRect.center - buttonRect.center).distance,
        lessThan(.1),
        reason: '$scenario ${language.$1} text must sit in the button center',
      );
      expect(buttonRect.width, greaterThanOrEqualTo(48));
      expect(buttonRect.height, greaterThanOrEqualTo(52));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$scenario ${language.$1} native name must remain complete',
      );
    }
  }

  onboardingWidgetTest(
    'age must be chosen before finishing and is saved without personal details',
    (tester) async {
      final store = MemoryProgressStore();
      final controller = GameController.forTest(store: store);
      addTearDown(controller.dispose);
      await showOnboarding(tester, controller);
      expect(find.textContaining('20 разных игр'), findsOneWidget);
      await next(tester);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('onboarding-next')),
      );
      expect(button.onPressed, isNull);
      expect(controller.onboardingComplete, isFalse);
      final age = find.byKey(const ValueKey('onboarding-age-3'));
      await tester.ensureVisible(age);
      await tester.tap(age);
      await tester.pumpAndSettle();
      expect(controller.childAge, 3);
      await next(tester);
      expect(find.text('20 наклеек для коллекции'), findsOneWidget);
      await next(tester);
      await controller.flush();
      final restored = await GameController.load(store: store);
      addTearDown(restored.dispose);
      expect(restored.childAge, 3);
      expect(restored.onboardingComplete, isTrue);
      expect(find.byType(TextField), findsNothing);
    },
  );

  onboardingWidgetTest('skipping introduction still requires age selection', (
    tester,
  ) async {
    final controller = GameController.forTest();
    addTearDown(controller.dispose);
    await showOnboarding(tester, controller);
    await tester.tap(find.byKey(const Key('onboarding-skip-intro')));
    await tester.pumpAndSettle();
    expect(controller.onboardingComplete, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
          .onPressed,
      isNull,
    );
    await tester.drag(
      find.byKey(const Key('onboarding-pages')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
          .onPressed,
      isNull,
    );
  });

  onboardingWidgetTest(
    'language and age can be revised before entering the game',
    (tester) async {
      final controller = GameController.forTest();
      addTearDown(controller.dispose);
      await showOnboarding(tester, controller);
      final english = find.byKey(const ValueKey('onboarding-language-en'));
      await tester.ensureVisible(english);
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(controller.language, 'en');
      await next(tester);
      final age = find.byKey(const ValueKey('onboarding-age-11'));
      await tester.ensureVisible(age);
      await tester.tap(age);
      await tester.pumpAndSettle();
      await next(tester);
      await tester.tap(find.byKey(const Key('onboarding-back')));
      await tester.pumpAndSettle();
      final revisedAge = find.byKey(const ValueKey('onboarding-age-6'));
      await tester.ensureVisible(revisedAge);
      await tester.tap(revisedAge);
      await tester.pumpAndSettle();
      expect(controller.childAge, 6);
      expect(controller.onboardingComplete, isFalse);
    },
  );

  onboardingWidgetTest(
    'system reduced motion removes decorative onboarding animation',
    (tester) async {
      final controller = GameController.forTest();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: OnboardingScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .every((indicator) => indicator.duration == Duration.zero),
        isTrue,
      );
      expect(
        tester
            .widgetList<FiniCompanion>(find.byType(FiniCompanion))
            .every((companion) => companion.reducedMotion),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
            .onPressed,
        isNull,
      );
    },
  );

  onboardingWidgetTest(
    'all three pages offer bundled speech in every locale with TTS unavailable',
    (tester) async {
      const channel = MethodChannel('tiny_trails/speech');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      for (final language in ['ru', 'kk', 'en']) {
        final controller = GameController.forTest();
        await controller.setLanguage(language);
        await showOnboarding(tester, controller);
        await next(tester);
        await settleNarration(tester);
        final age = find.byKey(const ValueKey('onboarding-age-3'));
        await tester.ensureVisible(age);
        await tester.tap(age);
        await tester.pumpAndSettle();
        await next(tester);
        await settleNarration(tester);
        await controller.setVoice(false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('onboarding-speak')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    },
  );

  onboardingWidgetTest(
    'full fonts and all locales fit phone landscape and tablet at enlarged text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(320, 568),
        const Size(393, 852),
        const Size(844, 390),
        const Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final language in ['ru', 'kk', 'en']) {
          final controller = GameController.forTest();
          await controller.setLanguage(language);
          await showOnboarding(tester, controller, textScale: 1.3);
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language welcome',
          );
          final languageChoice = find.byKey(
            ValueKey('onboarding-language-$language'),
          );
          await tester.ensureVisible(languageChoice);
          expectLanguageLabelsCentered(tester, '$size $language at 1.3x');
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language languages',
          );
          await next(tester);
          final age = find.byKey(const ValueKey('onboarding-age-11'));
          await tester.ensureVisible(age);
          await tester.tap(age);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size $language age');
          await next(tester);
          final lastBenefit = find.text(switch (language) {
            'kk' => 'Интернетсіз және жарнамасыз ойнаймыз',
            'en' => 'Play offline, without ads',
            _ => 'Играем без интернета и рекламы',
          });
          await tester.ensureVisible(lastBenefit);
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $language rewards',
          );
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  onboardingWidgetTest(
    'language names remain centered and selectable at double system text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = GameController.forTest();
      addTearDown(controller.dispose);
      await showOnboarding(tester, controller, textScale: 2);
      for (final language in ['ru', 'kk', 'en']) {
        final choice = find.byKey(ValueKey('onboarding-language-$language'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expectLanguageLabelsCentered(tester, '320dp $language at 2x');
        expect(tester.takeException(), isNull);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(controller.language, language);
        await tester.ensureVisible(choice);
        await captureWidgetFixture(
          tester,
          'output/qa/onboarding-language-$language-double-text.png',
          images: const [AssetImage('assets/images/fini-wave-sheet.png')],
        );
      }
    },
  );

  onboardingWidgetTest(
    'capture centered language labels with real fonts in every locale',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final layout in const [
        (Size(393, 852), 1.0, 'phone'),
        (Size(320, 568), 1.3, 'small-large-text'),
      ]) {
        tester.view.physicalSize = layout.$1;
        for (final language in ['ru', 'kk', 'en']) {
          final controller = GameController.forTest();
          await controller.setLanguage(language);
          await showOnboarding(tester, controller, textScale: layout.$2);
          final choice = find.byKey(ValueKey('onboarding-language-$language'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expectLanguageLabelsCentered(tester, '${layout.$3} $language');
          await captureWidgetFixture(
            tester,
            'output/qa/onboarding-language-$language-${layout.$3}.png',
            images: const [AssetImage('assets/images/fini-wave-sheet.png')],
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
    },
  );

  onboardingWidgetTest(
    'capture the real-font onboarding with final Fini artwork',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = GameController.forTest();
      addTearDown(controller.dispose);
      await showOnboarding(tester, controller);
      await captureWidgetFixture(
        tester,
        'output/qa/v2-widget-onboarding-phone.png',
        images: const [AssetImage('assets/images/fini-wave-sheet.png')],
      );
      await next(tester);
      await settleNarration(tester);
      await captureWidgetFixture(
        tester,
        'output/qa/v2-widget-onboarding-age.png',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
