import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/domain/artwork_limits.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/play/engines/raster_color_document.dart';
import 'package:tiny_trails/features/play/engines/raster_color_spec.dart';

ColorSceneSpec _spec() {
  const colors = [
    '#EF7A70',
    '#7BBA86',
    '#F0C95B',
    '#7CAFE0',
    '#B69BDC',
    '#EDAA7D',
    '#60BDB4',
    '#D58AAC',
  ];
  final ids = List.generate(8, (i) => 'region-${i + 1}');
  return ColorSceneSpec.fromJson({
    'version': 1,
    'asset': 'assets/images/levels/synthetic-test.png',
    'assetSha256': List.filled(64, 'a').join(),
    'imageWidth': 1024,
    'imageHeight': 1024,
    'palette': [
      for (var i = 0; i < 8; i++)
        {
          'id': 'paint-${i + 1}',
          'color': colors[i],
          'number': i + 1,
          'symbol': i < 4 ? 'circle' : 'triangle',
          'names': {'ru': 'Цвет', 'kk': 'Түс', 'en': 'Color'},
        },
    ],
    'regions': [
      for (var i = 0; i < 8; i++)
        {
          'id': ids[i],
          'paletteId': 'paint-${i + 1}',
          'points': [
            [.03 + (i % 4) * .245, .03 + (i ~/ 4) * .49],
            [.235 + (i % 4) * .245, .03 + (i ~/ 4) * .49],
            [.235 + (i % 4) * .245, .46 + (i ~/ 4) * .49],
            [.03 + (i % 4) * .245, .46 + (i ~/ 4) * .49],
          ],
          'anchor': [.13 + (i % 4) * .245, .24 + (i ~/ 4) * .49],
          'value': i + 1,
          'symbol': 'circle',
          'advancedValue': i % 4 + 1,
          'advancedSymbol': i < 4 ? 'circle' : 'triangle',
          'preschool': i < 4,
          'names': {'ru': 'Игрушка', 'kk': 'Ойыншық', 'en': 'Toy'},
        },
      {
        'id': 'decoration',
        'paletteId': 'paint-1',
        'points': [
          [.04, .47],
          [.20, .47],
          [.20, .50],
          [.04, .50],
        ],
        'anchor': [.12, .485],
        'value': 1,
        'symbol': 'circle',
        'names': {'ru': 'Украшение', 'kk': 'Әшекей', 'en': 'Decoration'},
      },
    ],
    'rules': {
      'preschool': {'regionIds': ids.take(4).toList(), 'mode': 'color'},
      'primary': {'regionIds': ids, 'mode': 'number'},
      'advanced': {
        'regionIds': ids,
        'mode': 'numberAndShape',
        'lookup': [
          for (var i = 0; i < 8; i++)
            {
              'paletteId': 'paint-${i + 1}',
              'value': i % 4 + 1,
              'symbol': i < 4 ? 'circle' : 'triangle',
            },
        ],
      },
    },
  });
}

void _line(RasterColorDocument document, {bool eraser = false, String? clip}) {
  document.beginStroke(
    const Offset(.07, .12),
    width: 20,
    eraser: eraser,
    clipRegionId: clip,
  );
  document.appendStroke(const Offset(.20, .12));
  document.endStroke();
}

