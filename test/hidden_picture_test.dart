import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/engines/hidden_picture.dart';

/// Synthetic geometry tests input rules. It is not artwork or final hotspot
/// evidence: the authored image and contours require their own visual review.
Map<String, dynamic> _fixture() => {
  'version': 1,
  'id': 'test-reef',
  'asset': 'assets/images/levels/10-reef.png',
  'imageWidth': 1000,
  'imageHeight': 800,
  'targets': <dynamic>[
    for (var i = 0; i < 8; i++)
      {
        'id': 'animal-$i',
        'name': {'ru': 'Друг $i', 'kk': 'Дос $i', 'en': 'Friend $i'},
        'polygon': <dynamic>[
          [.1 + (i % 4) * .2, i < 4 ? .1 : .5],
          [.2 + (i % 4) * .2, i < 4 ? .1 : .5],
          [.2 + (i % 4) * .2, i < 4 ? .2 : .6],
          [.1 + (i % 4) * .2, i < 4 ? .2 : .6],
        ],
        'anchor': [.15 + (i % 4) * .2, i < 4 ? .15 : .55],
        'crop': [
          .09 + (i % 4) * .2,
          i < 4 ? .09 : .49,
          .21 + (i % 4) * .2,
          i < 4 ? .21 : .61,
        ],
      },
  ],
};

Map<String, dynamic> _target(Map<String, dynamic> json, [int index = 0]) =>
    (json['targets'] as List)[index] as Map<String, dynamic>;

Map<String, dynamic> _validDraft(HiddenPictureSpec spec) => {
  'version': 3,
  'kind': 'hiddenAnimals',
  'engine': 'rasterHidden',
  'specId': spec.id,
  'asset': spec.asset,
  'ageBand': 'preschool',
  'found': ['animal-0'],
};

