import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/content/matching_layouts.dart';
import 'package:tiny_trails/features/play/engines/matching_engine.dart';
import 'package:tiny_trails/features/play/matching_activity.dart';

const _captureMatching = bool.fromEnvironment('CAPTURE_MATCHING');
const _captureKey = ValueKey('matching-test-capture');

const _shoes = LevelDefinition(
  id: 'v2_04',
  worldId: 'ocean',
  kind: ActivityKind.matchPairs,
  scene: 'shoes',
  variant: 0,
  difficulty: 1,
  order: 3,
  title: LocalizedText('Пары обуви', 'Аяқкиім жұптары', 'Shoe pairs'),
  instruction: LocalizedText('Найди пару', 'Жұбын тап', 'Find a pair'),
  illustrationAsset: 'assets/images/levels/04-shoes.png',
);
const _picnic = LevelDefinition(
  id: 'v2_14',
  worldId: 'safari',
  kind: ActivityKind.matchPairs,
  scene: 'picnic',
  variant: 1,
  difficulty: 2,
  order: 13,
  title: LocalizedText('Пикник', 'Серуен', 'Picnic'),
  instruction: LocalizedText('Найди пару', 'Жұбын тап', 'Find a pair'),
  illustrationAsset: 'assets/images/levels/14-picnic.png',
);

List<MatchingCard> _pair(MatchingLayout layout, String pairId) =>
    layout.cards.where((card) => card.pairId == pairId).toList();

