import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/legacy_catalog.dart';
import 'package:tiny_trails/shared/art/art_scene.dart';
import 'package:tiny_trails/shared/widgets/lesson_illustration.dart';

const _lessonAssets = <String>[
  '01-toybox.png',
  '02-zebra.png',
  '03-crocodile.png',
  '04-shoes.png',
  '05-balloons.png',
  '06-puppy.png',
  '07-kites.png',
  '08-school.png',
  '09-duck.png',
  '10-reef.png',
  '11-garden.png',
  '12-robot.png',
  '13-rocket.png',
  '14-picnic.png',
  '15-growth.png',
  '16-fox.png',
  '17-river.png',
  '18-park.png',
  '19-cat.png',
  '20-forest.png',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('The 20 curated lessons each route to their own authored bitmap', () {
    expect(contentVersion, 2);
    expect(levels, hasLength(20));
    final expectedAssets = [
      for (final filename in _lessonAssets) 'assets/images/levels/$filename',
    ];
    expect(
      levels.map((level) => level.illustrationAsset),
      orderedEquals(expectedAssets),
    );
    expect(
      levels.map((level) => level.illustrationAsset).toSet(),
      hasLength(20),
    );
    final shippedPngs = Directory('assets/images/levels')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(shippedPngs, _lessonAssets.toSet());
  });

  test(
    'All authored lesson assets decode at their reviewed source size',
    () async {
      for (final filename in _lessonAssets) {
        final path = 'assets/images/levels/$filename';
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          expect(codec.frameCount, 1, reason: path);
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, 1254, reason: path);
            expect(frame.image.height, 1254, reason: path);
            final rgba = await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            expect(rgba, isNotNull, reason: path);
            // A valid but blank replacement is still a broken lesson asset.
            final pixels = rgba!.buffer.asUint8List(
              rgba.offsetInBytes,
              rgba.lengthInBytes,
            );
            final sampledColors = <int>{};
            for (
              var pixel = 0;
              pixel < frame.image.width * frame.image.height;
              pixel += 997
            ) {
              final offset = pixel * 4;
              sampledColors.add(
                (pixels[offset] << 16) |
                    (pixels[offset + 1] << 8) |
                    pixels[offset + 2],
              );
            }
            expect(sampledColors.length, greaterThan(32), reason: path);
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
    },
  );

  testWidgets(
    'LessonIllustration uses each bitmap, including legacy scene names',
    (tester) async {
      for (final level in levels) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.square(
                dimension: 240,
                child: LessonIllustration(level: level),
              ),
            ),
          ),
        );
        final images = tester.widgetList<Image>(find.byType(Image));
        expect(images, hasLength(1), reason: level.id);
        final provider = images.single.image;
        expect(provider, isA<ResizeImage>(), reason: level.id);
        final original = (provider as ResizeImage).imageProvider;
        expect(original, isA<AssetImage>(), reason: level.id);
        expect(
          (original as AssetImage).assetName,
          level.illustrationAsset,
          reason: level.id,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  test('Fini has real transparent pixels and a substantial visible character', () async {
    final data = await rootBundle.load('assets/images/fini.png');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // PNG colour type6 carries actual RGBA data; an RGB checkerboard does not.
    expect(bytes[25], 6);
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      expect(codec.frameCount, 1);
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 1254);
        expect(frame.image.height, 1254);
        final data = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rgba = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        var transparent = 0;
        var solidCharacter = 0;
        for (var offset = 3; offset < rgba.length; offset += 4) {
          if (rgba[offset] == 0) transparent++;
          if (rgba[offset] >= 240) solidCharacter++;
        }
        final pixels = frame.image.width * frame.image.height;
        expect(transparent / pixels, greaterThan(.20));
        expect(solidCharacter / pixels, greaterThan(.20));
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });

  test('Unknown raster scene names cannot silently render a vector fox', () {
    for (final scene in ['toybox', 'shapeGarden', 'zebra', 'missing-scene']) {
      expect(
        () => SceneFactory.create(scene),
        throwsArgumentError,
        reason: scene,
      );
      expect(
        () => SceneFactory.create(scene, geometric: true),
        throwsArgumentError,
        reason: scene,
      );
    }
    for (final level in legacyLevels) {
      expect(SceneFactory.sceneNames, contains(level.scene), reason: level.id);
    }
    for (final scene in legacyLevels.map((level) => level.scene).toSet()) {
      expect(() => SceneFactory.create(scene), returnsNormally, reason: scene);
    }
  });

  test(
    'Legacy semantic numbering preserves source colours and saved fill IDs',
    () {
      final original = SceneFactory.create('fox', segmented: true);
      final fox = original.withSemanticNumbers();
      final palette = fox.numberPalette;
      expect(
        palette.keys,
        orderedEquals(List.generate(palette.length, (i) => i + 1)),
      );
      for (final region in fox.regions) {
        expect(palette[region.number], region.color, reason: region.id);
      }
      final head = fox.regions.firstWhere(
        (region) => region.id.startsWith('head_'),
      );
      expect(palette[head.number], const Color(0xFFFF9B7D));
      expect(
        fox.regions.map((region) => region.id),
        orderedEquals(original.regions.map((region) => region.id)),
      );
      expect(
        fox.regions.map((region) => region.path),
        orderedEquals(original.regions.map((region) => region.path)),
      );
    },
  );

  test(
    'Legacy ambiguous colour numbers are rejected instead of recoloured',
    () {
      final original = SceneFactory.create('fox');
      expect(() => original.numberPalette, throwsStateError);
      expect(
        () => original.withSemanticNumbers().numberPalette,
        returnsNormally,
      );
    },
  );
}
