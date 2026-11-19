import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/content/dots_rope_layouts.dart';
import 'package:tiny_trails/content/tracing_layouts.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/connect_dots_activity.dart';
import 'package:tiny_trails/features/play/content/choice_layouts.dart';
import 'package:tiny_trails/features/play/content/matching_layouts.dart';
import 'package:tiny_trails/features/play/engines/dots_engine.dart';
import 'package:tiny_trails/features/play/engines/hidden_picture.dart';
import 'package:tiny_trails/features/play/engines/maze_engine.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';
import 'package:tiny_trails/features/play/play_screen.dart';
import 'package:tiny_trails/features/play/raster_color_activity.dart';
import 'package:tiny_trails/features/play/rope_activity.dart';
import 'package:tiny_trails/main.dart';

var _childAge = 6;
AgeBand get _ageBand => AgeBand.fromAge(_childAge);
String get _storagePrefix => 'integration.v2.${_ageBand.name}.age$_childAge.';
final _verifiedLevelIds = <String>[];
final _verifiedAudioLocales = <String>[];
final _nativeSemantics = <String, Object?>{};

/// iOS Simulator enables its platform-owned semantics handle asynchronously in
/// viewDidAppear. Settle that native initialization before testWidgets records
/// its handle baseline, while keeping its normal semantics and leak checks.
void _installSimulatorSemanticsFixture(
  IntegrationTestWidgetsFlutterBinding binding,
) {
  if (!const bool.fromEnvironment('QA_IOS_SIMULATOR')) return;
  SemanticsHandle? fixture;
  setUpAll(() async {
    expect(Platform.isIOS, isTrue, reason: 'This fixture is simulator-only.');
    _nativeSemantics.addAll({
      'requested': true,
      'platformEnabledBefore': ui.PlatformDispatcher.instance.semanticsEnabled,
      'handlesBefore': binding.debugOutstandingSemanticsHandles,
    });
    fixture = binding.ensureSemantics();
    try {
      final elapsed = Stopwatch()..start();
      while (!ui.PlatformDispatcher.instance.semanticsEnabled) {
        if (elapsed.elapsed >= const Duration(seconds: 5)) {
          throw TimeoutException(
            'Native simulator semantics did not initialize.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      // Let the native semantics callback finish creating its own handle.
      await Future<void>.delayed(Duration.zero);
      _nativeSemantics.addAll({
        'platformEnabledAfter': ui.PlatformDispatcher.instance.semanticsEnabled,
        'handlesAfterSetup': binding.debugOutstandingSemanticsHandles,
      });
      expect(
        binding.debugOutstandingSemanticsHandles,
        2,
        reason:
            'Only our fixture and the acknowledged native handle may exist.',
      );
    } catch (_) {
      fixture?.dispose();
      fixture = null;
      rethrow;
    }
  });
  tearDownAll(() async {
    fixture?.dispose();
    fixture = null;
    await Future<void>.delayed(Duration.zero);
    final nativeEnabled = ui.PlatformDispatcher.instance.semanticsEnabled;
    final expectedHandles = nativeEnabled ? 1 : 0;
    _nativeSemantics.addAll({
      'platformEnabledAtTeardown': nativeEnabled,
      'expectedHandlesAfterTeardown': expectedHandles,
      'handlesAfterTeardown': binding.debugOutstandingSemanticsHandles,
    });
    expect(
      binding.debugOutstandingSemanticsHandles,
      expectedHandles,
      reason: 'Dispose only our fixture; the remaining handle belongs to iOS.',
    );
    _nativeSemantics['teardownVerified'] = true;
  });
}

/// Exercise the actual platform MP3 decoder and completion stream. Muting the
/// player avoids disturbing the user; this verifies playback, not pronunciation.
Future<void> _probeBundledNarration() async {
  for (final language in const ['ru', 'kk', 'en']) {
    final data = await rootBundle.load(
      'assets/audio/narration/cue_success_$language.mp3',
    );
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    expect(bytes, isNotEmpty, reason: '$language bundled narration bytes');
    final player = AudioPlayer();
    final completed = Completer<void>();
    // Install the listener before play: very short clips can finish before a
    // subscription made after the play future resolves would observe them.
    final subscription = player.onPlayerComplete.listen(
      (_) {
        if (!completed.isCompleted) completed.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!completed.isCompleted) completed.completeError(error, stack);
      },
    );
    try {
      // Both futures have handlers immediately, including when source setup
      // fails first. No orphan timeout or late stream error is left unobserved.
      await Future.wait<void>([
        Future<void>.sync(
          () => player.play(
            BytesSource(bytes, mimeType: 'audio/mpeg'),
            volume: 0,
          ),
        ),
        completed.future,
      ], eagerError: true).timeout(const Duration(seconds: 15));
      _verifiedAudioLocales.add(language);
    } on TimeoutException {
      fail(
        'Native $language bundled narration did not complete within 15 seconds.',
      );
    } finally {
      await subscription.cancel();
      await player.dispose().timeout(const Duration(seconds: 5));
    }
  }
}

/// The native harness may select one of three synthetic QA profiles before
/// launch. This is the only optional file read; ordinary application settings
/// and private provider configuration are never inspected by the test.
Future<int> _readQaAge() async {
  final profile = File(
    '${Directory.systemTemp.path}/tiny-trails-qa-profile.json',
  );
  final type = await FileSystemEntity.type(profile.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return 6;
  if (type != FileSystemEntityType.file || await profile.length() > 1024) {
    throw const FormatException(
      'The synthetic QA profile must be a small regular file.',
    );
  }
  final decoded = jsonDecode(await profile.readAsString());
  if (decoded is! Map<String, dynamic> ||
      decoded.length != 1 ||
      decoded['childAge'] is! int ||
      !const [4, 6, 10].contains(decoded['childAge'])) {
    throw const FormatException(
      'The synthetic QA profile requires childAge 4, 6, or 10.',
    );
  }
  return decoded['childAge'] as int;
}

// Real native preferences, isolated from both the child's game and v1 QA data.
class _QaStore implements ProgressStore {
  final _platform = PreferencesProgressStore();

  @override
  Future<String?> read(String key) => _platform.read('$_storagePrefix$key');

  @override
  Future<void> write(String key, String value) =>
      _platform.write('$_storagePrefix$key', value);
}

/// Bitmap codecs and platform preferences run on real workers. Yield a bounded
/// amount of wall time instead of trying to settle a loading spinner forever.
Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  int attempts = 400,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out: $reason');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _dismissInterfaceGuideIfPresent(WidgetTester tester) async {
  // The first-launch offer is scheduled after the shell's first frame. Use its
  // real Skip control; the native gameplay harness must not bypass UI state.
  await tester.pump();
  final skip = find.byKey(const Key('fini-tour-skip'));
  if (skip.evaluate().isEmpty) return;
  await _tap(tester, skip);
  await _until(
    tester,
    () => skip.evaluate().isEmpty,
    reason: 'dismiss Fini’s interface tour through its Skip button',
  );
}

Offset _onCanvas(WidgetTester tester, String key, Offset unit) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  if (key == 'rope-canvas') {
    return rect.topLeft + ropeMarkerCenter(unit, rect.width);
  }
  return rect.topLeft + Offset(unit.dx * rect.width, unit.dy * rect.height);
}

Future<void> _tapCanvas(WidgetTester tester, String key, Offset unit) async {
  await tester.tapAt(_onCanvas(tester, key, unit));
  await tester.pump();
}

void _expectNoAward(GameController controller, LevelDefinition level) {
  expect(
    controller.progress.containsKey(level.id),
    isFalse,
    reason: '${level.id}: an incorrect input must not complete the level',
  );
  expect(controller.completedCount, level.order);
  expect(controller.totalStars, level.order * 3);
  expect(controller.earnedStickers, hasLength(level.order));
}

Future<void> _ready(WidgetTester tester, LevelDefinition level) async {
  await _until(tester, () {
    final screens = tester.widgetList<PlayScreen>(find.byType(PlayScreen));
    return screens.isNotEmpty && screens.last.level.id == level.id;
  }, reason: 'navigation to ${level.id}');
  // The art is actually decoded and displayed before its coordinates are used.
  final context = tester.element(find.byType(PlayScreen).last);
  await tester.runAsync(
    () => precacheImage(AssetImage(level.illustrationAsset!), context),
  );
  await tester.pump(const Duration(milliseconds: 350));
  await _until(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    reason: 'the real ${level.id} bitmap and its interaction layer',
  );
  expect(tester.takeException(), isNull, reason: '${level.id} initial render');
}

Future<ColorSceneSpec> _colorSpec(LevelDefinition level) async =>
    ColorSceneSpec.fromJson(
      jsonDecode(await rootBundle.loadString(colorSpecAsset(level)))
          as Map<String, dynamic>,
    );

Future<void> _color(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final spec = await _colorSpec(level);
  final targets = spec.regionsFor(_ageBand);
  final first = targets.first;
  final correct = spec.acceptedPaletteIdFor(first, _ageBand);
  final wrong = spec.paletteFor(_ageBand).firstWhere((p) => p.id != correct);
  await _tap(tester, find.byKey(ValueKey('raster-palette-${wrong.id}')));
  await _tapCanvas(tester, 'color-canvas', first.anchor);
  _expectNoAward(controller, level);
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('color-finish')))
        .onPressed,
    isNull,
  );
  for (final region in targets) {
    await _tap(
      tester,
      find.byKey(
        ValueKey(
          'raster-palette-${spec.acceptedPaletteIdFor(region, _ageBand)}',
        ),
      ),
    );
    await _tapCanvas(tester, 'color-canvas', region.anchor);
  }
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('color-finish')))
        .onPressed,
    isNotNull,
  );
  await _tap(tester, find.byKey(const Key('color-finish')));
}