void main() {
  test(
    'unclipped legacy marks outside all reviewed interiors stay invisible',
    () {
      final document = RasterColorDocument(
        spec: _spec(),
        ageBand: AgeBand.primary,
      );
      addTearDown(document.dispose);
      document.setCreative(true);
      document.beginStroke(const Offset(.05, .005), width: 4);
      document.appendStroke(const Offset(.9, .005));
      document.endStroke();
      expect(document.visibleInkCells, 0);
      expect(document.canFinish, isFalse);
    },
  );
  for (final band in AgeBand.values) {
    test('only the correct age-specific regions complete ${band.name}', () {
      final spec = _spec();
      final document = RasterColorDocument(spec: spec, ageBand: band);
      addTearDown(document.dispose);
      expect(document.requiredCount, band == AgeBand.preschool ? 4 : 8);
      expect(document.canFinish, isFalse);
      document.selectPalette('paint-2');
      expect(document.fillRegion('region-1'), isFalse);
      expect(document.completedCount, 0);
      expect(document.fillRegion('unknown'), isFalse);
      document.selectPalette('paint-1');
      expect(
        document.fillRegion('decoration'),
        isFalse,
        reason: 'A color match must not turn decoration into a task target',
      );
      if (band == AgeBand.preschool) {
        expect(document.fillRegion('region-8'), isFalse);
      }
      for (final region in spec.regionsFor(band)) {
        document.selectPalette(spec.acceptedPaletteIdFor(region, band));
        expect(document.fillRegion(region.id), isTrue);
        expect(document.fillRegion(region.id), isFalse);
      }
      expect(document.completedCount, document.requiredCount);
      expect(document.solved, isTrue);
      expect(document.canFinish, isTrue);
      document.undo();
      expect(document.canFinish, isFalse);
      document.redo();
      expect(document.canFinish, isTrue);
    });
  }

  test('advanced colors need both clues, including a matching shape', () {
    final document = RasterColorDocument(
      spec: _spec(),
      ageBand: AgeBand.advanced,
    );
    addTearDown(document.dispose);
    document.selectPalette('paint-5'); // Value1 matches; triangle does not.
    expect(document.fillRegion('region-1'), isFalse);
    document.selectPalette('paint-2'); // Circle matches; value2 does not.
    expect(document.fillRegion('region-1'), isFalse);
    document.selectPalette('paint-1');
    expect(document.fillRegion('region-1'), isTrue);
    expect(document.completedCount, 1);
  });

  test('a guided task never accepts brush marks or wrong saved colors', () {
    final spec = _spec();
    final document = RasterColorDocument(spec: spec, ageBand: AgeBand.primary);
    addTearDown(document.dispose);
    _line(document);
    expect(document.strokes, isEmpty);
    final data = document.toJson();
    data['fills'] = {'region-1': 'paint-2', 'unknown': 'paint-1'};
    data['strokes'] = [
      {
        'points': [
          [.1, .1],
          [.8, .1],
        ],
        'color': 0xFF112233,
        'width': 20,
      },
    ];
    final restored = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.primary,
      initialData: data,
    );
    addTearDown(restored.dispose);
    expect(restored.fills, isEmpty);
    expect(restored.strokes, isEmpty);
    expect(restored.canFinish, isFalse);
  });

  test(
    'creative colors and marks are editable but a blank picture cannot finish',
    () {
      final document = RasterColorDocument(
        spec: _spec(),
        ageBand: AgeBand.preschool,
      );
      addTearDown(document.dispose);
      document.setCreative(true);
      expect(document.canFinish, isFalse);
      document.selectPalette('paint-8');
      expect(document.fillRegion('region-1'), isTrue);
      expect(document.completedCount, 0);
      expect(document.canFinish, isTrue);
      document.eraseRegion('region-1');
      expect(document.canFinish, isFalse);
      _line(document, clip: 'region-1');
      expect(document.visibleInkCells, greaterThanOrEqualTo(8));
      expect(document.canFinish, isTrue);
      _line(document, eraser: true, clip: 'region-1');
      expect(document.visibleInkCells, 0);
      expect(document.canFinish, isFalse);
      document.undo();
      expect(document.canFinish, isTrue);
      document.redo();
      expect(document.canFinish, isFalse);
    },
  );

  test('clipped-away and cancelled strokes cannot award visible work', () {
    final document = RasterColorDocument(
      spec: _spec(),
      ageBand: AgeBand.primary,
    );
    addTearDown(document.dispose);
    document.setCreative(true);
    document.beginStroke(const Offset(.4, .8), clipRegionId: 'region-1');
    document.appendStroke(const Offset(.8, .8));
    document.endStroke();
    expect(document.visibleInkCells, 0);
    expect(document.canFinish, isFalse);
    document.undo();
    expect(document.canRedo, isTrue);
    document.beginStroke(const Offset(.1, .1));
    expect(document.canRedo, isFalse);
    document.cancelStroke();
    expect(document.canRedo, isTrue);
    document.redo();
    expect(document.strokes, hasLength(1));
    expect(document.canFinish, isFalse);
  });

  test('creative replay returns to the task without accepting free colors', () {
    final spec = _spec();
    final document = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.preschool,
    );
    addTearDown(document.dispose);
    document.fillRegion('region-1');
    document.setCreative(true);
    document.selectPalette('paint-8');
    document.fillRegion('region-2');
    document.fillRegion('region-8');
    _line(document);
    document.setCreative(false);
    expect(document.fills, {'region-1': 'paint-1'});
    expect(document.strokes, isEmpty);
    expect(document.canFinish, isFalse);
    document.undo();
    expect(document.creative, isTrue);
    expect(
      document.fills.keys,
      containsAll(['region-1', 'region-2', 'region-8']),
    );
    expect(document.strokes, hasLength(1));
  });

  test('drafts are bound to the actual asset and reject malformed marks', () {
    final spec = _spec();
    final document = RasterColorDocument(spec: spec, ageBand: AgeBand.primary);
    addTearDown(document.dispose);
    document.setCreative(true);
    document.fillRegion('region-1');
    final draft = document.toJson();
    final wrongImage = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.primary,
      initialData: {...draft, 'assetSha256': List.filled(64, 'b').join()},
    );
    addTearDown(wrongImage.dispose);
    expect(wrongImage.fills, isEmpty);
    expect(wrongImage.creative, isFalse);
    draft['fills'] = {
      'region-1': 'paint-1',
      'unknown': 'paint-8',
      'region-2': 'unknown',
    };
    draft['strokes'] = [
      {
        'points': [
          [double.nan, .1],
          [.2, double.infinity],
        ],
        'color': 0xFF112233,
        'width': 12,
      },
      {
        'points': [
          [.1, .1],
        ],
        'color': 0xFF112233,
        'width': double.nan,
      },
      {
        'points': [
          [.1, .1],
        ],
        'color': 0xFF112233,
        'width': 12,
        'clipRegionId': 'unknown',
      },
    ];
    final restored = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.primary,
      initialData: draft,
    );
    addTearDown(restored.dispose);
    expect(restored.fills, {'region-1': 'paint-1'});
    expect(restored.strokes, isEmpty);
    expect(restored.canFinish, isTrue);
  });

  test('public views and serialized data do not mutate the document', () {
    final document = RasterColorDocument(
      spec: _spec(),
      ageBand: AgeBand.primary,
    );
    addTearDown(document.dispose);
    document.fillRegion('region-1');
    expect(
      () => document.fills['region-2'] = 'paint-2',
      throwsUnsupportedError,
    );
    expect(() => document.strokes.clear(), throwsUnsupportedError);
    final data = document.toJson();
    (data['fills'] as Map)['region-2'] = 'paint-2';
    expect(document.completedCount, 1);
  });

  test('changed metadata cannot reuse completion from the same image', () {
    final spec = _spec();
    final firstDigest = List.filled(64, '1').join();
    final secondDigest = List.filled(64, '2').join();
    final first = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.preschool,
      specSha256: firstDigest,
    );
    addTearDown(first.dispose);
    for (final region in spec.regionsFor(AgeBand.preschool)) {
      first.selectPalette(region.paletteId);
      first.fillRegion(region.id);
    }
    expect(first.canFinish, isTrue);
    final restored = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.preschool,
      specSha256: secondDigest,
      initialData: first.toJson(),
    );
    addTearDown(restored.dispose);
    expect(restored.fills, isEmpty);
    expect(restored.canFinish, isFalse);
  });

  test('a 22000-point drawing saves every stroke within the shared budget', () {
    final spec = _spec();
    final document = RasterColorDocument(spec: spec, ageBand: AgeBand.primary);
    addTearDown(document.dispose);
    document.setCreative(true);
    for (var stroke = 0; stroke < 20; stroke++) {
      document.beginStroke(Offset(.05, .1 + stroke * .03));
      for (var i = 1; i < 1100; i++) {
        document.appendStroke(
          Offset(
            .05 + .8 * i / 1099,
            .1 + stroke * .03 + math.sin(i * .1) * .015,
          ),
        );
      }
      document.endStroke();
    }
    expect(document.strokes, hasLength(20));
    expect(
      document.totalPointCount,
      lessThanOrEqualTo(ArtworkLimits.maxTotalBrushPoints),
    );
    expect(
      document.strokes.every(
        (stroke) => stroke.points.length <= ArtworkLimits.maxPointsPerStroke,
      ),
      isTrue,
    );
    expect(document.strokes.last.points.last.dx, closeTo(.85, 1e-8));
    final data = document.toJson();
    expect(
      utf8.encode(jsonEncode(data)).length,
      lessThan(ArtworkLimits.maxArtworkBytes),
    );
    final restored = RasterColorDocument(
      spec: spec,
      ageBand: AgeBand.primary,
      initialData: data,
    );
    addTearDown(restored.dispose);
    expect(restored.strokes, hasLength(20));
    expect(restored.totalPointCount, document.totalPointCount);
    expect(restored.strokes.last.points.last.dx, closeTo(.85, .0001));
    expect(restored.canFinish, isTrue);
  });
}
