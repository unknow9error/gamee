import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/app_audio_scope.dart';
import 'package:tiny_trails/core/feedback_service.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/choice_activity.dart';
import 'package:tiny_trails/features/play/color_activity.dart';
import 'package:tiny_trails/features/play/connect_dots_activity.dart';
import 'package:tiny_trails/features/play/content/matching_layouts.dart';
import 'package:tiny_trails/features/play/drawing_activity.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';
import 'package:tiny_trails/features/play/engines/raster_color_asset.dart';
import 'package:tiny_trails/features/play/hidden_activity.dart';
import 'package:tiny_trails/features/play/matching_activity.dart';
import 'package:tiny_trails/features/play/maze_activity.dart';
import 'package:tiny_trails/features/play/play_screen.dart';
import 'package:tiny_trails/features/play/rope_activity.dart';
import 'package:tiny_trails/main.dart';
import 'package:tiny_trails/shared/widgets/activity_tutorial.dart';

class _FeedbackProbe extends FeedbackService {
  final music = <bool>[];
  final paused = <bool>[];
  final speech =
      <({String text, String language, bool enabled, String? key})>[];
  var disposed = 0;

  @override
  Future<bool> isSpeechAvailable(
    String language, {
    String? narrationKey,
  }) async => true;
  @override
  Future<void> speak(
    String text,
    String language, {
    required bool enabled,
    String? narrationKey,
  }) async {
    speech.add((
      text: text,
      language: language,
      enabled: enabled,
      key: narrationKey,
    ));
  }

  @override
  Future<void> setMusicEnabled(bool enabled) async => music.add(enabled);
  @override
  Future<void> setPaused(bool value) async => paused.add(value);
  @override
  Future<void> tap({required bool sound, required bool haptics}) async {}
  @override
  Future<void> success({required bool sound, required bool haptics}) async {}
  @override
  void dispose() => disposed++;
}

class _FailingPrimaryStore extends MemoryProgressStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail && key == GameController.storageKey) {
      throw StateError('Synthetic storage refusal');
    }
    await super.write(key, value);
  }
}

class _UnreadableStore extends MemoryProgressStore {
  bool failRead = false;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('Synthetic read refusal');
    return super.read(key);
  }
}

class _DelayedVoiceProbe extends _FeedbackProbe {
  final available = Completer<bool>();
  @override
  Future<bool> isSpeechAvailable(String language, {String? narrationKey}) =>
      available.future;
}

class _BreakClock implements Stopwatch {
  Duration time = const Duration(minutes: 16);
  bool running = false;
  @override
  Duration get elapsed => time;
  @override
  int get elapsedMicroseconds => time.inMicroseconds;
  @override
  int get elapsedMilliseconds => time.inMilliseconds;
  @override
  int get elapsedTicks => time.inMicroseconds;
  @override
  int get frequency => 1000000;
  @override
  bool get isRunning => running;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
  @override
  void reset() => time = Duration.zero;
}

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

ActivityConfig _activeConfig(WidgetTester tester, ActivityKind kind) =>
    switch (kind) {
      ActivityKind.numberColor || ActivityKind.freeColor =>
        tester.widget<ColorActivity>(find.byType(ColorActivity)).config,
      ActivityKind.oddFragment ||
      ActivityKind.patternSequence ||
      ActivityKind.missingPuzzle =>
        tester.widget<ChoiceActivity>(find.byType(ChoiceActivity)).config,
      ActivityKind.connectDots =>
        tester
            .widget<ConnectDotsActivity>(find.byType(ConnectDotsActivity))
            .config,
      ActivityKind.matchPairs =>
        tester.widget<MatchingActivity>(find.byType(MatchingActivity)).config,
      ActivityKind.maze =>
        tester.widget<MazeActivity>(find.byType(MazeActivity)).config,
      ActivityKind.ropeTrace =>
        tester.widget<RopeActivity>(find.byType(RopeActivity)).config,
      ActivityKind.guidedDraw =>
        tester.widget<DrawingActivity>(find.byType(DrawingActivity)).config,
      ActivityKind.hiddenAnimals =>
        tester.widget<HiddenActivity>(find.byType(HiddenActivity)).config,
    };

