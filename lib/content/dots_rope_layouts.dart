import 'dart:math' as math;
import 'dart:ui';

import '../domain/models.dart';

/// Hand-annotated against the final 1254px ImageGen masters (November 17, 2026).
/// All coordinates are normalized to the complete square image, including its
/// margins. Never crop the image independently from these input targets.
class DotsLayout {
  DotsLayout({
    required this.id,
    required this.asset,
    required this.outline,
    required this.band,
    required this.labelStep,
  }) {
    final count = switch (band) {
      AgeBand.preschool => 12,
      AgeBand.primary => 20,
      AgeBand.advanced => 30,
    };
    final metric = outline.computeMetrics().single;
    points = List.unmodifiable(
      List.generate(
        count,
        (index) =>
            metric.getTangentForOffset(metric.length * index / count)!.position,
      ),
    );
  }
  final String id;
  final String asset;
  final Path outline;
  final AgeBand band;
  final int labelStep;
  late final List<Offset> points;
  String get revision => '$id-master-1-${band.name}';
  int label(int index) => (index + 1) * labelStep;

  factory DotsLayout.forLevel(LevelDefinition level, AgeBand band) {
    final rocket = level.id.contains('13') || level.scene == 'rocket';
    return DotsLayout(
      id: level.id,
      asset:
          level.illustrationAsset ??
          'assets/images/levels/${rocket ? '13-rocket' : '03-crocodile'}.png',
      band: band,
      labelStep: band == AgeBand.advanced ? (rocket ? 5 : 2) : 1,
      outline: rocket ? _rocketOutline() : _crocodileOutline(),
    );
  }
}

Path _rocketOutline() => Path()
  ..moveTo(.5, .044)
  ..cubicTo(.55, .042, .608, .15, .637, .23)
  ..cubicTo(.668, .32, .687, .401, .673, .48)
  ..cubicTo(.736, .527, .768, .655, .765, .785)
  ..quadraticBezierTo(.757, .823, .737, .783)
  ..quadraticBezierTo(.698, .705, .625, .675)
  ..lineTo(.608, .703)
  ..lineTo(.593, .754)
  ..quadraticBezierTo(.553, .768, .5, .758)
  ..quadraticBezierTo(.446, .768, .405, .754)
  ..lineTo(.391, .704)
  ..lineTo(.373, .674)
  ..quadraticBezierTo(.302, .704, .265, .783)
  ..quadraticBezierTo(.242, .824, .234, .785)
  ..cubicTo(.223, .66, .256, .529, .326, .48)
  ..cubicTo(.312, .392, .328, .307, .363, .227)
  ..cubicTo(.398, .143, .451, .055, .5, .044)
  ..close();

Path _crocodileOutline() => Path()
  ..moveTo(.929, .219)
  ..quadraticBezierTo(.932, .178, .89, .198)
  ..lineTo(.774, .248)
  ..quadraticBezierTo(.741, .197, .705, .222)
  ..quadraticBezierTo(.67, .233, .664, .256)
  ..quadraticBezierTo(.627, .238, .614, .282)
  ..quadraticBezierTo(.565, .304, .566, .36)
  ..quadraticBezierTo(.548, .393, .544, .438)
  ..quadraticBezierTo(.512, .438, .502, .461)
  ..quadraticBezierTo(.463, .421, .441, .467)
  ..quadraticBezierTo(.398, .446, .385, .478)
  ..quadraticBezierTo(.349, .463, .323, .499)
  ..quadraticBezierTo(.285, .485, .26, .516)
  ..quadraticBezierTo(.224, .515, .199, .496)
  ..quadraticBezierTo(.166, .468, .139, .494)
  ..quadraticBezierTo(.107, .478, .091, .493)
  ..cubicTo(.064, .435, .071, .384, .22, .36)
  ..cubicTo(.153, .326, .039, .369, .022, .471)
  ..cubicTo(.004, .594, .078, .658, .224, .672)
  ..quadraticBezierTo(.197, .7, .178, .727)
  ..quadraticBezierTo(.16, .763, .21, .757)
  ..lineTo(.274, .753)
  ..quadraticBezierTo(.307, .75, .292, .727)
  ..quadraticBezierTo(.331, .695, .347, .659)
  ..quadraticBezierTo(.401, .673, .492, .652)
  ..quadraticBezierTo(.484, .701, .479, .73)
  ..quadraticBezierTo(.474, .765, .538, .759)
  ..lineTo(.59, .754)
  ..quadraticBezierTo(.622, .746, .603, .724)
  ..lineTo(.562, .717)
  ..quadraticBezierTo(.62, .651, .647, .578)
  ..quadraticBezierTo(.68, .639, .71, .721)
  ..quadraticBezierTo(.719, .756, .756, .75)
  ..quadraticBezierTo(.783, .746, .757, .718)
  ..lineTo(.725, .7)
  ..lineTo(.686, .623)
  ..quadraticBezierTo(.688, .539, .71, .463)
  ..quadraticBezierTo(.727, .441, .772, .437)
  ..quadraticBezierTo(.844, .43, .842, .385)
  ..quadraticBezierTo(.775, .403, .751, .363)
  ..quadraticBezierTo(.735, .341, .719, .334)
  ..quadraticBezierTo(.812, .325, .929, .252)
  ..quadraticBezierTo(.943, .24, .929, .219)
  ..close();