Future<void> _choice(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final challenge = choiceChallenge(level, _ageBand, childAge: _childAge);
  for (final stage in challenge.stages) {
    final wrong = stage.options.firstWhere((o) => o.id != stage.answer);
    await _tap(tester, find.byKey(ValueKey('choice-option-${wrong.id}')));
    _expectNoAward(controller, level);
    await _tap(tester, find.byKey(ValueKey('choice-option-${stage.answer}')));
  }
}

Future<void> _dots(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final layout = DotsLayout.forLevel(level, _ageBand);
  final rect = tester.getRect(find.byKey(const Key('dots-canvas')));
  final artSide = rect.width - dotsCanvasInset * 2;
  final labels = dotLabelPositions(layout.points, artSide);
  Offset labelPoint(int index) =>
      rect.topLeft +
      const Offset(dotsCanvasInset, dotsCanvasInset) +
      labels[index] * artSide;
  var wrongIndex = 1;
  for (var index = 2; index < labels.length; index++) {
    if ((labels[index] - labels.first).distance >
        (labels[wrongIndex] - labels.first).distance) {
      wrongIndex = index;
    }
  }
  await tester.tapAt(labelPoint(wrongIndex));
  await tester.pump();
  _expectNoAward(controller, level);
  for (var index = 0; index < labels.length; index++) {
    await tester.tapAt(labelPoint(index));
    await tester.pump();
  }
}

