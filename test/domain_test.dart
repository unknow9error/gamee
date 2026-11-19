import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/domain/artwork_limits.dart';

void main() {
  group('content contract', () {
    test('exactly20curatedlevels cover10mechanics and5chapters', () {
      expect(worlds.length, 5);
      expect(levels.length, 20);
      expect(levels.map((item) => item.id).toList(), [
        for (var i = 1; i <= 20; i++) 'v2_${i.toString().padLeft(2, '0')}',
      ]);
      expect(stickers.length, 20);
      expect(
        stickers.map((item) => item.levelId).toSet(),
        levelIndex.keys.toSet(),
      );
      expect(
        levels.any((item) => item.kind == ActivityKind.freeColor),
        isFalse,
      );
      for (final world in worlds) {
        expect(levelsForWorld(world.id), hasLength(4));
      }
      for (final kind in activeActivityKinds) {
        expect(levels.where((item) => item.kind == kind), hasLength(2));
      }
      for (final level in levels) {
        expect(level.illustrationAsset, startsWith('assets/images/levels/'));
        expect(level.voiceKey, level.id);
      }
      for (final goal in missions) {
        expect(
          goal.target,
          lessThanOrEqualTo(
            levels.where((item) => item.kind == goal.kind).length,
          ),
        );
      }
      for (final badge in achievements) {
        expect(
          badge.target,
          lessThanOrEqualTo(badge.kind == null ? levels.length : 2),
        );
      }
      expect(
        levelIndex['v2_01']!.activityData['colorSpecAsset'],
        'assets/content/color-toybox.json',
      );
      expect(levelIndex['v2_11']!.activityData['ruleMode'], 'shapes');
      expect(
        levelIndex['v2_10']!.activityData['hiddenSpecAsset'],
        'assets/content/hidden-reef.json',
      );
    });

    test('all user-facing catalog text is present in all three languages', () {
      final copy = <LocalizedText>[
        for (final world in worlds) ...[world.title, world.subtitle],
        for (final level in levels) ...[level.title, level.instruction],
        for (final achievement in achievements) ...[
          achievement.title,
          achievement.description,
        ],
        for (final mission in missions) mission.title,
      ];
      for (final text in copy) {
        for (final language in ['ru', 'kk', 'en']) {
          expect(text.resolve(language).trim(), isNotEmpty);
        }
      }
    });
  });

  test('all20activities are reachable for every supported age', () async {
    final controller = GameController.inMemory();
    for (var age = 3; age <= 11; age++) {
      await controller.setChildAge(age);
      expect(levels.every(controller.isUnlocked), isTrue);
    }
    expect(AgeBand.fromAge(3), AgeBand.preschool);
    expect(AgeBand.fromAge(5), AgeBand.preschool);
    expect(AgeBand.fromAge(6), AgeBand.primary);
    expect(AgeBand.fromAge(8), AgeBand.primary);
    expect(AgeBand.fromAge(9), AgeBand.advanced);
    expect(AgeBand.fromAge(11), AgeBand.advanced);
    expect(() => controller.setChildAge(2), throwsRangeError);
    expect(() => controller.setChildAge(12), throwsRangeError);
    expect(controller.childAge, 11);
  });

  test('replays preserve best stars and distinct artwork versions without duplicate awards', () async {
    final controller = GameController.inMemory();
    final level = levels.first;
    final first = await controller.completeLevel(
      level,
      artwork: {
        'fills': {'body': 7},
      },
    );
    expect(first.firstCompletion, isTrue);
    expect(
      first.newAchievements.map((item) => item.id),
      contains('first_step'),
    );
    final replay = await controller.completeLevel(
      level,
      stars: 1,
      artwork: {
        'fills': {'body': 9},
      },
    );
    expect(replay.firstCompletion, isFalse);
    expect(replay.newAchievements, isEmpty);
    expect(controller.totalStars, 3);
    expect(controller.completedCount, 1);
    expect(controller.progress[level.id]!.attempts, 2);
    expect(controller.artworks.length, 2);
    expect(controller.artworks.map((art) => art.id).toSet(), hasLength(2));
    expect(controller.artworks.first.data['fills']['body'], 9);
  });

  test('draft input and returned copies cannot mutate owned state', () async {
    final controller = GameController.inMemory();
    final input = <String, dynamic>{
      'points': [
        [0.2, 0.4],
      ],
    };
    await controller.saveDraft(levels.first.id, input);
    (input['points'] as List).clear();
    final draft = controller.draftFor(levels.first.id)!;
    expect(draft['points'], hasLength(1));
    (draft['points'] as List).clear();
    expect(controller.draftFor(levels.first.id)!['points'], hasLength(1));
  });

  test('invalid drawing and unknown level leave progress unchanged', () async {
    final controller = GameController.inMemory();
    expect(
      () => controller.saveDraft(levels.first.id, {'x': double.nan}),
      throwsFormatException,
    );
    expect(() => controller.saveDraft('not-a-level', {}), throwsArgumentError);
    await expectLater(
      controller.completeLevel(levels.first, artwork: {'x': Object()}),
      throwsFormatException,
    );
    expect(controller.completedCount, 0);
    expect(controller.artworks, isEmpty);
  });

  test('ordinary oversampled brush strokes compact and survive save and completion', () async {
    final controller = GameController.inMemory();
    final payload = <String, dynamic>{
      'version': 1,
      'strokes': List.generate(
        20,
        (_) => {
          'color': 0xFFEA7563,
          'width': 12.0,
          'points': List.generate(1100, (i) => [i / 1100, .5]),
        },
      ),
    };
    await controller.saveDraft(levels[1].id, payload);
    final compact = controller.draftFor(levels[1].id)!;
    final strokes = compact['strokes'] as List;
    expect(strokes, hasLength(20));
    expect(
      strokes.fold<int>(
        0,
        (sum, stroke) => sum + (stroke['points'] as List).length,
      ),
      lessThanOrEqualTo(ArtworkLimits.maxTotalBrushPoints),
    );
    for (final stroke in strokes) {
      final points = stroke['points'] as List;
      expect(points.first, [0.0, .5]);
      expect(points.last[0], closeTo(1099 / 1100, .0001));
    }
    final reward = await controller.completeLevel(levels[1], artwork: payload);
    expect(reward.firstCompletion, isTrue);
    expect(controller.artworks.single.data['strokes'], hasLength(20));
  });
}
