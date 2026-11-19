import 'package:flutter/material.dart';

import 'art_scene.dart';

class SceneIllustration extends StatelessWidget {
  const SceneIllustration({
    super.key,
    required this.scene,
    this.size,
    this.colored = true,
    this.variant = 0,
    this.subjectOnly = false,
  });
  final String scene;
  final double? size;
  final bool colored;
  final int variant;
  final bool subjectOnly;
  @override
  Widget build(BuildContext context) {
    final artwork = SceneFactory.create(scene, variant: variant);
    final illustration = subjectOnly
        ? ArtScene(
            regions: artwork.regions
                .where((r) => r.group == 'subject')
                .toList(),
            details: artwork.drawingDetails,
            viewBox: artwork.viewBox,
          )
        : artwork;
    return SizedBox.square(
      dimension: size,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: ArtScenePainter(scene: illustration, colored: colored),
        ),
      ),
    );
  }
}