Future<void> _matching(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final layout = matchingLayoutFor(level, _childAge);
  final first = layout.cards.first;
  final wrong = layout.cards.firstWhere((card) => card.pairId != first.pairId);
  await _tap(tester, find.byKey(ValueKey('matching-card-${first.id}')));
  await _tap(tester, find.byKey(ValueKey('matching-card-${wrong.id}')));
  _expectNoAward(controller, level);
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('matching-finish')))
        .onPressed,
    isNull,
  );
  await tester.pump(
    Duration(milliseconds: _ageBand == AgeBand.advanced ? 1000 : 650),
  );
  for (final pairId in layout.pairIds) {
    for (final card in layout.cards.where((card) => card.pairId == pairId)) {
      await _tap(tester, find.byKey(ValueKey('matching-card-${card.id}')));
    }
  }
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('matching-finish')))
        .onPressed,
    isNotNull,
  );
  await _tap(tester, find.byKey(const Key('matching-finish')));
}

Future<void> _rope(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final layout = RopeLayout.forLevel(level, _ageBand);
  final first = layout.routes.first;
  final wrong = await tester.startGesture(
    _onCanvas(tester, 'rope-canvas', first.samples.first),
  );
  await wrong.moveTo(_onCanvas(tester, 'rope-canvas', first.samples.last));
  await wrong.up();
  await tester.pump();
  _expectNoAward(controller, level);
  for (final route in layout.routes) {
    if (_ageBand == AgeBand.preschool) {
      for (final checkpoint in const [40, 80, 120, 160]) {
        await _tap(tester, find.byKey(ValueKey('rope-checkpoint-$checkpoint')));
      }
      continue;
    }
    if (_ageBand == AgeBand.advanced) {
      var from = 0;
      for (var checkpoint = 0; checkpoint < 4; checkpoint++) {
        final until = (checkpoint + 1) * 40;
        final gesture = await tester.startGesture(
          _onCanvas(tester, 'rope-canvas', route.samples[from]),
        );
        for (var index = from + 1; index <= until; index++) {
          await gesture.moveTo(
            _onCanvas(tester, 'rope-canvas', route.samples[index]),
          );
        }
        await gesture.up();
        await tester.pump();
        if (checkpoint < 3) {
          final correct = route.symbols[checkpoint];
          final wrong = const [
            'star',
            'leaf',
            'flower',
          ].firstWhere((symbol) => symbol != correct);
          await _tap(tester, find.byKey(ValueKey('rope-symbol-$wrong')));
          _expectNoAward(controller, level);
          await _tap(tester, find.byKey(ValueKey('rope-symbol-$correct')));
        }
        from = until;
      }
      continue;
    }
    final gesture = await tester.startGesture(
      _onCanvas(tester, 'rope-canvas', route.samples.first),
    );
    for (final point in route.samples.skip(1)) {
      await gesture.moveTo(_onCanvas(tester, 'rope-canvas', point));
    }
    await gesture.up();
    await tester.pump();
  }
}

