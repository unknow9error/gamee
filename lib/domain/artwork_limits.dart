/// One shared budget for input engines and persistent artwork. Coordinates are
/// normalized; reducing redundant samples does not discard complete strokes.
abstract final class ArtworkLimits {
  static const maxArtworkBytes = 384 * 1024;
  static const maxArtworkNodes = 120000;
  static const maxBrushStrokes = 240;
  static const maxTotalBrushPoints = 6000;
  static const maxPointsPerStroke = 400;
}
