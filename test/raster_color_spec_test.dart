import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';

const _symbols = [
  'circle',
  'triangle',
  'square',
  'star',
  'heart',
  'diamond',
  'flower',
  'leaf',
];
const _colors = [
  '#EA7563',
  '#F3AA69',
  '#F5D66B',
  '#90BC77',
  '#439282',
  '#6EBBDA',
  '#5375BD',
  '#9F83CC',
];

/// Controlled metadata only: it does not stand in for reviewed production art.
Map<String, dynamic> _fixture() {
  final palette = List.generate(
    8,
    (index) => <String, dynamic>{
      'id': 'paint_$index',
      'color': _colors[index],
      'symbol': _symbols[index],
      'number': index + 1,
      'names': {
        'ru': 'Краска $index',
        'kk': 'Түс $index',
        'en': 'Paint $index',
      },
    },
  );
  final regions = List.generate(8, (index) {
    final left = .05 + (index % 4) * .24;
    final top = .08 + (index ~/ 4) * .43;
    return <String, dynamic>{
      'id': 'piece_$index',
      'paletteId': 'paint_$index',
      'points': [
        [left, top],
        [left + .17, top],
        [left + .17, top + .28],
        [left, top + .28],
      ],
      'anchor': [left + .085, top + .14],
      'value': index + 1,
      'symbol': _symbols[index],
      'advancedValue': index % 4 + 1,
      'advancedSymbol': index < 4 ? 'circle' : 'triangle',
      'names': {
        'ru': 'Фигура $index',
        'kk': 'Пішін $index',
        'en': 'Shape $index',
      },
      'preschool': index < 4,
    };
  });
  final ids = List.generate(8, (index) => 'piece_$index');
  return {
    'version': 1,
    'asset': 'assets/images/levels/01-toybox.png',
    'assetSha256': List.filled(64, '0').join(),
    'imageWidth': 1024,
    'imageHeight': 1024,
    'palette': palette,
    'regions': regions,
    'rules': {
      'preschool': {'regionIds': ids.take(4).toList(), 'mode': 'color'},
      'primary': {'regionIds': List.of(ids), 'mode': 'number'},
      'advanced': {
        'regionIds': List.of(ids),
        'mode': 'numberAndShape',
        'lookup': List<Map<String, dynamic>>.generate(
          8,
          (index) => <String, dynamic>{
            'paletteId': 'paint_$index',
            'value': index % 4 + 1,
            'symbol': index < 4 ? 'circle' : 'triangle',
          },
        ),
      },
    },
  };
}

List<Map<String, dynamic>> _regions(Map<String, dynamic> json) =>
    (json['regions'] as List).cast<Map<String, dynamic>>();
List<Map<String, dynamic>> _palette(Map<String, dynamic> json) =>
    (json['palette'] as List).cast<Map<String, dynamic>>();
Map<String, dynamic> _rule(Map<String, dynamic> json, String age) =>
    (json['rules'] as Map)[age] as Map<String, dynamic>;
List<Map<String, dynamic>> _lookup(Map<String, dynamic> json) =>
    (_rule(json, 'advanced')['lookup'] as List).cast<Map<String, dynamic>>();