Future<void> _pumpGame(
  WidgetTester tester, {
  LevelDefinition level = _shoes,
  int age = 6,
  String language = 'ru',
  Map<String, dynamic>? draft,
  bool hint = false,
  bool reducedMotion = true,
  ValueChanged<Map<String, dynamic>>? changed,
  ValueChanged<Map<String, dynamic>>? completed,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Scaffold(
          body: MatchingActivity(
            config: ActivityConfig(
              level: level,
              language: language,
              childAge: age,
              initialData: draft,
              showHint: hint,
              reducedMotion: reducedMotion,
              onChanged: changed ?? (_) {},
              onCompleted: completed ?? (_) {},
              onFeedback: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureMatching) return;
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MatchingActivity));
    final activity = tester.widget<MatchingActivity>(
      find.byType(MatchingActivity),
    );
    await precacheImage(
      AssetImage(
        matchingLayoutFor(
          activity.config.level,
          activity.config.childAge,
        ).assetPath,
      ),
      context,
    );
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('output/qa/matching-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _tapCard(WidgetTester tester, MatchingCard card) async {
  await tester.tap(find.byKey(ValueKey('matching-card-${card.id}')));
  await tester.pump();
}

FilledButton _finish(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('matching-finish')));

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

  group('curated matching layouts', () {
    for (final level in [_shoes, _picnic]) {
      test(
        '${level.scene}: every age has bounded, distinct complete pairs',
        () {
          for (var age = 3; age <= 11; age++) {
            final layout = matchingLayoutFor(level, age);
            final expected = age == 3
                ? 2
                : age <= 5
                ? 3
                : age <= 8
                ? 4
                : 6;
            expect(layout.pairIds, hasLength(expected));
            expect(layout.cards, hasLength(expected * 2));
            expect(
              layout.cards.map((card) => card.id).toSet(),
              hasLength(expected * 2),
            );
            expect(layout.memoryMode, age >= 9);
            for (final pairId in layout.pairIds) {
              final pair = _pair(layout, pairId);
              expect(pair, hasLength(2));
              expect(
                pair.first.crop.left != pair.last.crop.left ||
                    pair.first.crop.top != pair.last.crop.top,
                isTrue,
                reason: 'Each card uses its own counterpart in actual art',
              );
            }
            for (final card in layout.cards) {
              expect(card.crop.width, greaterThan(0));
              expect(card.crop.height, greaterThan(0));
              expect(card.crop.left, greaterThanOrEqualTo(0));
              expect(card.crop.top, greaterThanOrEqualTo(0));
              expect(
                card.crop.left + card.crop.width,
                lessThanOrEqualTo(MatchingCrop.sourceSize),
              );
              expect(
                card.crop.top + card.crop.height,
                lessThanOrEqualTo(MatchingCrop.sourceSize),
              );
              for (final language in ['ru', 'kk', 'en']) {
                expect(card.name.resolve(language), isNotEmpty);
              }
            }
          }
        },
      );
    }
  });

  group('pair engine', () {
    test(
      'same card, unknown ID and solved pair replay cannot make progress',
      () {
        final layout = matchingLayoutFor(_shoes, 6);
        final engine = MatchingEngine(layout: layout);
        final pair = _pair(layout, layout.pairIds.first);
        expect(engine.tap('unknown'), MatchingTapResult.ignored);
        expect(engine.tap(pair.first.id), MatchingTapResult.selected);
        expect(engine.tap(pair.first.id), MatchingTapResult.ignored);
        expect(engine.solvedPairIds, isEmpty);
        expect(engine.tap(pair.last.id), MatchingTapResult.matched);
        for (var i = 0; i < 20; i++) {
          expect(engine.tap(pair[i % 2].id), MatchingTapResult.ignored);
        }
        expect(engine.solvedPairIds, {pair.first.pairId});
        expect(engine.complete, isFalse);
      },
    );

    test('wrong pair resets selection and cannot overlap another attempt', () {
      final layout = matchingLayoutFor(_picnic, 9);
      final engine = MatchingEngine(layout: layout);
      final first = layout.cards.first;
      final wrong = layout.cards.firstWhere(
        (card) => card.pairId != first.pairId,
      );
      expect(engine.tap(first.id), MatchingTapResult.selected);
      expect(engine.tap(wrong.id), MatchingTapResult.mismatch);
      expect(engine.selectedCardId, isNull);
      expect(engine.mismatchCardIds, unorderedEquals([first.id, wrong.id]));
      expect(engine.isRevealed(first), isTrue);
      expect(engine.isRevealed(wrong), isTrue);
      expect(
        engine.tap(_pair(layout, first.pairId).last.id),
        MatchingTapResult.ignored,
      );
      engine.clearMismatch();
      expect(engine.isRevealed(first), isFalse);
      expect(engine.isRevealed(wrong), isFalse);
      expect(engine.solvedPairIds, isEmpty);
      expect(engine.tap(first.id), MatchingTapResult.selected);
    });

    test(
      'only all unique valid pairs complete; found pairs remain revealed',
      () {
        final layout = matchingLayoutFor(_shoes, 11);
        final engine = MatchingEngine(layout: layout);
        var solved = 0;
        for (final pairId in layout.pairIds) {
          final pair = _pair(layout, pairId);
          expect(engine.tap(pair.first.id), MatchingTapResult.selected);
          expect(
            engine.tap(pair.last.id),
            ++solved == layout.pairIds.length
                ? MatchingTapResult.completed
                : MatchingTapResult.matched,
          );
          expect(engine.isRevealed(pair.first), isTrue);
          expect(engine.isRevealed(pair.last), isTrue);
          expect(engine.complete, solved == layout.pairIds.length);
        }
        expect(engine.solvedPairIds, layout.pairIds);
        expect(engine.tap(layout.cards.first.id), MatchingTapResult.ignored);
      },
    );

    test('hints never select or award progress and exclude solved pairs', () {
      final layout = matchingLayoutFor(_picnic, 6);
      final engine = MatchingEngine(layout: layout);
      final before = engine.toJson();
      final hint = engine.hintCardIds();
      expect(hint, hasLength(2));
      expect(
        layout.cardById(hint.first)!.pairId,
        layout.cardById(hint.last)!.pairId,
      );
      expect(engine.toJson(), before);
      engine.tap(hint.first);
      engine.tap(hint.last);
      expect(engine.hintCardIds().toSet().intersection(hint.toSet()), isEmpty);
    });

    test(
      'round trip preserves valid solved pairs and a single memory reveal',
      () {
        final layout = matchingLayoutFor(_shoes, 9);
        final engine = MatchingEngine(layout: layout);
        final pair = _pair(layout, layout.pairIds.first);
        engine.tap(pair.first.id);
        engine.tap(pair.last.id);
        final next = layout.cards.firstWhere((card) => !engine.isSolved(card));
        engine.tap(next.id);
        final restored = MatchingEngine(
          layout: layout,
          initialData: engine.toJson(),
        );
        expect(restored.solvedPairIds, {pair.first.pairId});
        expect(restored.selectedCardId, next.id);
        expect(restored.isRevealed(next), isTrue);
        expect(
          restored.tap(
            _pair(
              layout,
              next.pairId,
            ).firstWhere((card) => card.id != next.id).id,
          ),
          MatchingTapResult.matched,
        );
      },
    );

    test('wrong identity or age/revision cannot restore another challenge', () {
      final layout = matchingLayoutFor(_shoes, 6);
      final pair = _pair(layout, layout.pairIds.first);
      final engine = MatchingEngine(layout: layout)
        ..tap(pair.first.id)
        ..tap(pair.last.id);
      final valid = engine.toJson();
      for (final field in [
        'version',
        'kind',
        'levelId',
        'ageBand',
        'layoutRevision',
      ]) {
        final tampered = {...valid, field: 'wrong'};
        final restored = MatchingEngine(layout: layout, initialData: tampered);
        expect(restored.solvedPairIds, isEmpty, reason: field);
        expect(restored.selectedCardId, isNull);
      }
      for (final age in [3, 5, 9, 11]) {
        final restored = MatchingEngine(
          layout: matchingLayoutFor(_shoes, age),
          initialData: valid,
        );
        expect(restored.solvedPairIds, isEmpty, reason: 'new age: $age');
      }
      final restoredPicnic = MatchingEngine(
        layout: matchingLayoutFor(_picnic, 6),
        initialData: valid,
      );
      expect(restoredPicnic.solvedPairIds, isEmpty);
    });

    test(
      'preschool pair-count change resets even within the same age band',
      () {
        final small = matchingLayoutFor(_shoes, 3);
        final pair = _pair(small, small.pairIds.first);
        final engine = MatchingEngine(layout: small)
          ..tap(pair.first.id)
          ..tap(pair.last.id);
        final larger = matchingLayoutFor(_shoes, 4);
        expect(larger.ageBand, small.ageBand);
        expect(larger.revision, isNot(small.revision));
        final restored = MatchingEngine(
          layout: larger,
          initialData: engine.toJson(),
        );
        expect(restored.solvedPairIds, isEmpty);
        expect(restored.complete, isFalse);
      },
    );

    test(
      'restore deduplicates and filters foreign pairs, invalid selections',
      () {
        final layout = matchingLayoutFor(_shoes, 6);
        final base = MatchingEngine(layout: layout).toJson();
        final pairId = layout.pairIds.first;
        final restored = MatchingEngine(
          layout: layout,
          initialData: {
            ...base,
            'solvedPairIds': [pairId, pairId, 'foreign', 1, null],
            'selectedCardId': _pair(layout, pairId).first.id,
          },
        );
        expect(restored.solvedPairIds, {pairId});
        expect(restored.selectedCardId, isNull);
        expect(restored.complete, isFalse);
        final invalid = MatchingEngine(
          layout: layout,
          initialData: {
            ...base,
            'solvedPairIds': 'bad',
            'selectedCardId': 'foreign',
          },
        );
        expect(invalid.solvedPairIds, isEmpty);
        expect(invalid.selectedCardId, isNull);
      },
    );

    test(
      'corrupt or oversized memory reveals close instead of exposing cards',
      () {
        final layout = matchingLayoutFor(_picnic, 9);
        final base = MatchingEngine(layout: layout).toJson();
        final card = layout.cards.first;
        for (final reveals in <Object?>[
          null,
          'all',
          [],
          [card.id, card.id],
          ['foreign'],
          layout.cards.map((card) => card.id).toList(),
        ]) {
          final restored = MatchingEngine(
            layout: layout,
            initialData: {
              ...base,
              'selectedCardId': card.id,
              'revealedCardIds': reveals,
            },
          );
          expect(restored.selectedCardId, isNull, reason: '$reveals');
          expect(layout.cards.where(restored.isRevealed), isEmpty);
        }
      },
    );

    test('transient mismatches close on restore and never count as found', () {
      final layout = matchingLayoutFor(_picnic, 9);
      final engine = MatchingEngine(layout: layout);
      final first = layout.cards.first;
      final wrong = layout.cards.firstWhere(
        (card) => card.pairId != first.pairId,
      );
      engine.tap(first.id);
      engine.tap(wrong.id);
      final restored = MatchingEngine(
        layout: layout,
        initialData: engine.toJson(),
      );
      expect(restored.mismatchCardIds, isEmpty);
      expect(restored.selectedCardId, isNull);
      expect(restored.solvedPairIds, isEmpty);
      expect(layout.cards.where(restored.isRevealed), isEmpty);
    });
  });

  testWidgets(
    'two taps match; duplicate taps and a wrong pair do not complete',
    (tester) async {
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      final layout = matchingLayoutFor(_shoes, 3);
      await _pumpGame(
        tester,
        age: 3,
        changed: snapshots.add,
        completed: completions.add,
      );
      expect(_finish(tester).onPressed, isNull);
      final first = layout.cards.first;
      final wrong = layout.cards.firstWhere(
        (card) => card.pairId != first.pairId,
      );
      await _tapCard(tester, first);
      await _tapCard(tester, first);
      expect(snapshots.last['solvedPairIds'], isEmpty);
      await _tapCard(tester, wrong);
      expect(snapshots.last['solvedPairIds'], isEmpty);
      await tester.pump(const Duration(milliseconds: 800));
      for (final pairId in layout.pairIds) {
        final pair = _pair(layout, pairId);
        await _tapCard(tester, pair.first);
        await _tapCard(tester, pair.last);
        await _tapCard(tester, pair.first);
      }
      expect(snapshots.last['solvedPairIds'], unorderedEquals(layout.pairIds));
      expect(completions, isEmpty);
      expect(_finish(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('matching-finish')));
      await tester.pump();
      expect(completions, hasLength(1));
      expect(_finish(tester).onPressed, isNull);
      expect(
        completions.single['solvedPairIds'],
        unorderedEquals(layout.pairIds),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hint cannot award a pair or enable finishing', (tester) async {
    final snapshots = <Map<String, dynamic>>[];
    var completed = 0;
    await _pumpGame(
      tester,
      level: _picnic,
      age: 9,
      hint: true,
      changed: snapshots.add,
      completed: (_) => completed++,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(completed, 0);
    expect(
      snapshots.every((data) => (data['solvedPairIds'] as List).isEmpty),
      isTrue,
    );
    expect(_finish(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory exposes only tapped cards and closes a wrong pair', (
    tester,
  ) async {
    final snapshots = <Map<String, dynamic>>[];
    final layout = matchingLayoutFor(_picnic, 9);
    await _pumpGame(tester, level: _picnic, age: 9, changed: snapshots.add);
    for (final card in layout.cards) {
      expect(find.byKey(ValueKey('back-${card.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('face-${card.id}')), findsNothing);
    }
    final first = layout.cards.first;
    final wrong = layout.cards.firstWhere(
      (card) => card.pairId != first.pairId,
    );
    await _tapCard(tester, first);
    expect(find.byKey(ValueKey('face-${first.id}')), findsOneWidget);
    await _tapCard(tester, wrong);
    expect(find.byKey(ValueKey('face-${wrong.id}')), findsOneWidget);
    expect(snapshots.last['solvedPairIds'], isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(ValueKey('back-${first.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('back-${wrong.id}')), findsOneWidget);
    expect(snapshots.last['selectedCardId'], isNull);
    expect(snapshots.last['revealedCardIds'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['ru', 'kk', 'en']) {
    testWidgets('$language semantics do not disclose a face-down subject', (
      tester,
    ) async {
      final layout = matchingLayoutFor(_shoes, 9);
      await _pumpGame(tester, age: 9, language: language);
      final first = layout.cards.first;
      final name = first.name.resolve(language);
      final subjects = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith(name) ?? false),
      );
      expect(subjects, findsNothing);
      await _tapCard(tester, first);
      expect(subjects, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'draft and compatible age retain progress; a new age band resets it',
    (tester) async {
      final young = matchingLayoutFor(_shoes, 5);
      final pair = _pair(young, young.pairIds.first);
      final engine = MatchingEngine(layout: young)
        ..tap(pair.first.id)
        ..tap(pair.last.id);
      final snapshots = <Map<String, dynamic>>[];
      final completions = <Map<String, dynamic>>[];
      await _pumpGame(
        tester,
        age: 5,
        draft: engine.toJson(),
        changed: snapshots.add,
        completed: completions.add,
      );
      final next = young.cards.firstWhere((card) => !engine.isSolved(card));
      await _tapCard(tester, next);
      expect(snapshots.last['solvedPairIds'], [pair.first.pairId]);
      await _pumpGame(
        tester,
        age: 4,
        changed: snapshots.add,
        completed: completions.add,
      );
      await _tapCard(
        tester,
        _pair(young, next.pairId).firstWhere((card) => card.id != next.id),
      );
      expect(
        snapshots.last['solvedPairIds'],
        unorderedEquals([pair.first.pairId, next.pairId]),
      );
      final remaining = young.pairIds.firstWhere(
        (id) => id != pair.first.pairId && id != next.pairId,
      );
      for (final card in _pair(young, remaining)) {
        await _tapCard(tester, card);
      }
      await tester.tap(find.byKey(const Key('matching-finish')));
      await tester.pump();
      expect(completions, hasLength(1));
      await _pumpGame(
        tester,
        age: 5,
        changed: snapshots.add,
        completed: completions.add,
      );
      expect(
        _finish(tester).onPressed,
        isNull,
        reason: 'A compatible age update cannot replay completion',
      );
      expect(completions, hasLength(1));
      await _pumpGame(
        tester,
        age: 9,
        draft: snapshots.last,
        changed: snapshots.add,
      );
      final older = matchingLayoutFor(_shoes, 9);
      for (final card in older.cards) {
        expect(
          find.byKey(ValueKey('matching-card-${card.id}')),
          findsOneWidget,
        );
      }
      await _tapCard(tester, older.cards.first);
      expect(snapshots.last['ageBand'], AgeBand.advanced.name);
      expect(snapshots.last['solvedPairIds'], isEmpty);
      expect(_finish(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 720),
    const Size(720, 280),
    const Size(1024, 768),
  ]) {
    testWidgets('memory cards fit $size with a 220dp board and 48dp targets', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpGame(tester, level: _picnic, age: 11);
      final canvas = tester.getRect(find.byKey(const Key('matching-canvas')));
      expect(canvas.height, greaterThanOrEqualTo(220));
      expect(canvas.width, greaterThanOrEqualTo(220));
      final layout = matchingLayoutFor(_picnic, 11);
      for (final card in layout.cards) {
        final finder = find.byKey(ValueKey('matching-card-${card.id}'));
        final rect = tester.getRect(finder);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(canvas.contains(rect.center), isTrue);
        expect(finder.hitTestable(), findsOneWidget);
      }
      await _tapCard(tester, layout.cards.first);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('optional capture of original-art matching boards', (
    tester,
  ) async {
    if (!_captureMatching) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final fixture in [
      (
        level: _shoes,
        age: 4,
        hint: false,
        solved: false,
        size: const Size(390, 720),
        orientation: 'portrait',
      ),
      (
        level: _shoes,
        age: 9,
        hint: true,
        solved: false,
        size: const Size(390, 720),
        orientation: 'portrait-hint',
      ),
      (
        level: _picnic,
        age: 6,
        hint: false,
        solved: false,
        size: const Size(390, 720),
        orientation: 'portrait',
      ),
      (
        level: _picnic,
        age: 9,
        hint: true,
        solved: false,
        size: const Size(390, 720),
        orientation: 'portrait-hint',
      ),
      (
        level: _picnic,
        age: 9,
        hint: true,
        solved: false,
        size: const Size(720, 280),
        orientation: 'landscape-hint',
      ),
      (
        level: _shoes,
        age: 11,
        hint: false,
        solved: true,
        size: const Size(390, 720),
        orientation: 'portrait-solved',
      ),
      (
        level: _picnic,
        age: 11,
        hint: false,
        solved: true,
        size: const Size(720, 280),
        orientation: 'landscape-solved',
      ),
    ]) {
      // Each fixture gets a fresh activity so initialData is restored even
      // when the preceding capture used the same scene and age.
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = fixture.size;
      Map<String, dynamic>? draft;
      if (fixture.solved) {
        final layout = matchingLayoutFor(fixture.level, fixture.age);
        final engine = MatchingEngine(layout: layout);
        for (final pairId in layout.pairIds) {
          final pair = _pair(layout, pairId);
          engine.tap(pair.first.id);
          engine.tap(pair.last.id);
        }
        draft = engine.toJson();
      }
      await _pumpGame(
        tester,
        level: fixture.level,
        age: fixture.age,
        hint: fixture.hint,
        draft: draft,
      );
      await _capture(
        tester,
        '${fixture.level.scene}-${fixture.age}-${fixture.orientation}',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