Future<void> _waitForBoard(WidgetTester tester, ActivityKind kind) async {
  final board = find.byKey(ValueKey(_boardKey(kind)));
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (board.evaluate().isNotEmpty &&
        imageCache.pendingImageCount == 0 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(board, findsOneWidget);
  await _settle(tester);
}

Future<GameController> _controller({
  ProgressStore? store,
  Stopwatch? clock,
  int age = 6,
  bool onboarding = true,
}) async {
  final c = GameController.forTest(store: store, sessionClock: clock);
  await c.setChildAge(age);
  await c.setReducedMotion(true);
  await c.setSound(false);
  await c.setHaptics(false);
  await c.setVoice(false);
  await c.setGuidanceEnabled(false);
  await c.setBreakReminders(false);
  if (onboarding) await c.finishOnboarding();
  return c;
}

Future<void> _open(
  WidgetTester tester,
  GameController c,
  LevelDefinition level, {
  _FeedbackProbe? audio,
}) async {
  final probe = audio ?? _FeedbackProbe();
  await tester.pumpWidget(
    TinyTrailsApp(controller: c, feedbackFactory: () => probe),
  );
  await _settle(tester);
  final guideSkip = find.byKey(const Key('fini-tour-skip'));
  if (guideSkip.evaluate().isNotEmpty) {
    await tester.tap(guideSkip);
    await _settle(tester);
  }
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PlayScreen(controller: c, level: level),
    ),
  );
  await _waitForBoard(tester, level.kind);
}

final _colorSpecs = <String, ColorSceneSpec>{};
ColorSceneSpec _colorSpec(LevelDefinition level) => _colorSpecs[level.id]!;

Future<void> _paint(
  WidgetTester tester,
  ColorSceneSpec spec,
  ColorRegionSpec region,
  AgeBand band,
) async {
  final palette = find.byKey(
    ValueKey('raster-palette-${spec.acceptedPaletteIdFor(region, band)}'),
  );
  await _showTarget(tester, palette);
  await tester.tap(palette);
  await tester.pump();
  final rect = tester.getRect(find.byKey(const Key('color-canvas')));
  await tester.tapAt(
    rect.topLeft +
        Offset(region.anchor.dx * rect.width, region.anchor.dy * rect.height),
  );
  await tester.pump();
}

Future<void> _solveColor(
  WidgetTester tester,
  LevelDefinition level,
  AgeBand band,
) async {
  final spec = _colorSpec(level);
  for (final region in spec.regionsFor(band)) {
    await _paint(tester, spec, region, band);
  }
  final finish = find.byKey(const Key('color-finish'));
  expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
  await tester.tap(finish);
  await _settle(tester);
}