class RopeRoute {
  RopeRoute({
    required this.id,
    required this.path,
    required this.color,
    required this.symbols,
    this.branches = const [],
  }) {
    final metric = path.computeMetrics().single;
    samples = List.unmodifiable(
      List.generate(
        161,
        (index) => metric
            .getTangentForOffset(
              math.min(metric.length - .000001, metric.length * index / 160),
            )!
            .position,
      ),
    );
  }
  final String id;
  final Path path;
  final Color color;
  final List<String> symbols;
  final List<Path> branches;
  late final List<Offset> samples;
}

class RopeLayout {
  const RopeLayout({
    required this.id,
    required this.asset,
    required this.band,
    required this.routes,
  });
  final String id;
  final String asset;
  final AgeBand band;
  final List<RopeRoute> routes;
  String get revision => '$id-master-1-${band.name}';

  factory RopeLayout.forLevel(LevelDefinition level, AgeBand band) {
    final river = level.id.contains('17') || level.scene == 'river';
    return RopeLayout(
      id: level.id,
      band: band,
      asset:
          level.illustrationAsset ??
          'assets/images/levels/${river ? '17-river' : '07-kites'}.png',
      routes: river ? _riverRoutes(band) : _kiteRoutes(band),
    );
  }
}

List<RopeRoute> _kiteRoutes(AgeBand band) => [
  RopeRoute(
    id: 'fox-red-kite',
    color: const Color(0xFFE38161),
    symbols: const ['star', 'leaf', 'flower'],
    path: Path()
      ..moveTo(.185, .741)
      ..cubicTo(.132, .652, .055, .566, .066, .449)
      ..cubicTo(.066, .369, .095, .279, .122, .218),
    branches: band == AgeBand.advanced
        ? [
            Path()
              ..moveTo(.068, .447)
              ..cubicTo(.31, .30, .61, .48, .901, .234),
          ]
        : const [],
  ),
  RopeRoute(
    id: 'rabbit-blue-kite',
    color: const Color(0xFF588C9C),
    symbols: const ['flower', 'star', 'leaf'],
    path: Path()
      ..moveTo(.812, .75)
      ..cubicTo(.853, .639, .932, .538, .926, .392)
      ..quadraticBezierTo(.925, .303, .9, .234),
    branches: band == AgeBand.advanced
        ? [
            Path()
              ..moveTo(.927, .403)
              ..cubicTo(.68, .29, .4, .47, .122, .218),
          ]
        : const [],
  ),
];

List<RopeRoute> _riverRoutes(AgeBand band) {
  final full = Path()
    ..moveTo(.617, .986)
    ..cubicTo(.70, .925, .83, .875, .90, .80)
    ..cubicTo(.97, .72, .973, .65, .895, .615)
    ..cubicTo(.81, .55, .67, .49, .58, .44)
    ..cubicTo(.45, .38, .56, .335, .607, .285)
    ..cubicTo(.65, .25, .51, .22, .46, .20)
    ..cubicTo(.409, .164, .505, .143, .55, .129);
  Path path = full;
  if (band == AgeBand.preschool) {
    final metric = full.computeMetrics().single;
    path = metric.extractPath(0, metric.length * .55);
  }
  return [
    RopeRoute(
      id: 'river-upstream',
      path: path,
      color: const Color(0xFF3B91A2),
      symbols: const ['leaf', 'star', 'flower'],
      branches: band == AgeBand.advanced
          ? [
              Path()
                ..moveTo(.895, .615)
                ..quadraticBezierTo(.945, .603, .957, .552),
            ]
          : const [],
    ),
  ];
}
