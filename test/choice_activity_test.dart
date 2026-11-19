import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/activity_config.dart';
import 'package:tiny_trails/features/play/choice_activity.dart';
import 'package:tiny_trails/features/play/content/choice_layouts.dart';
import 'package:tiny_trails/features/play/engines/choice_engine.dart';

LevelDefinition level(String scene) => LevelDefinition(
  id: 'choice-$scene',
  worldId: 'test',
  kind: switch (scene) {
    'zebra' || 'robot' => ActivityKind.oddFragment,
    'balloons' || 'growth' => ActivityKind.patternSequence,
    _ => ActivityKind.missingPuzzle,
  },
  scene: scene,
  variant: 0,
  difficulty: 1,
  title: const LocalizedText('Игра', 'Ойын', 'Play'),
  instruction: const LocalizedText('Сравни', 'Салыстыр', 'Compare'),
  order: 0,
);
const scenes = ['zebra', 'robot', 'balloons', 'growth', 'puppy', 'fox'];

void main() {
  test(
    'all six image layouts have a unique rule-derived answer at every age',
    () {
      for (final scene in scenes) {
        for (final age in AgeBand.values) {
          final challenge = choiceChallenge(level(scene), age);
          expect(challenge.stages, isNotEmpty);
          final engine = ChoiceEngine(challenge);
          for (final stage in challenge.stages) {
            final old = engine.toJson();
            for (final option in stage.options.where(
              (o) => o.id != stage.answer,
            )) {
              expect(
                engine.choose(option.id),
                isFalse,
                reason: '$scene $age ${stage.id}',
              );
              expect(engine.toJson(), old);
            }
            expect(engine.choose(stage.answer), isTrue);
          }
          expect(engine.complete, isTrue);
          expect(engine.choose(engine.stage.answer), isFalse);
          expect(
            ChoiceEngine(challenge, initialData: engine.toJson()).complete,
            isTrue,
          );
        }
      }
    },
  );

  test(
    'age changes actual rules and required progress, including both properties',
    () {
      final easy = choiceChallenge(level('balloons'), AgeBand.preschool);
      final medium = choiceChallenge(level('balloons'), AgeBand.primary);
      final hard = choiceChallenge(level('balloons'), AgeBand.advanced);
      expect(easy.stages.first.sequence.length, 4);
      expect(
        medium.stages.first.sequence[1]!.samePicture(
          medium.stages.first.sequence[2]!,
        ),
        isTrue,
      );
      expect(hard.stages.first.answerOption.piece.turns, 2);
      expect(
        hard.stages.first.sequence[0]!.samePicture(
          hard.stages.first.sequence[2]!,
        ),
        isFalse,
      );
      expect(choiceChallenge(level('fox'), AgeBand.preschool).holes.length, 1);
      expect(choiceChallenge(level('fox'), AgeBand.primary).holes.length, 2);
      expect(choiceChallenge(level('fox'), AgeBand.advanced).holes.length, 4);
      expect(
        choiceChallenge(level('growth'), AgeBand.advanced).stages.length,
        4,
      );
      expect(
        choiceChallenge(
          level('robot'),
          AgeBand.advanced,
        ).stages.first.referenceTurns,
        1,
      );
    },
  );

  test(
    'restore rejects malformed, cross-age, cross-image and forged answers',
    () {
      final challenge = choiceChallenge(level('fox'), AgeBand.advanced);
      final engine = ChoiceEngine(challenge)
        ..choose(challenge.stages.first.answer);
      final valid = engine.toJson();
      expect(ChoiceEngine(challenge, initialData: valid).stageIndex, 1);
      for (final changed in <Map<String, dynamic>>[
        {'version': 2},
        {'ageBand': 'preschool'},
        {'levelId': 'other'},
        {'asset': 'other.png'},
        {'scene': 'other'},
        {'childAge': 10},
        {'layoutRevision': 999},
        {'stage': '1'},
        {'answers': 'wrong'},
        {
          'answers': ['forged'],
        },
        {
          'answers': [challenge.stages.first.answer, 42],
          'stage': 2,
        },
        {'answers': List.filled(10000, 'x'), 'stage': 10000},
      ]) {
        expect(
          ChoiceEngine(
            challenge,
            initialData: {...valid, ...changed},
          ).stageIndex,
          0,
        );
      }
    },
  );

  test(
    'missing crops are in bounds, distinct, nonoverlapping, and large enough',
    () {
      for (final scene in ['puppy', 'fox']) {
        final holes = choiceChallenge(level(scene), AgeBand.advanced).holes;
        for (var i = 0; i < holes.length; i++) {
          final crop = holes[i].crop;
          expect(
            crop.left >= 0 &&
                crop.top >= 0 &&
                crop.right <= 1 &&
                crop.bottom <= 1,
            isTrue,
          );
          expect(crop.shortestSide * 220, greaterThanOrEqualTo(48));
          for (var j = 0; j < i; j++) {
            expect(crop.overlaps(holes[j].crop), isFalse);
          }
        }
      }
    },
  );

  for (final scene in scenes) {
    testWidgets(
      '$scene wrong taps do not advance, every stage completes once',
      (tester) async {
        tester.view.physicalSize = const Size(390, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final challenge = choiceChallenge(level(scene), AgeBand.advanced);
        var completions = 0;
        final saves = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          app(scene, 10, saves.add, (_) => completions++),
        );
        await tester.pumpAndSettle();
        for (final stage in challenge.stages) {
          final wrong = stage.options.firstWhere((o) => o.id != stage.answer);
          final wrongFinder = find.byKey(ValueKey('choice-option-${wrong.id}'));
          await tester.ensureVisible(wrongFinder);
          await tester.tap(wrongFinder);
          await tester.pumpAndSettle();
          expect(completions, 0);
          expect(saves.length, challenge.stages.indexOf(stage));
          final rightFinder = find.byKey(
            ValueKey('choice-option-${stage.answer}'),
          );
          await tester.ensureVisible(rightFinder);
          await tester.tap(rightFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(saves.length, challenge.stages.length);
        expect(completions, 1);
        await tester.pumpWidget(
          app(scene, 10, saves.add, (_) => completions++, language: 'kk'),
        );
        await tester.pumpAndSettle();
        expect(completions, 1);
      },
    );
  }

  testWidgets(
    'dragging a wrong piece then the correct piece uses the real hole target',
    (tester) async {
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var complete = 0;
      final saves = <Map<String, dynamic>>[];
      await tester.pumpWidget(app('puppy', 4, saves.add, (_) => complete++));
      await tester.pumpAndSettle();
      final stage = choiceChallenge(
        level('puppy'),
        AgeBand.preschool,
      ).stages.first;
      final hole = find.byKey(const ValueKey('choice-hole-0'));
      final wrong = stage.options.firstWhere((o) => o.id != stage.answer);
      await tester.dragFrom(
        tester.getCenter(find.byKey(ValueKey('choice-option-${wrong.id}'))),
        tester.getCenter(hole) -
            tester.getCenter(find.byKey(ValueKey('choice-option-${wrong.id}'))),
      );
      await tester.pumpAndSettle();
      expect(complete, 0);
      expect(saves, isEmpty);
      final correct = find.byKey(ValueKey('choice-option-${stage.answer}'));
      await tester.dragFrom(
        tester.getCenter(correct),
        tester.getCenter(hole) - tester.getCenter(correct),
      );
      await tester.pumpAndSettle();
      expect(complete, 1);
      expect(saves.single['stage'], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'valid restore continues, hints never award, and age switch resets',
    (tester) async {
      final challenge = choiceChallenge(
        level('fox'),
        AgeBand.advanced,
        childAge: 10,
      );
      final engine = ChoiceEngine(challenge)
        ..choose(challenge.stages.first.answer);
      var complete = 0;
      final saves = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          'fox',
          10,
          saves.add,
          (_) => complete++,
          initial: engine.toJson(),
          hint: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('choice-hole-0')), findsNothing);
      expect(find.byKey(const ValueKey('choice-hole-1')), findsOneWidget);
      expect(complete, 0);
      expect(saves, isEmpty);
      await tester.pumpWidget(
        app('fox', 4, saves.add, (_) => complete++, initial: engine.toJson()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('choice-hole-0')), findsOneWidget);
      expect(complete, 0);
    },
  );

  testWidgets('small phone and landscape remain usable with 48dp choices', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 480),
      const Size(740, 300),
      const Size(740, 200),
    ]) {
      tester.view.physicalSize = size;
      for (final scene in scenes) {
        await tester.pumpWidget(app(scene, 10, (_) {}, (_) {}));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$scene $size');
        final board = tester.getSize(find.byKey(const Key('choice-board')));
        expect(board.shortestSide, greaterThanOrEqualTo(220));
        final stage = choiceChallenge(
          level(scene),
          AgeBand.advanced,
        ).stages.first;
        for (final option in stage.options) {
          final target = find.byKey(ValueKey('choice-option-${option.id}'));
          expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
        }
      }
    }
  });

  testWidgets('image puzzle screenshots for visual inspection', (tester) async {
    final output = const String.fromEnvironment('CHOICE_SCREENSHOTS');
    if (output.isEmpty) return;
    await tester.runAsync(() async {
      await (FontLoader(
        'Nunito',
      )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scene in scenes) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: app(scene, 10, (_) {}, (_) {})),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$scene.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

Widget app(
  String scene,
  int age,
  ValueChanged<Map<String, dynamic>> changed,
  ValueChanged<Map<String, dynamic>> completed, {
  Map<String, dynamic>? initial,
  bool hint = false,
  String language = 'en',
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildTheme(),
  home: Scaffold(
    body: ChoiceActivity(
      config: ActivityConfig(
        level: level(scene),
        language: language,
        childAge: age,
        initialData: initial,
        showHint: hint,
        reducedMotion: true,
        onChanged: changed,
        onCompleted: completed,
        onFeedback: () {},
      ),
    ),
  ),
);