Future<void> _closeApp(WidgetTester tester, GameController c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await c.flush();
  c.dispose();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // Shared cached futures must be created in the real async zone, rather
    // than retaining the first widget test's now-frozen fake scheduler.
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

  testWidgets(
    'onboarding requires an age and opens the actual 20-activity home',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await _controller(onboarding: false);
      final audio = _FeedbackProbe();
      await tester.pumpWidget(
        TinyTrailsApp(controller: c, feedbackFactory: () => audio),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await _settle(tester);
      final next = find.byKey(const Key('onboarding-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await _showTarget(tester, find.byKey(const ValueKey('onboarding-age-9')));
      await tester.tap(find.byKey(const ValueKey('onboarding-age-9')));
      await tester.pump();
      await tester.tap(next);
      await _settle(tester);
      await tester.tap(next);
      await _settle(tester);
      expect(c.childAge, 9);
      expect(c.onboardingComplete, isTrue);
      expect(find.byKey(const Key('fini-interface-tour')), findsOneWidget);
      final guideSkip = find.byKey(const Key('fini-tour-skip'));
      expect(guideSkip, findsOneWidget);
      await tester.tap(guideSkip);
      await _settle(tester);
      expect(find.byKey(const Key('fini-interface-tour')), findsNothing);
      expect(guideSkip, findsNothing);
      expect(find.byKey(const Key('continue-adventure')), findsOneWidget);
      final count = tester
          .widget<Text>(find.byKey(const Key('home-catalog-count')))
          .data!;
      expect(count, contains('20'));
      expect(count, isNot(contains('120')));
      await tester.tap(find.byType(NavigationDestination).at(1));
      await _settle(tester);
      expect(find.byKey(const PageStorageKey('studio-scroll')), findsOneWidget);
      await tester.tap(find.byType(NavigationDestination).at(2));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'a real color lesson awards once, keeps its art, and survives restart',
    (tester) async {
      final store = MemoryProgressStore();
      final c = await _controller(store: store);
      final level = levels.first;
      await _open(tester, c, level);
      expect(_activeConfig(tester, level.kind).childAge, c.childAge);
      await _solveColor(tester, level, c.ageBand);
      expect(c.completedCount, 1);
      expect(c.totalStars, 3);
      expect(c.earnedStickers, hasLength(1));
      expect(c.artworks, hasLength(1));
      expect(c.artworks.single.levelId, level.id);
      expect(c.artworks.single.data['fills'], isNotEmpty);
      final restarted = await GameController.load(store: store);
      expect(restarted.completedCount, 1);
      expect(restarted.artworks.single.id, c.artworks.single.id);
      expect(restarted.earnedStickers.single.id, c.earnedStickers.single.id);
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
      restarted.dispose();
    },
  );

  testWidgets(
    'failed completion keeps finished work and Retry commits without a duplicate reward',
    (tester) async {
      final store = _FailingPrimaryStore();
      final c = await _controller(store: store);
      final level = levels.first;
      await _open(tester, c, level);
      store.fail = true;
      await _solveColor(tester, level, c.ageBand);
      expect(c.completedCount, 0);
      expect(c.artworks, isEmpty);
      expect(c.draftFor(level.id)?['fills'], isNotEmpty);
      expect(find.byKey(const Key('retry-completion')), findsOneWidget);
      expect(find.text('Дальше играть'), findsNothing);
      store.fail = false;
      await tester.tap(find.byKey(const Key('retry-completion')));
      await _settle(tester);
      expect(c.completedCount, 1);
      expect(c.artworks, hasLength(1));
      expect(c.totalStars, 3);
      expect(c.earnedStickers, hasLength(1));
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets('system Back waits for a failed save and lets the child stay', (
    tester,
  ) async {
    final store = _FailingPrimaryStore();
    final c = await _controller(store: store);
    final level = levels.first;
    await _open(tester, c, level);
    store.fail = true;
    final spec = _colorSpec(level);
    await _paint(tester, spec, spec.regionsFor(c.ageBand).first, c.ageBand);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Работа ещё не сохранена'), findsOneWidget);
    expect(find.byType(PlayScreen), findsOneWidget);
    await tester.tap(find.text('Остаться'));
    await _settle(tester);
    store.fail = false;
    await tester.tap(find.byKey(const Key('retry-completion')));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(PlayScreen), findsNothing);
    expect(c.draftFor(level.id)?['fills'], isNotEmpty);
    expect(tester.takeException(), isNull);
    await _closeApp(tester, c);
  });

  testWidgets(
    'Retry recovers an initial storage read error before the first input',
    (tester) async {
      final store = _UnreadableStore();
      final seed = await _controller(store: store);
      await seed.completeLevel(levels[1]);
      seed.dispose();
      store.failRead = true;
      final c = await GameController.load(store: store);
      await c.setVoice(false);
      await c.setSound(false);
      await c.setHaptics(false);
      await c.setGuidanceEnabled(false);
      await c.setReducedMotion(true);
      await c.finishOnboarding();
      expect(c.completedCount, 0);
      expect(c.persistenceError, isNotNull);
      await _open(tester, c, levels.first);
      store.failRead = false;
      await tester.tap(find.byKey(const Key('retry-completion')));
      await _settle(tester);
      expect(c.completedCount, 1);
      expect(c.progress, contains(levels[1].id));
      expect(c.persistenceError, isNull);
      expect(find.byKey(const Key('play-save-notice')), findsNothing);
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'late voice availability cannot narrate a task after leaving it',
    (tester) async {
      final c = await _controller();
      await c.setVoice(true);
      final audio = _DelayedVoiceProbe();
      await _open(tester, c, levels.first, audio: audio);
      await tester.tap(find.byTooltip('Сохранить и выйти'));
      await tester.pump();
      audio.available.complete(true);
      await _settle(tester);
      expect(find.byType(PlayScreen), findsNothing);
      expect(
        audio.speech.where(
          (event) => event.enabled && event.key == levels.first.voiceKey,
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'a full album can be managed without dropping the finished drawing',
    (tester) async {
      final c = await _controller();
      final level = levels.first;
      for (var i = 0; i < GameController.maxArtworks; i++) {
        await c.completeLevel(
          level,
          artwork: {'version': 1, 'fixture': 'earlier artwork $i'},
        );
      }
      final oldId = c.artworks.first.id;
      await _open(tester, c, level);
      await _solveColor(tester, level, c.ageBand);
      expect(c.artworks.length, GameController.maxArtworks);
      expect(find.byKey(const Key('manage-artworks')), findsOneWidget);
      expect(c.draftFor(level.id)?['fills'], isNotEmpty);
      await tester.tap(find.byKey(const Key('manage-artworks')));
      await _settle(tester);
      final card = find.byKey(ValueKey('artwork-$oldId'));
      await _showTarget(tester, card);
      await tester.tap(card);
      await _settle(tester);
      final delete = find.byKey(const Key('delete-artwork'));
      await _showTarget(tester, delete);
      await tester.tap(delete);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await _settle(tester);
      expect(c.artworks.length, GameController.maxArtworks - 1);
      await tester.tap(find.byType(BackButton).last);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('retry-completion')));
      await _settle(tester);
      expect(c.artworks.length, GameController.maxArtworks);
      expect(c.artworks.first.data['fills'], isNotEmpty);
      expect(
        c.artworks.map((work) => work.id).toSet().length,
        GameController.maxArtworks,
      );
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'global Next crosses a chapter and puzzle results do not enter the art album',
    (tester) async {
      final c = await _controller();
      final level = levels.firstWhere((item) => item.id == 'v2_04');
      await _open(tester, c, level);
      final layout = matchingLayoutFor(level, c.childAge);
      for (final pair in layout.pairIds) {
        for (final card in layout.cards.where((card) => card.pairId == pair)) {
          await tester.tap(find.byKey(ValueKey('matching-card-${card.id}')));
          await tester.pump();
        }
      }
      await tester.tap(find.byKey(const Key('matching-finish')));
      await _settle(tester);
      expect(c.completedCount, 1);
      expect(c.artworks, isEmpty);
      await tester.tap(find.text('Дальше играть'));
      await _waitForBoard(tester, ActivityKind.patternSequence);
      final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
      expect(play.level.id, 'v2_05');
      expect(find.text('УРОВЕНЬ 5 / 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'a saved completion can suggest a break, and continuing remains optional',
    (tester) async {
      final clock = _BreakClock();
      final c = await _controller(clock: clock);
      await c.setBreakReminders(true);
      await _open(tester, c, levels.first);
      expect(find.byKey(const Key('break-keep-playing')), findsNothing);
      await _solveColor(tester, levels.first, c.ageBand);
      await tester.tap(find.text('Дальше играть'));
      await _settle(tester);
      expect(find.byKey(const Key('break-keep-playing')), findsOneWidget);
      expect(c.completedCount, 1);
      await tester.tap(find.byKey(const Key('break-keep-playing')));
      await _waitForBoard(tester, ActivityKind.oddFragment);
      expect(c.shouldSuggestBreak, isFalse);
      expect(
        tester.widget<PlayScreen>(find.byType(PlayScreen)).level.id,
        'v2_02',
      );
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'age-aware guidance can be disabled while manual help and recorded narration stay available',
    (tester) async {
      final c = await _controller(age: 3);
      final audio = _FeedbackProbe();
      await c.setGuidanceEnabled(true);
      await _open(tester, c, levels.first, audio: audio);
      final tutorial = tester.widget<ActivityTutorial>(
        find.byType(ActivityTutorial),
      );
      expect(tutorial.ageBand, AgeBand.preschool);
      expect(tutorial.level?.id, levels.first.id);
      await _showTarget(tester, find.text('Начать играть'));
      await tester.tap(find.text('Начать играть'));
      await _settle(tester);
      await c.setGuidanceEnabled(false);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PlayScreen(controller: c, level: levels[1]),
        ),
      );
      await _waitForBoard(tester, levels[1].kind);
      expect(find.byType(ActivityTutorial), findsNothing);
      await c.setVoice(true);
      await tester.tap(find.byTooltip('Послушать задание'));
      await _settle(tester);
      expect(audio.speech.last.key, levels[1].voiceKey);
      expect(audio.speech.last.enabled, isTrue);
      await tester.tap(find.byTooltip('Как играть'));
      await _settle(tester);
      expect(find.byType(ActivityTutorial), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _closeApp(tester, c);
    },
  );

  testWidgets(
    'creative replay is available only after completing that authored lesson',
    (tester) async {
      final level = levels.first;
      final requested = LevelDefinition(
        id: level.id,
        worldId: level.worldId,
        kind: level.kind,
        scene: level.scene,
        variant: level.variant,
        difficulty: level.difficulty,
        order: level.order,
        title: level.title,
        instruction: level.instruction,
        illustrationAsset: level.illustrationAsset,
        voiceKey: level.voiceKey,
        activityData: {...level.activityData, 'creativeReplay': true},
      );
      final fresh = await _controller();
      await _open(tester, fresh, requested);
      expect(
        _activeConfig(tester, level.kind).level.activityData['creativeReplay'],
        isNot(true),
      );
      expect(find.text('Твои цвета'), findsNothing);
      await _closeApp(tester, fresh);
      final completed = await _controller();
      await completed.completeLevel(level);
      await _open(tester, completed, requested);
      expect(
        _activeConfig(tester, level.kind).level.activityData['creativeReplay'],
        isTrue,
      );
      expect(find.text('Твои цвета'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('color-finish')))
            .onPressed,
        isNull,
        reason: 'A blank creative replay is not a new finished artwork.',
      );
      expect(levels, hasLength(20));
      expect(tester.takeException(), isNull);
      await _closeApp(tester, completed);
    },
  );

  testWidgets(
    'one global audio session follows preferences, narration ownership, and foreground state',
    (tester) async {
      final clock = _BreakClock()..time = Duration.zero;
      final c = await _controller(clock: clock);
      final audio = _FeedbackProbe();
      await tester.pumpWidget(
        TinyTrailsApp(controller: c, feedbackFactory: () => audio),
      );
      await _settle(tester);
      expect(audio.music.last, isFalse);
      await c.setMusicEnabled(true);
      await tester.pump();
      expect(audio.music.last, isTrue);
      final scope = tester.widget<AppAudioScope>(find.byType(AppAudioScope));
      final oldOwner = Object(), newOwner = Object();
      await scope.narration.speak(
        oldOwner,
        'Старое задание',
        'ru',
        enabled: true,
        narrationKey: 'v2_01',
      );
      await scope.narration.speak(
        newOwner,
        'Новое задание',
        'ru',
        enabled: true,
        narrationKey: 'v2_02',
      );
      final events = audio.speech.length;
      await scope.narration.stop(oldOwner);
      expect(
        audio.speech.length,
        events,
        reason: 'Leaving an old route must not stop the next instruction.',
      );
      await c.setVoice(true);
      await c.setVoice(false);
      await tester.pump();
      expect(audio.speech.last.enabled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(audio.paused.last, isTrue);
      expect(clock.running, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.paused.last, isFalse);
      expect(clock.running, isTrue);
      expect(
        AppAudioScope.of(tester.element(find.byType(Navigator).first)),
        same(audio),
      );
      await _closeApp(tester, c);
      expect(audio.disposed, 1);
    },
  );

  for (final age in [3, 6, 9]) {
    for (final kind in activeActivityKinds) {
      testWidgets(
        'full ${kind.name} age $age retains a usable board through phone, landscape, and tablet',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = await _controller(age: age);
          final audio = _FeedbackProbe();
          final level = levels.firstWhere((level) => level.kind == kind);
          await tester.pumpWidget(
            AppAudioScope(
              feedback: audio,
              child: MaterialApp(
                theme: buildTheme(),
                home: PlayScreen(controller: c, level: level),
              ),
            ),
          );
          for (final size in [
            const Size(320, 568),
            const Size(844, 390),
            const Size(768, 1024),
          ]) {
            tester.view.physicalSize = size;
            await _waitForBoard(tester, kind);
            final board = tester.getSize(find.byKey(ValueKey(_boardKey(kind))));
            expect(
              board.shortestSide,
              greaterThanOrEqualTo(220),
              reason:
                  'The complete $kind age $age screen at $size must leave room for finger input.',
            );
            final config = _activeConfig(tester, kind);
            expect(config.childAge, age);
            expect(config.ageBand, AgeBand.fromAge(age));
            expect(config.onSpeak, isNotNull);
            expect(tester.takeException(), isNull);
          }
          await _closeApp(tester, c);
          audio.dispose();
        },
      );
    }
  }
}