Future<void> _maze(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final network = MazeNetwork.forLevel(
    levelId: level.id,
    scene: level.scene,
    ageBand: _ageBand,
  );
  await _tapCanvas(tester, 'maze-canvas', const Offset(.99, .01));
  _expectNoAward(controller, level);
  // Query the same read-only map planner used by the visual hint. Every move
  // still enters through a real neighboring-junction touch; no session is solved
  // or injected. Advanced paths include both required flags before finishing.
  final route = MazeSession(network).hintRoute;
  expect(route, isNotEmpty);
  for (final node in route.skip(1)) {
    await _tap(tester, find.byKey(ValueKey('maze-node-$node')));
  }
}

Future<void> _drawing(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final canvas = find.byKey(const Key('drawing-canvas'));
  final layout = guidedDrawingLayout(level.scene, _ageBand);
  if (_ageBand == AgeBand.preschool) {
    final side = tester.getSize(canvas).width;
    final wrong = layout.actions.first.checkpointsForCanvas(side).last;
    await _tapCanvas(tester, 'drawing-canvas', wrong / 400);
  } else {
    final wrong = await tester.startGesture(
      _onCanvas(tester, 'drawing-canvas', const Offset(.04, .04)),
    );
    await wrong.moveTo(
      _onCanvas(tester, 'drawing-canvas', const Offset(.14, .04)),
    );
    await wrong.up();
    await tester.pump();
  }
  _expectNoAward(controller, level);
  expect(find.byKey(const Key('drawing-finish')), findsNothing);
  if (_ageBand != AgeBand.preschool) {
    await _tap(tester, find.byTooltip('Отменить'));
  }
  for (var stage = 0; stage < layout.actions.length; stage++) {
    final action = layout.actions[stage];
    expect(
      find.text(action.title.resolve('ru')),
      findsOneWidget,
      reason: '${level.id}: the preceding contour must really be complete',
    );
    if (_ageBand == AgeBand.preschool) {
      final side = tester.getSize(canvas).width;
      for (final point in action.checkpointsForCanvas(side)) {
        await _tapCanvas(tester, 'drawing-canvas', point / 400);
      }
      continue;
    }
    for (final metric in action.path.computeMetrics()) {
      // A small nearby contour can already meet this stage's coverage rule.
      // Follow the visible teaching stage rather than drawing into the next one.
      if (find.text(action.title.resolve('ru')).evaluate().isEmpty) break;
      final rect = tester.getRect(canvas);
      Offset screen(Offset point) => rect.topLeft + point * (rect.width / 400);
      final gesture = await tester.startGesture(
        screen(metric.getTangentForOffset(0)!.position),
      );
      for (var distance = 4.0; distance < metric.length; distance += 4) {
        await gesture.moveTo(
          screen(metric.getTangentForOffset(distance)!.position),
        );
      }
      await gesture.moveTo(
        screen(
          metric
              .getTangentForOffset(math.max(0.0, metric.length - .001))!
              .position,
        ),
      );
      await gesture.up();
      await tester.pump();
    }
  }
  await _until(
    tester,
    () => find.byKey(const Key('drawing-finish')).evaluate().isNotEmpty,
    reason: '${level.id}: all genuine contour stages completed',
  );
  // Add one real decorative mark to the child's completed drawing.
  await _tapCanvas(tester, 'drawing-canvas', const Offset(.86, .15));
  await _tap(tester, find.byKey(const Key('drawing-finish')));
}