void main() {
  test('optional readable clue slots are normalized and immutable', () {
    expect(ColorSceneSpec.fromJson(_fixture()).labelSlots, isEmpty);
    final json = _fixture()
      ..['labelSlots'] = [
        [.02, .01, .30, .05],
        [.32, .01, .10, .05],
      ];
    final spec = ColorSceneSpec.fromJson(json);
    expect(spec.labelSlots, hasLength(2));
    expect(spec.labelSlots.first, const Rect.fromLTWH(.02, .01, .30, .05));
    expect(
      () => spec.labelSlots.add(const Rect.fromLTWH(0, 0, .1, .1)),
      throwsUnsupportedError,
    );
    expect(spec.regionsFor(AgeBand.primary), hasLength(8));
  });

  test(
    'rejects invalid or overlapping clue slots without changing target masks',
    () {
      for (final slot in [
        [0, 0, 0, .1],
        [0, 0, .1, -.1],
        [.9, 0, .2, .1],
        [0, .9, .1, .2],
        [double.nan, 0, .1, .1],
        [0, 0, double.infinity, .1],
        [0, 0, .1],
      ]) {
        final json = _fixture()..['labelSlots'] = [slot];
        expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
      }
      final overlap = _fixture()
        ..['labelSlots'] = [
          [0, 0, .2, .2],
          [.1, .1, .2, .2],
        ];
      expect(() => ColorSceneSpec.fromJson(overlap), throwsFormatException);
    },
  );

  test('resolves the reviewed region set and palette for each age', () {
    final scene = ColorSceneSpec.fromJson(_fixture());
    expect(scene.asset, 'assets/images/levels/01-toybox.png');
    expect(scene.imageWidth, 1024);
    expect(scene.imageHeight, 1024);
    expect(scene.regionsFor(AgeBand.preschool), hasLength(4));
    expect(scene.regionsFor(AgeBand.primary), hasLength(8));
    expect(scene.regionsFor(AgeBand.advanced), hasLength(8));
    expect(scene.paletteFor(AgeBand.preschool), hasLength(4));
    expect(scene.ruleFor(AgeBand.preschool).mode, ColorRuleMode.color);
    expect(scene.ruleFor(AgeBand.primary).mode, ColorRuleMode.number);
    expect(scene.ruleFor(AgeBand.advanced).mode, ColorRuleMode.numberAndShape);
    for (final age in AgeBand.values) {
      for (final region in scene.regionsFor(age)) {
        expect(scene.acceptedPaletteFor(region, age).id, region.paletteId);
        expect(region.path.contains(region.anchor), isTrue);
      }
    }
    final first = scene.regionById('piece_0');
    expect(first.path.contains(const Offset(.01, .01)), isFalse);
    expect(scene.paletteById(first.paletteId).names.en, 'Paint 0');
  });

  test('supports parity and shape rules without assigning colors by index', () {
    final json = _fixture();
    final advanced = _rule(json, 'advanced');
    advanced['mode'] = 'parityAndShape';
    for (var index = 0; index < 8; index++) {
      _regions(json)[index]['advancedValue'] = index + 1;
      _regions(json)[index]['advancedSymbol'] = _symbols[index ~/ 2];
    }
    advanced['lookup'] = List.generate(
      8,
      (index) => {
        'paletteId': 'paint_$index',
        'parity': (index + 1).isOdd ? 'odd' : 'even',
        'symbol': _symbols[index ~/ 2],
      },
    );
    final scene = ColorSceneSpec.fromJson(json);
    expect(scene.ruleFor(AgeBand.advanced).mode, ColorRuleMode.parityAndShape);
    for (final region in scene.regionsFor(AgeBand.advanced)) {
      expect(
        scene.acceptedPaletteFor(region, AgeBand.advanced).id,
        region.paletteId,
      );
    }
  });

  test(
    'advanced clues can change without changing the primary number answer',
    () {
      final json = _fixture();
      for (var index = 0; index < 8; index++) {
        _regions(json)[index]['advancedValue'] = index % 4 + 1;
        _regions(json)[index]['advancedSymbol'] = index < 4
            ? 'circle'
            : 'triangle';
      }
      _rule(json, 'advanced')['lookup'] = List.generate(
        8,
        (index) => {
          'paletteId': 'paint_$index',
          'value': index % 4 + 1,
          'symbol': index < 4 ? 'circle' : 'triangle',
        },
      );
      final scene = ColorSceneSpec.fromJson(json);
      for (final region in scene.regions) {
        expect(
          scene.acceptedPaletteFor(region, AgeBand.primary).id,
          region.paletteId,
        );
        expect(
          scene.acceptedPaletteFor(region, AgeBand.advanced).id,
          region.paletteId,
        );
      }
    },
  );

  test('holes preserve unpainted windows inside a closed object', () {
    final json = _fixture();
    _regions(json).first['holes'] = [
      [
        [.10, .14],
        [.17, .14],
        [.17, .20],
        [.10, .20],
      ],
    ];
    final scene = ColorSceneSpec.fromJson(json);
    final path = scene.regionById('piece_0').path;
    expect(path.contains(const Offset(.08, .12)), isTrue);
    expect(path.contains(const Offset(.13, .17)), isFalse);
    expect(path.contains(scene.regionById('piece_0').anchor), isTrue);
  });

  test('a shape legend can share a paint across several regions', () {
    final json = _fixture();
    _rule(json, 'primary')['mode'] = 'shape';
    _regions(json)[1]['paletteId'] = 'paint_0';
    _regions(json)[1]['symbol'] = 'circle';
    _regions(json)[1]['value'] = 1;
    _regions(json)[1]['advancedValue'] = 1;
    _regions(json)[1]['advancedSymbol'] = 'circle';
    _lookup(json).removeAt(1);
    final scene = ColorSceneSpec.fromJson(json);
    expect(scene.paletteFor(AgeBand.primary), hasLength(7));
    expect(
      scene.acceptedPaletteFor(scene.regionById('piece_1'), AgeBand.primary).id,
      'paint_0',
    );
  });

  test('rejects numbers whose legend paint disagrees with the artwork', () {
    final json = _fixture();
    _regions(json)[0]['value'] = 2;
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test('rejects two different paints with the same shape legend', () {
    final json = _fixture();
    _rule(json, 'primary')['mode'] = 'shape';
    _palette(json)[1]['symbol'] = 'circle';
    _regions(json)[1]['symbol'] = 'circle';
    _lookup(json)[1]['symbol'] = 'circle';
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test('rejects advanced lookup answers inconsistent with original colors', () {
    final json = _fixture();
    _lookup(json)[0]['paletteId'] = 'paint_1';
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test(
    'rejects a decorative second condition that never changes the answer',
    () {
      final json = _fixture();
      for (var index = 0; index < 8; index++) {
        _regions(json)[index]['advancedValue'] = index + 1;
        _regions(json)[index]['advancedSymbol'] = _symbols[index];
      }
      _rule(json, 'advanced')['lookup'] = List.generate(
        8,
        (index) => {
          'paletteId': 'paint_$index',
          'value': index + 1,
          'symbol': _symbols[index],
        },
      );
      expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
    },
  );

  test('rejects ambiguous advanced clue pairs', () {
    final json = _fixture();
    _lookup(json).add(Map.of(_lookup(json).first)..['paletteId'] = 'paint_1');
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test('rejects a missing lookup answer instead of guessing a palette', () {
    final json = _fixture();
    _lookup(json).removeAt(0);
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test('rejects unknown and repeated regions in an age plan', () {
    final unknown = _fixture();
    (_rule(unknown, 'primary')['regionIds'] as List)[0] = 'unreviewed_piece';
    expect(() => ColorSceneSpec.fromJson(unknown), throwsFormatException);
    final duplicate = _fixture();
    (_rule(duplicate, 'primary')['regionIds'] as List)[1] = 'piece_0';
    expect(() => ColorSceneSpec.fromJson(duplicate), throwsFormatException);
  });

  test('rejects duplicate palette and region identifiers', () {
    final duplicatePalette = _fixture();
    _palette(duplicatePalette)[1]['id'] = 'paint_0';
    expect(
      () => ColorSceneSpec.fromJson(duplicatePalette),
      throwsFormatException,
    );
    final duplicateRegion = _fixture();
    _regions(duplicateRegion)[1]['id'] = 'piece_0';
    expect(
      () => ColorSceneSpec.fromJson(duplicateRegion),
      throwsFormatException,
    );
  });

  test(
    'rejects incomplete age plans instead of silently reducing the game',
    () {
      final missing = _fixture();
      (missing['rules'] as Map).remove('advanced');
      expect(() => ColorSceneSpec.fromJson(missing), throwsFormatException);
      final preschoolTooShort = _fixture();
      _rule(preschoolTooShort, 'preschool')['regionIds'] = ['piece_0'];
      expect(
        () => ColorSceneSpec.fromJson(preschoolTooShort),
        throwsFormatException,
      );
      final primaryTooShort = _fixture();
      _rule(primaryTooShort, 'primary')['regionIds'] = List.generate(
        5,
        (index) => 'piece_$index',
      );
      expect(
        () => ColorSceneSpec.fromJson(primaryTooShort),
        throwsFormatException,
      );
    },
  );

  test('rejects unsupported versions and invalid source image dimensions', () {
    final newer = _fixture()..['version'] = 99;
    expect(() => ColorSceneSpec.fromJson(newer), throwsFormatException);
    final noWidth = _fixture()..['imageWidth'] = 0;
    expect(() => ColorSceneSpec.fromJson(noWidth), throwsFormatException);
    final fractionHeight = _fixture()..['imageHeight'] = 1024.5;
    expect(
      () => ColorSceneSpec.fromJson(fractionHeight),
      throwsFormatException,
    );
  });

  test('rejects nonfinite and out-of-bounds geometry', () {
    for (final coordinate in [double.nan, double.infinity, -.01, 1.01]) {
      final json = _fixture();
      (_regions(json).first['points'] as List)[0] = [coordinate, .08];
      expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
    }
  });

  test(
    'rejects self-intersecting polygons and anchors outside their region',
    () {
      final crossed = _fixture();
      _regions(crossed).first['points'] = [
        [.05, .08],
        [.22, .36],
        [.05, .36],
        [.20, .08],
      ];
      // This crossed polygon still has positive signed area and an anchor in
      // its lower lobe, so area/anchor checks alone cannot reject the defect.
      _regions(crossed).first['anchor'] = [.12, .30];
      expect(() => ColorSceneSpec.fromJson(crossed), throwsFormatException);
      final outside = _fixture();
      _regions(outside).first['anchor'] = [.9, .9];
      expect(() => ColorSceneSpec.fromJson(outside), throwsFormatException);
    },
  );

  test('rejects degenerate regions with no usable interior', () {
    final json = _fixture();
    _regions(json).first['points'] = [
      [.1, .1],
      [.2, .2],
      [.3, .3],
    ];
    _regions(json).first['anchor'] = [.2, .2];
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test('does not mistake nearby short parallel edges for an intersection', () {
    final json = _fixture();
    _regions(json).first['points'] = [
      [.100, .100],
      [.101, .101],
      [.102, .100],
      [.102, .102],
      [.101, .102],
      [.100, .101],
    ];
    _regions(json).first['anchor'] = [.1013, .1014];
    final scene = ColorSceneSpec.fromJson(json);
    expect(
      scene.regionById('piece_0').path.contains(const Offset(.1013, .1014)),
      isTrue,
    );
  });

  test('rejects overlapping required masks with otherwise valid rules', () {
    final json = _fixture();
    _regions(json)[1]['points'] = [
      [.10, .12],
      [.27, .12],
      [.27, .40],
      [.10, .40],
    ];
    _regions(json)[1]['anchor'] = [.185, .26];
    expect(() => ColorSceneSpec.fromJson(json), throwsFormatException);
  });

  test(
    'rejects unbounded content and malformed assets without echoing values',
    () {
      for (final field in ['asset', 'assetSha256', 'color', 'symbol']) {
        final json = _fixture();
        const syntheticMarker = 'invalid-private-looking-sentinel';
        if (field == 'color' || field == 'symbol') {
          _palette(json).first[field] = syntheticMarker;
        } else {
          json[field] = syntheticMarker;
        }
        try {
          ColorSceneSpec.fromJson(json);
          fail('Invalid $field must not be accepted');
        } on FormatException catch (error) {
          expect(error.message, isNot(contains(syntheticMarker)));
        }
      }
      final unsafePath = _fixture()
        ..['asset'] = 'assets/images/levels/../outside.png';
      expect(() => ColorSceneSpec.fromJson(unsafePath), throwsFormatException);
    },
  );
}