void main() {
  group('reviewed bitmap spec contract', () {
    for (final scene in ['reef', 'forest']) {
      test(
        'authored $scene metadata decodes against its real asset contract',
        () {
          final spec = HiddenPictureSpec.decode(
            File('assets/content/hidden-$scene.json').readAsStringSync(),
          );
          expect(
            spec.asset,
            scene == 'reef'
                ? 'assets/images/levels/10-reef.png'
                : 'assets/images/levels/20-forest.png',
          );
          expect(spec.imageSize.width, greaterThan(0));
          expect(spec.imageSize.height, greaterThan(0));
          expect(spec.imageSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
          expect(spec.targets, hasLength(8));
          for (final target in spec.targets) {
            expect(target.path.contains(target.anchor), isTrue);
          }
        },
      );
    }

    test(
      'optional fingerprint binds drafts to the reviewed bitmap revision',
      () {
        final fingerprint = List.filled(32, 'AB').join();
        final json = _fixture()..['imageSha256'] = fingerprint;
        final spec = HiddenPictureSpec.fromJson(json);
        expect(spec.imageSha256, fingerprint.toLowerCase());
        final session = HiddenPictureSession(spec, AgeBand.primary);
        session.discover('animal-0');
        final draft = session.toJson();
        expect(draft['imageSha256'], fingerprint.toLowerCase());
        expect(
          HiddenPictureSession(spec, AgeBand.primary, draft: draft).found,
          {'animal-0'},
        );
        for (final replacement in [null, List.filled(32, 'cd').join()]) {
          final stale = Map<String, dynamic>.from(draft)
            ..['imageSha256'] = replacement;
          expect(
            HiddenPictureSession(spec, AgeBand.primary, draft: stale).found,
            isEmpty,
          );
        }
        for (final invalid in [42, 'abc', List.filled(64, 'z').join()]) {
          final bad = _fixture()..['imageSha256'] = invalid;
          expect(() => HiddenPictureSpec.fromJson(bad), throwsFormatException);
        }
      },
    );

    test('normalizes geometry into source-image pixels', () {
      final spec = HiddenPictureSpec.decode(jsonEncode(_fixture()));
      expect(spec.imageSize, const Size(1000, 800));
      final first = spec.targets.first;
      expect(first.anchor, const Offset(150, 120));
      expect(first.path.getBounds(), const Rect.fromLTRB(100, 80, 200, 160));
      expect(first.cropRect, const Rect.fromLTRB(90, 72, 210, 168));
      expect(first.name.resolve('kk'), 'Дос 0');
      expect(spec.targetsFor(AgeBand.preschool), hasLength(2));
      expect(spec.targetsFor(AgeBand.primary), hasLength(4));
      expect(spec.targetsFor(AgeBand.advanced), hasLength(8));
    });

    test('geometry and collections cannot be mutated by a caller', () {
      final spec = HiddenPictureSpec.fromJson(_fixture());
      final first = spec.targets.first;
      first.path.reset();
      expect(first.path.contains(first.anchor), isTrue);
      expect(() => first.polygon.add(Offset.zero), throwsUnsupportedError);
      expect(() => spec.targets.add(first), throwsUnsupportedError);
      expect(
        () => spec.targetsFor(AgeBand.preschool).clear(),
        throwsUnsupportedError,
      );
    });

    test('accepts an explicitly closed simple polygon', () {
      final json = _fixture();
      final points = _target(json)['polygon'] as List;
      points.add(List<double>.from(points.first as List));
      final spec = HiddenPictureSpec.fromJson(json);
      expect(spec.targets.first.polygon, hasLength(4));
    });

    test('rejects wrong version, nonobjects, and target count', () {
      expect(() => HiddenPictureSpec.decode('[]'), throwsFormatException);
      final badVersion = _fixture()..['version'] = 2;
      expect(
        () => HiddenPictureSpec.fromJson(badVersion),
        throwsFormatException,
      );
      final missingTarget = _fixture();
      (missingTarget['targets'] as List).removeLast();
      expect(
        () => HiddenPictureSpec.fromJson(missingTarget),
        throwsFormatException,
      );
      final invalidTarget = _fixture();
      (invalidTarget['targets'] as List)[0] = null;
      expect(
        () => HiddenPictureSpec.fromJson(invalidTarget),
        throwsFormatException,
      );
    });

    test('rejects missing names, duplicate IDs and unsafe asset paths', () {
      final badName = _fixture();
      (_target(badName)['name'] as Map)['kk'] = '  ';
      expect(() => HiddenPictureSpec.fromJson(badName), throwsFormatException);
      final duplicate = _fixture();
      _target(duplicate, 1)['id'] = 'animal-0';
      expect(
        () => HiddenPictureSpec.fromJson(duplicate),
        throwsFormatException,
      );
      for (final asset in [
        '../private.png',
        'assets/images/levels/../../private.png',
        'https://example.com/reef.png',
        'assets/images/levels/reef.jpg',
      ]) {
        final json = _fixture()..['asset'] = asset;
        expect(() => HiddenPictureSpec.fromJson(json), throwsFormatException);
      }
    });

    test('rejects invalid dimensions and out-of-image or nonfinite points', () {
      for (final dimension in [
        0,
        -1,
        16385,
        1.5,
        double.infinity,
        double.nan,
      ]) {
        final json = _fixture()..['imageWidth'] = dimension;
        expect(() => HiddenPictureSpec.fromJson(json), throwsFormatException);
      }
      for (final coordinate in [-.01, 1.01, double.infinity, double.nan, 'x']) {
        final json = _fixture();
        (_target(json)['polygon'] as List)[0] = [coordinate, .1];
        expect(() => HiddenPictureSpec.fromJson(json), throwsFormatException);
      }
    });

    test('rejects degenerate, crossed and duplicate-vertex contours', () {
      for (final polygon in [
        [
          [.1, .1],
          [.2, .1],
          [.3, .1],
        ],
        [
          [.1, .1],
          [.3, .3],
          [.1, .3],
          [.3, .1],
          [.35, .2],
        ],
        [
          [.1, .1],
          [.1, .1],
          [.2, .2],
          [.1, .2],
        ],
      ]) {
        final json = _fixture();
        _target(json)['polygon'] = polygon;
        expect(() => HiddenPictureSpec.fromJson(json), throwsFormatException);
      }
    });

    test(
      'requires interior anchors and crops containing the whole contour',
      () {
        final badAnchor = _fixture();
        _target(badAnchor)['anchor'] = [.5, .5];
        expect(
          () => HiddenPictureSpec.fromJson(badAnchor),
          throwsFormatException,
        );
        for (final crop in [
          [.15, .09, .21, .21],
          [.09, .09, .19, .21],
          [.09, .09, .21, .19],
          [.2, .2, .1, .1],
        ]) {
          final json = _fixture();
          _target(json)['crop'] = crop;
          expect(() => HiddenPictureSpec.fromJson(json), throwsFormatException);
        }
      },
    );
  });

  group('actual discovery rules', () {
    late HiddenPictureSpec spec;
    setUp(() => spec = HiddenPictureSpec.fromJson(_fixture()));

    test('only the active age-appropriate targets can be discovered', () {
      final session = HiddenPictureSession(spec, AgeBand.preschool);
      expect(session.activeTargets, hasLength(2));
      expect(session.discover('animal-5'), isFalse);
      expect(session.discover('not-a-target'), isFalse);
      expect(session.findAt(spec.targets[5].anchor), isNull);
      expect(session.findAt(spec.targets[0].anchor)?.id, 'animal-0');
      expect(session.discover('animal-0'), isTrue);
      expect(session.discover('animal-0'), isFalse);
      expect(session.findAt(spec.targets[0].anchor), isNull);
      expect(
        session.findAt(spec.targets[0].anchor, tolerance: 200),
        isNull,
        reason: 'A repeated hit must not jump to a nearby remaining target',
      );
      expect(session.isComplete, isFalse);
      expect(session.discover('animal-1'), isTrue);
      expect(session.isComplete, isTrue);
      expect(session.remainingTargets, isEmpty);
      expect(() => session.found.add('animal-5'), throwsUnsupportedError);
    });

    test(
      'bounded closest hit helps imprecise taps without awarding far ground',
      () {
        final session = HiddenPictureSession(spec, AgeBand.preschool);
        expect(session.findAt(const Offset(205, 120)), isNull);
        expect(
          session.findAt(const Offset(205, 120), tolerance: 5)?.id,
          'animal-0',
        );
        expect(session.findAt(const Offset(206, 120), tolerance: 5), isNull);
        expect(session.findAt(const Offset(950, 750), tolerance: 28), isNull);
        expect(session.findAt(const Offset(-1, 120), tolerance: 100), isNull);
      },
    );

    test(
      'equal-distance and overlapping hits do not choose declaration order',
      () {
        final session = HiddenPictureSession(spec, AgeBand.preschool);
        expect(session.findAt(const Offset(250, 120), tolerance: 50), isNull);
        final json = _fixture();
        _target(json, 1)['polygon'] = [
          [.15, .1],
          [.25, .1],
          [.25, .2],
          [.15, .2],
        ];
        _target(json, 1)['anchor'] = [.2, .15];
        _target(json, 1)['crop'] = [.14, .09, .26, .21];
        final overlap = HiddenPictureSession(
          HiddenPictureSpec.fromJson(json),
          AgeBand.preschool,
        );
        expect(overlap.findAt(const Offset(175, 120)), isNull);
      },
    );

    test(
      'input NaN, infinity or negative tolerance never discovers anything',
      () {
        final session = HiddenPictureSession(spec, AgeBand.advanced);
        expect(session.findAt(const Offset(double.nan, 120)), isNull);
        expect(session.findAt(const Offset(150, double.infinity)), isNull);
        for (final tolerance in [-1.0, double.nan, double.infinity]) {
          expect(
            session.findAt(spec.targets.first.anchor, tolerance: tolerance),
            isNull,
          );
        }
        expect(session.found, isEmpty);
      },
    );

    test('all eight discoveries are required for the advanced band', () {
      final session = HiddenPictureSession(spec, AgeBand.advanced);
      for (final target in spec.targets.take(7)) {
        final hit = session.findAt(target.anchor);
        expect(hit?.id, target.id);
        expect(session.discover(hit!.id), isTrue);
      }
      expect(session.isComplete, isFalse);
      session.discover(spec.targets.last.id);
      expect(session.isComplete, isTrue);
    });

    test('saves canonical source identity and authored target ordering', () {
      final session = HiddenPictureSession(spec, AgeBand.primary);
      session.discover('animal-1');
      session.discover('animal-0');
      final draft = session.toJson();
      expect(draft, {
        'version': 3,
        'kind': 'hiddenAnimals',
        'engine': 'rasterHidden',
        'specId': spec.id,
        'asset': spec.asset,
        'ageBand': 'primary',
        'found': ['animal-0', 'animal-1'],
      });
      final restored = HiddenPictureSession(
        spec,
        AgeBand.primary,
        draft: draft,
      );
      expect(restored.found, {'animal-0', 'animal-1'});
      expect(restored.isComplete, isFalse);
    });

    test('restores valid unique IDs but never inactive or unknown targets', () {
      final draft = _validDraft(spec)
        ..['found'] = ['animal-0', 'animal-0', 'animal-7', 'unknown', 42];
      final session = HiddenPictureSession(
        spec,
        AgeBand.preschool,
        draft: draft,
      );
      expect(session.found, {'animal-0'});
      expect(session.isComplete, isFalse);
    });

    test(
      'a harder age band preserves progress and adds genuinely remaining work',
      () {
        final young = HiddenPictureSession(spec, AgeBand.preschool);
        young.discover('animal-0');
        young.discover('animal-1');
        expect(young.isComplete, isTrue);
        final older = HiddenPictureSession(
          spec,
          AgeBand.advanced,
          draft: young.toJson(),
        );
        expect(older.found, {'animal-0', 'animal-1'});
        expect(older.remainingTargets, hasLength(6));
        expect(older.isComplete, isFalse);
      },
    );

    test(
      'rejects stale asset identity, legacy drafts and malformed metadata',
      () {
        for (final patch in <Map<String, dynamic>>[
          {'version': 2},
          {'kind': 'freeColor'},
          {'engine': 'legacyGeometry'},
          {'specId': 'another-scene'},
          {'asset': 'assets/images/levels/20-forest.png'},
          {'ageBand': 'adult'},
          {'found': 'animal-0'},
          {'found': List.filled(100, 'animal-0')},
        ]) {
          final draft = _validDraft(spec)..addAll(patch);
          final session = HiddenPictureSession(
            spec,
            AgeBand.primary,
            draft: draft,
          );
          expect(session.found, isEmpty, reason: 'Invalid draft patch: $patch');
        }
      },
    );
  });
}
