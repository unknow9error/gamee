import 'dart:convert';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'raster_color_spec.dart';

/// One owner gets one image handle. The decoded source remains shared and the
/// painting document never mutates or regenerates the original illustration.
class LoadedColorScene {
  const LoadedColorScene(this.spec, this.image, this.specSha256);
  final ColorSceneSpec spec;
  final ui.Image image;
  final String specSha256;
  void dispose() => image.dispose();
}

class ColorSceneAssets {
  static final Map<(AssetBundle, String), Future<LoadedColorScene>> _cache = {};

  static Future<LoadedColorScene> load(
    String specAsset, {
    String? expectedIllustrationAsset,
    AssetBundle? bundle,
  }) async {
    final source = bundle ?? rootBundle;
    if (!RegExp(r'^assets/content/color-[a-z0-9-]+\.json$')
        .hasMatch(specAsset)) {
      throw const FormatException('Invalid coloring content path');
    }
    final key = (source, specAsset);
    final pending = _cache.putIfAbsent(key, () => _decode(source, specAsset));
    late LoadedColorScene scene;
    try {
      scene = await pending;
    } catch (_) {
      if (identical(_cache[key], pending)) _cache.remove(key);
      rethrow;
    }
    if (expectedIllustrationAsset != null &&
        scene.spec.asset != expectedIllustrationAsset) {
      throw const FormatException('Coloring picture does not match its lesson');
    }
    return LoadedColorScene(scene.spec, scene.image.clone(), scene.specSha256);
  }

  static Future<LoadedColorScene> _decode(
    AssetBundle bundle,
    String specAsset,
  ) async {
    final specData = await bundle.load(specAsset);
    final specBytes = specData.buffer.asUint8List(
      specData.offsetInBytes,
      specData.lengthInBytes,
    );
    final decoded = jsonDecode(utf8.decode(specBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid coloring content');
    }
    final spec = ColorSceneSpec.fromJson(decoded);
    final imageData = await bundle.load(spec.asset);
    final bytes = imageData.buffer.asUint8List(
      imageData.offsetInBytes,
      imageData.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != spec.assetSha256) {
      throw const FormatException('Coloring illustration version mismatch');
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final image = (await codec.getNextFrame()).image;
      if (image.width != spec.imageWidth || image.height != spec.imageHeight) {
        image.dispose();
        throw const FormatException('Coloring illustration size mismatch');
      }
      return LoadedColorScene(
        spec,
        image,
        sha256.convert(specBytes).toString(),
      );
    } finally {
      codec.dispose();
    }
  }
}