Future<void> _hidden(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) async {
  final spec = HiddenPictureSpec.decode(
    await rootBundle.loadString(
      level.activityData['hiddenSpecAsset'] as String,
    ),
  );
  Offset unit(Offset point) =>
      Offset(point.dx / spec.imageSize.width, point.dy / spec.imageSize.height);
  await _tapCanvas(tester, 'hidden-canvas', unit(spec.targets[1].anchor));
  await _tapCanvas(tester, 'hidden-canvas', const Offset(.99, .01));
  _expectNoAward(controller, level);
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
        .onPressed,
    isNull,
  );
  for (final target in spec.targetsFor(_ageBand)) {
    await _tap(tester, find.byKey(ValueKey('hidden-target-${target.id}')));
    await _tapCanvas(tester, 'hidden-canvas', unit(target.anchor));
  }
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('hidden-finish')))
        .onPressed,
    isNotNull,
  );
  await _tap(tester, find.byKey(const Key('hidden-finish')));
}

Future<void> _solve(
  WidgetTester tester,
  GameController controller,
  LevelDefinition level,
) => switch (level.kind) {
  ActivityKind.numberColor => _color(tester, controller, level),
  ActivityKind.oddFragment ||
  ActivityKind.patternSequence ||
  ActivityKind.missingPuzzle => _choice(tester, controller, level),
  ActivityKind.connectDots => _dots(tester, controller, level),
  ActivityKind.matchPairs => _matching(tester, controller, level),
  ActivityKind.ropeTrace => _rope(tester, controller, level),
  ActivityKind.maze => _maze(tester, controller, level),
  ActivityKind.guidedDraw => _drawing(tester, controller, level),
  ActivityKind.hiddenAnimals => _hidden(tester, controller, level),
  ActivityKind.freeColor => throw StateError(
    'Creative replay is not a catalog level',
  ),
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _installSimulatorSemanticsFixture(binding);
  unawaited(
    binding.allTestsPassed.future.then((passed) async {
      await File('${Directory.systemTemp.path}/tiny-trails-qa-result.json')
          .writeAsString(
            jsonEncode({
              'passed': passed,
              'suite': 'twenty_curated_native',
              'platform': Platform.operatingSystem,
              'contentVersion': contentVersion,
              'childAge': _childAge,
              'ageBand': _ageBand.name,
              'storageNamespace': _storagePrefix,
              'verifiedLevelIds': _verifiedLevelIds,
              'verifiedAudioLocales': _verifiedAudioLocales,
              'nativeSemantics': _nativeSemantics,
            }),
            flush: true,
          );
    }),
  );

  testWidgets(
    'all 20 curated levels reject wrong input, award through UI and persist for the selected QA age',
    (tester) async {
      _verifiedLevelIds.clear();
      _verifiedAudioLocales.clear();
      _childAge = await _readQaAge();
      final store = _QaStore();
      final controller = await GameController.load(store: store);
      GameController? restarted;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        controller.dispose();
        restarted?.dispose();
      });
      await controller.resetProgress();
      await controller.setLanguage('ru');
      await controller.setChildAge(_childAge);
      await controller.setReducedMotion(true);
      await controller.setSound(false);
      await controller.setVoice(false);
      await controller.setHaptics(false);
      await controller.setMusicEnabled(false);
      await controller.setGuidanceEnabled(false);
      await controller.setBreakReminders(false);
      await controller.finishOnboarding();
      expect(levels, hasLength(20));
      expect(controller.ageBand, _ageBand);
      await tester.pumpWidget(TinyTrailsApp(controller: controller));
      await _until(
        tester,
        () => find.byKey(const Key('continue-adventure')).evaluate().isNotEmpty,
        reason: 'the real adventure home',
      );
      await _dismissInterfaceGuideIfPresent(tester);
      await _tap(tester, find.byKey(const Key('continue-adventure')));

      for (final level in levels) {
        await _ready(tester, level);
        _expectNoAward(controller, level);
        await _solve(tester, controller, level);
        await _until(
          tester,
          () => controller.progress.containsKey(level.id),
          reason: '${level.id}: native preferences completion commit',
        );
        await _until(
          tester,
          () => find.text('Дальше играть').evaluate().isNotEmpty,
          reason: '${level.id}: its reward screen',
        );
        expect(controller.completedCount, level.order + 1);
        expect(controller.totalStars, (level.order + 1) * 3);
        expect(controller.progress[level.id]!.attempts, 1);
        expect(controller.earnedStickers, hasLength(level.order + 1));
        expect(find.text('Новая наклейка в альбоме'), findsOneWidget);
        expect(controller.persistenceError, isNull);
        expect(
          tester.takeException(),
          isNull,
          reason: '${level.id} interaction',
        );
        _verifiedLevelIds.add(level.id);
        await _tap(tester, find.widgetWithText(FilledButton, 'Дальше играть'));
      }

      await _until(
        tester,
        () => find.byKey(const Key('continue-adventure')).evaluate().isNotEmpty,
        reason: 'return home after the twentieth reward',
      );
      await controller.flush();
      expect(controller.completedCount, 20);
      expect(controller.totalStars, 60);
      expect(controller.earnedStickers, hasLength(20));
      expect(controller.artworks, hasLength(4));
      expect(
        controller.artworks.map((art) => art.levelId),
        unorderedEquals(['v2_01', 'v2_09', 'v2_11', 'v2_19']),
      );
      expect(controller.drafts, isEmpty);

      restarted = await GameController.load(store: store);
      expect(restarted.childAge, _childAge);
      expect(restarted.completedCount, 20);
      expect(restarted.totalStars, 60);
      expect(restarted.earnedStickers, hasLength(20));
      expect(restarted.artworks, hasLength(4));
      expect(
        restarted.earnedAchievements.map((item) => item.id),
        contains('first_step'),
      );
      expect(restarted.persistenceError, isNull);
      await tester.pumpWidget(
        TinyTrailsApp(
          key: const ValueKey('restarted-native-app'),
          controller: restarted,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await _tap(tester, find.text('Мастерская').last);
      await _until(
        tester,
        () => find.byKey(const Key('studio-album-count')).evaluate().isNotEmpty,
        reason: 'the durable artwork album',
      );
      final albumCount = tester.widget<Text>(
        find.byKey(const Key('studio-album-count')),
      );
      expect(albumCount.data, '4 / ${GameController.maxArtworks}');
      await _probeBundledNarration();
      expect(_verifiedAudioLocales, ['ru', 'kk', 'en']);
      final speech = await const MethodChannel('tiny_trails/speech')
          .invokeMethod<bool>('isAvailable', {'language': 'en'})
          .timeout(const Duration(seconds: 7));
      expect(speech, isA<bool>());
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'suite': 'twenty_curated_native',
        'childAge': _childAge,
        'ageBand': _ageBand.name,
        'storageNamespace': _storagePrefix,
        'verifiedLevelIds': List<String>.of(_verifiedLevelIds),
        'verifiedAudioLocales': List<String>.of(_verifiedAudioLocales),
        'stars': restarted.totalStars,
        'stickers': restarted.earnedStickers.length,
        'artworks': restarted.artworks.length,
      };
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
