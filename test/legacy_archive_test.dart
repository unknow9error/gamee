import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/data/legacy_archive.dart';
import 'package:tiny_trails/data/legacy_catalog.dart';
import 'package:tiny_trails/domain/models.dart';

void main() {
  test(
    'v1 archive keeps exactly its original six worlds and 120 level IDs',
    () {
      const worldIds = ['ocean', 'forest', 'meadow', 'farm', 'safari', 'space'];
      const kindNames = [
        'numberColor',
        'freeColor',
        'maze',
        'guidedDraw',
        'hiddenAnimals',
      ];
      final expectedIds = {
        for (final world in worldIds)
          for (var chapter = 1; chapter <= 4; chapter++)
            for (final kind in kindNames) '${world}_${kind}_$chapter',
      };
      expect(legacyWorlds.map((world) => world.id), worldIds);
      expect(legacyLevels, hasLength(120));
      expect(legacyLevelIndex.keys.toSet(), expectedIds);
      expect(legacyWorldIndex.keys.toSet(), worldIds.toSet());
      for (final worldId in worldIds) {
        final levels = legacyLevelsForWorld(worldId);
        expect(levels, hasLength(20));
        expect(
          levels.map((level) => level.order),
          List.generate(20, (index) => index),
        );
        expect(
          levels.map((level) => level.kind.name).toSet(),
          kindNames.toSet(),
        );
      }
    },
  );

  test(
    'v1 copy and scene parameters stay usable without the active catalog',
    () {
      final whale = legacyLevelIndex['ocean_numberColor_1']!;
      expect(whale.kind, ActivityKind.numberColor);
      expect(whale.scene, 'whale');
      expect(whale.variant, 0);
      expect(whale.difficulty, 1);
      expect(whale.title.ru, 'Кит: первое открытие');
      expect(whale.title.kk, 'Кит: алғашқы жаңалық');
      expect(whale.title.en, 'Whale: first discovery');
      expect(
        whale.instruction.en,
        'Pick a numbered color, then tap the matching area. Reveal the hidden picture!',
      );
      final finalLevel = legacyLevelIndex['space_hiddenAnimals_4']!;
      expect(finalLevel.scene, 'rocket');
      expect(finalLevel.variant, 3);
      expect(finalLevel.difficulty, 4);
      expect(finalLevel.order, 19);
      expect(legacyWorldIndex['safari']!.title.ru, 'Большое сафари');
      expect(legacyWorldIndex['safari']!.color, 0xFFC37A4D);
      expect(legacyWorldIndex['safari']!.scene, 'giraffe');
    },
  );

  test('v1 archive reads all 120 scores and preserves original settings', () {
    final source = _snapshot(
      progress: {
        for (final id in legacyLevelIndex.keys)
          id: {
            'stars': 3,
            'attempts': 2,
            'completedAt': '2026-11-16T12:30:00.000',
          },
      },
    );
    final archive = LegacyArchive.fromEncoded(source);
    expect(archive.originalSnapshot, source);
    expect(archive.hasData, isTrue);
    expect(archive.completedCount, 120);
    expect(archive.totalStars, 360);
    expect(archive.damagedEntries, 0);
    expect(archive.settings['language'], 'kk');
    expect(() => archive.progress.clear(), throwsUnsupportedError);
    expect(() => archive.settings.clear(), throwsUnsupportedError);
  });

  test('legacy drawing points are retained without applying the v2 budget', () {
    final points = List.generate(9000, (index) => [index / 9000, 0.25]);
    final data = {
      'strokes': [
        {'color': 4278190080, 'points': points},
      ],
    };
    final source = _snapshot(
      drafts: {'space_guidedDraw_4': data},
      artworks: [
        {
          'levelId': 'space_freeColor_4',
          'createdAt': '2026-11-16T12:30:00.123456Z',
          'data': data,
        },
      ],
    );
    final archive = LegacyArchive.fromEncoded(source);
    expect(archive.draftCount, 1);
    expect(archive.artworkCount, 1);
    expect(archive.artworks.single.data['strokes'][0]['points'], points);
    expect(
      archive.drafts['space_guidedDraw_4']!['strokes'][0]['points'],
      hasLength(9000),
    );
    expect(
      () => archive.drafts['space_guidedDraw_4']!.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (archive.artworks.single.data['strokes'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(archive.originalSnapshot, source);
  });

  test(
    'damaged individual entries are isolated while their raw source remains',
    () {
      final source = _snapshot(
        progress: {
          'ocean_numberColor_1': {
            'stars': 2,
            'attempts': 1,
            'completedAt': '2026-11-16T12:30:00.000',
          },
          'ocean_freeColor_1': {
            'stars': 4,
            'attempts': 1,
            'completedAt': '2026-11-16T12:30:00.000',
          },
          'ocean_maze_1': {
            'stars': 3,
            'attempts': 1,
            'completedAt': '2026-02-31T12:30:00.000',
          },
          'unknown_level': {
            'stars': 3,
            'completedAt': '2026-11-16T12:30:00.000',
          },
        },
        drafts: {
          'ocean_hiddenAnimals_1': ['wrong-shape'],
        },
        artworks: [
          {
            'levelId': 'ocean_freeColor_1',
            'createdAt': '2026-11-16T25:30:00.000',
            'data': {'fills': {}},
          },
        ],
      );
      final archive = LegacyArchive.fromEncoded(source);
      expect(archive.completedCount, 1);
      expect(archive.totalStars, 2);
      expect(archive.damagedEntries, 5);
      expect(archive.originalSnapshot, source);
    },
  );

  test(
    'invalid outer snapshots throw so migration can try the untouched backup',
    () {
      for (final source in [
        'not-json',
        '[]',
        '{"version":2,"settings":{}}',
        '{"version":1.0,"settings":{}}',
        '{"version":1,"settings":false}',
        '{"version":1,"settings":{},"progress":[]}',
        '{"version":1,"settings":{},"artworks":{}}',
      ]) {
        expect(() => LegacyArchive.fromEncoded(source), throwsFormatException);
      }
      final empty = LegacyArchive.fromEncoded(_snapshot());
      expect(empty.hasData, isFalse);
      expect(empty.damagedEntries, 0);
    },
  );
}

String _snapshot({
  Map<String, dynamic>? progress,
  Map<String, dynamic>? drafts,
  List<dynamic>? artworks,
}) => jsonEncode({
  'version': 1,
  'settings': {'language': 'kk', 'sound': false, 'onboardingComplete': true},
  'progress': progress ?? {},
  'drafts': drafts ?? {},
  'artworks': artworks ?? [],
});
