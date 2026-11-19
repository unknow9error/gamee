part of 'art_scene.dart';

/// Smooth workbook partitions continue through the scenery and subject. Small
/// fragments are kept with their parent instead of becoming frustrating taps.
ArtScene _numberScene(ArtScene artwork, int variant) {
  final vertical = Path()
    ..moveTo(0, 0)
    ..lineTo(155 + variant * 13.0, 0)
    ..cubicTo(230, 93, 134, 173, 214, 256)
    ..cubicTo(259, 310, 200, 350, 225, 400)
    ..lineTo(0, 400)
    ..close();
  final horizontal = Path()
    ..moveTo(0, 0)
    ..lineTo(400, 0)
    ..lineTo(400, 205 + variant * 12.0)
    ..cubicTo(310, 163, 277, 249, 194, 217)
    ..cubicTo(116, 185, 60, 258, 0, 217)
    ..close();
  final diagonal = Path()
    ..moveTo(0, 0)
    ..lineTo(400, 0)
    ..lineTo(400, 335)
    ..cubicTo(255, 324, 156, 122, 0, 137)
    ..close();
  final cuts = [
    vertical,
    if (variant >= 1) horizontal,
    if (variant >= 3) diagonal,
  ];
  final regions = <ArtRegion>[];
  for (var i = 0; i < artwork.regions.length; i++) {
    final region = artwork.regions[i];
    var exposed = region.path;
    for (final later in artwork.regions.skip(i + 1)) {
      exposed = Path.combine(PathOperation.difference, exposed, later.path);
    }
    var parts = [exposed];
    for (final cut in cuts) {
      final next = <Path>[];
      for (final part in parts) {
        final bounds = part.getBounds();
        if (bounds.width * bounds.height < 4500) {
          next.add(part);
          continue;
        }
        final first = Path.combine(PathOperation.intersect, part, cut);
        final second = Path.combine(PathOperation.difference, part, cut);
        if (_estimatedArea(first) >= 850 && _estimatedArea(second) >= 850) {
          next.addAll([first, second]);
        } else {
          next.add(part);
        }
      }
      parts = next;
    }
    for (var j = 0; j < parts.length; j++) {
      regions.add(
        ArtRegion(
          id: '${region.id}_$j',
          path: parts[j],
          color: region.color,
          labelPoint: region.labelPoint,
          number: parts.length == 1
              ? region.number
              : region.group == 'subject'
              ? 10 + (i + j) % 3
              : 6 + (i + j) % 4,
          group: region.group,
        ),
      );
    }
  }
  return ArtScene(
    regions: _placeLabels(regions, details: artwork.details, partitioned: true),
    details: artwork.details,
    drawingDetails: artwork.drawingDetails,
    viewBox: artwork.viewBox,
  );
}

double _estimatedArea(Path path) {
  final bounds = path.getBounds();
  if (bounds.isEmpty) return 0;
  var samples = 0;
  for (var x = bounds.left + 3; x < bounds.right; x += 6) {
    for (var y = bounds.top + 3; y < bounds.bottom; y += 6) {
      if (path.contains(Offset(x, y))) samples++;
    }
  }
  return samples * 36.0;
}
