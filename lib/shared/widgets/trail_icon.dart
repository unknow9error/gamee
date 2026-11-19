import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Little ink-and-watercolor drawings, shared by navigation and play tools.
enum TrailIconKind {
  adventures,
  studio,
  rewards,
  fox,
  star,
  leaf,
  calendar,
  check,
  brush,
  palette,
  maze,
  draw,
  search,
  dots,
  pairs,
  pattern,
  puzzle,
  rope,
  sparkles,
  album,
  rest,
  hint,
  settings,
  speaker,
  offline,
  heart,
}

/// The enclosing button or label owns semantics, just as it owns interaction.
/// [color] provides a single-ink version for controls on a colored surface.
class TrailIcon extends StatelessWidget {
  const TrailIcon(
    this.kind, {
    super.key,
    this.size = 28,
    this.selected = false,
    this.color,
  });

  final TrailIconKind kind;
  final double size;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TrailIconPainter(
          kind: kind,
          selected: selected,
          color: color,
        ),
      ),
    ),
  );
}

class _TrailIconPainter extends CustomPainter {
  const _TrailIconPainter({
    required this.kind,
    required this.selected,
    required this.color,
  });

  final TrailIconKind kind;
  final bool selected;
  final Color? color;

  Color get ink => color ?? AppColors.ink;

  Color wash(Color pigment) => color == null
      ? Color.lerp(pigment, AppColors.paper, selected ? 0 : .13)!
      : color!.withValues(alpha: .18);

  Paint get pen => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.65
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void shape(Canvas canvas, Path path, Color pigment, {bool outline = true}) {
    canvas.drawPath(path, Paint()..color = wash(pigment));
    if (outline) canvas.drawPath(path, pen);
  }

  void line(Canvas canvas, Path path, {Color? pigment, double width = 1.65}) {
    canvas.drawPath(
      path,
      pen
        ..color = pigment ?? ink
        ..strokeWidth = width,
    );
  }

  void dot(Canvas canvas, double x, double y, double radius, Color pigment) {
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = wash(pigment));
    canvas.drawCircle(Offset(x, y), radius, pen);
  }

  Path roundedStar(double x, double y, double radius) {
    final points = List<Offset>.generate(10, (index) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final length = index.isEven ? radius : radius * .48;
      return Offset(x + math.cos(angle) * length, y + math.sin(angle) * length);
    });
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index + 9) % 10];
      final current = points[index];
      final next = points[(index + 1) % 10];
      final before = Offset.lerp(current, previous, .18)!;
      final after = Offset.lerp(current, next, .18)!;
      if (index == 0) {
        path.moveTo(before.dx, before.dy);
      } else {
        path.lineTo(before.dx, before.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, after.dx, after.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    switch (kind) {
      case TrailIconKind.adventures:
        _map(canvas);
      case TrailIconKind.studio:
      case TrailIconKind.palette:
        _palette(canvas);
      case TrailIconKind.rewards:
        _rosette(canvas);
      case TrailIconKind.fox:
        _fox(canvas);
      case TrailIconKind.star:
        shape(canvas, roundedStar(16, 16, 13), AppColors.yellow);
        line(
          canvas,
          Path()
            ..moveTo(11, 14)
            ..lineTo(13, 10),
          width: 1.4,
        );
      case TrailIconKind.leaf:
        _leaf(canvas);
      case TrailIconKind.calendar:
        _calendar(canvas);
      case TrailIconKind.check:
        shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(4, 4, 24, 24),
              const Radius.circular(10),
            ),
          ),
          AppColors.lime,
        );
        line(
          canvas,
          Path()
            ..moveTo(9.5, 16)
            ..lineTo(14, 20.5)
            ..lineTo(23, 11),
          width: 2.1,
        );
      case TrailIconKind.brush:
        _brush(canvas);
      case TrailIconKind.maze:
        _maze(canvas);
      case TrailIconKind.draw:
        _draw(canvas);
      case TrailIconKind.search:
        _search(canvas);
      case TrailIconKind.dots:
        _dots(canvas);
      case TrailIconKind.pairs:
        _pairs(canvas);
      case TrailIconKind.pattern:
        _pattern(canvas);
      case TrailIconKind.puzzle:
        _puzzle(canvas);
      case TrailIconKind.rope:
        _rope(canvas);
      case TrailIconKind.sparkles:
        _sparkle(canvas, 12, 13, 8, AppColors.yellow);
        _sparkle(canvas, 25, 23, 4, AppColors.peach);
        dot(canvas, 24, 6, 1.4, AppColors.lime);
      case TrailIconKind.album:
        _album(canvas);
      case TrailIconKind.rest:
        _rest(canvas);
      case TrailIconKind.hint:
        _hint(canvas);
      case TrailIconKind.settings:
        _settings(canvas);
      case TrailIconKind.speaker:
        _speaker(canvas);
      case TrailIconKind.offline:
        _offline(canvas);
      case TrailIconKind.heart:
        _heart(canvas);
    }
    canvas.restore();
  }

  void _map(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(3, 7)
        ..lineTo(11, 4)
        ..lineTo(21, 7)
        ..lineTo(29, 4)
        ..lineTo(28, 25)
        ..lineTo(20, 28)
        ..lineTo(11, 25)
        ..lineTo(3, 28)
        ..close(),
      AppColors.lime,
    );
    shape(
      canvas,
      Path()
        ..moveTo(11, 4)
        ..lineTo(21, 7)
        ..lineTo(20, 28)
        ..lineTo(11, 25)
        ..close(),
      AppColors.paper,
    );
    line(
      canvas,
      Path()
        ..moveTo(7, 22)
        ..cubicTo(4, 15, 18, 22, 17, 14)
        ..cubicTo(16, 9, 25, 15, 25, 10),
      pigment: color ?? AppColors.green,
      width: 1.9,
    );
    dot(canvas, 7, 22, 2, AppColors.peach);
    dot(canvas, 25, 10, 2, AppColors.yellow);
  }

  void _palette(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(16, 4)
        ..cubicTo(8, 3, 3, 9, 3, 16)
        ..cubicTo(3, 24, 9, 29, 16, 28)
        ..cubicTo(20, 27, 16, 23, 20, 21)
        ..cubicTo(24, 19, 29, 22, 29, 16)
        ..cubicTo(29, 9, 23, 4, 16, 4)
        ..close(),
      AppColors.peach,
    );
    dot(canvas, 9, 13, 2.2, AppColors.lavender);
    dot(canvas, 15, 9, 2.1, AppColors.yellow);
    dot(canvas, 23, 12, 2.2, AppColors.blue);
    dot(canvas, 9, 21, 2, AppColors.lime);
    canvas.drawOval(const Rect.fromLTWH(15, 16, 4, 5), Paint()..color = ink);
  }

  void _rosette(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(9, 19)
        ..lineTo(6, 29)
        ..lineTo(12, 26)
        ..lineTo(15, 29)
        ..lineTo(18, 20)
        ..close(),
      AppColors.lavender,
    );
    shape(
      canvas,
      Path()
        ..moveTo(19, 19)
        ..lineTo(22, 29)
        ..lineTo(24, 25)
        ..lineTo(29, 26)
        ..lineTo(25, 17)
        ..close(),
      AppColors.peach,
    );
    final badge = Path();
    for (var i = 0; i < 24; i++) {
      final angle = -math.pi / 2 + i * math.pi / 12;
      final radius = i.isEven ? 11.8 : 10.4;
      final x = 16 + math.cos(angle) * radius;
      final y = 13 + math.sin(angle) * radius;
      if (i == 0) {
        badge.moveTo(x, y);
      } else {
        badge.lineTo(x, y);
      }
    }
    shape(canvas, badge..close(), AppColors.yellow);
    shape(canvas, roundedStar(16, 13, 6), AppColors.paper);
  }

  void _fox(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(5, 16)
        ..quadraticBezierTo(2, 9, 5, 3)
        ..quadraticBezierTo(11, 5, 13, 10)
        ..quadraticBezierTo(16, 8, 20, 10)
        ..quadraticBezierTo(24, 4, 28, 3)
        ..quadraticBezierTo(30, 10, 27, 16)
        ..quadraticBezierTo(26, 25, 16, 29)
        ..quadraticBezierTo(6, 25, 5, 16)
        ..close(),
      const Color(0xFFED9C69),
    );
    shape(
      canvas,
      Path()
        ..moveTo(6, 16)
        ..quadraticBezierTo(12, 15, 16, 21)
        ..quadraticBezierTo(20, 15, 26, 16)
        ..quadraticBezierTo(25, 24, 16, 28)
        ..quadraticBezierTo(7, 24, 6, 16)
        ..close(),
      AppColors.paper,
      outline: false,
    );
    line(
      canvas,
      Path()
        ..moveTo(6.5, 7)
        ..lineTo(9, 12)
        ..moveTo(25.5, 7)
        ..lineTo(23, 12),
      pigment: color ?? const Color(0xFFAE6549),
    );
    canvas.drawCircle(const Offset(11, 18), 1.1, Paint()..color = ink);
    canvas.drawCircle(const Offset(21, 18), 1.1, Paint()..color = ink);
    shape(
      canvas,
      Path()
        ..moveTo(13.6, 23)
        ..quadraticBezierTo(16, 21.9, 18.4, 23)
        ..quadraticBezierTo(16, 26.1, 13.6, 23)
        ..close(),
      ink,
      outline: false,
    );
  }

  void _leaf(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(16, 27)
        ..cubicTo(1, 23, 4, 12, 5, 7)
        ..cubicTo(14, 8, 18, 12, 16, 22)
        ..cubicTo(15, 10, 22, 5, 29, 4)
        ..cubicTo(30, 16, 26, 22, 16, 24)
        ..close(),
      AppColors.lime,
    );
    line(
      canvas,
      Path()
        ..moveTo(16, 29)
        ..quadraticBezierTo(17, 19, 24, 11)
        ..moveTo(16, 24)
        ..quadraticBezierTo(12, 19, 10, 14),
    );
  }

  void _calendar(Canvas canvas) {
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 6, 24, 23),
          const Radius.circular(5),
        ),
      ),
      AppColors.paper,
    );
    shape(
      canvas,
      Path()
        ..moveTo(4, 13)
        ..lineTo(4, 10)
        ..quadraticBezierTo(4, 6, 9, 6)
        ..lineTo(23, 6)
        ..quadraticBezierTo(28, 6, 28, 10)
        ..lineTo(28, 13)
        ..close(),
      AppColors.blue,
    );
    line(
      canvas,
      Path()
        ..moveTo(10, 3)
        ..lineTo(10, 9)
        ..moveTo(22, 3)
        ..lineTo(22, 9),
    );
    shape(canvas, roundedStar(16, 21, 6), AppColors.yellow);
  }

  void _brush(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(12, 18)
        ..lineTo(23, 4)
        ..quadraticBezierTo(26, 1, 28, 4)
        ..quadraticBezierTo(29, 5, 27, 8)
        ..lineTo(17, 22)
        ..close(),
      AppColors.lavender,
    );
    line(
      canvas,
      Path()
        ..moveTo(12, 18)
        ..lineTo(17, 22)
        ..moveTo(15, 14)
        ..lineTo(21, 18),
    );
    shape(
      canvas,
      Path()
        ..moveTo(12, 19)
        ..cubicTo(4, 17, 8, 27, 3, 28)
        ..cubicTo(10, 30, 18, 27, 17, 22)
        ..close(),
      AppColors.peach,
    );
  }

  void _maze(Canvas canvas) {
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 3, 26, 26),
          const Radius.circular(5),
        ),
      ),
      AppColors.lime,
    );
    line(
      canvas,
      Path()
        ..moveTo(4, 10)
        ..lineTo(11, 10)
        ..lineTo(11, 22)
        ..lineTo(22, 22)
        ..lineTo(22, 16)
        ..lineTo(17, 16)
        ..lineTo(17, 8)
        ..lineTo(28, 8),
    );
    line(
      canvas,
      Path()
        ..moveTo(5, 25)
        ..lineTo(7, 25)
        ..moveTo(5, 17)
        ..lineTo(7, 17)
        ..moveTo(24, 12)
        ..lineTo(27, 12),
      pigment: color ?? AppColors.green,
      width: 2,
    );
    dot(canvas, 7, 6.5, 1.4, AppColors.peach);
    dot(canvas, 25, 26, 1.4, AppColors.yellow);
  }

  void _draw(Canvas canvas) {
    line(
      canvas,
      Path()
        ..moveTo(3, 27)
        ..cubicTo(1, 21, 13, 22, 10, 27)
        ..cubicTo(9, 30, 18, 29, 19, 26),
      pigment: color ?? AppColors.green,
    );
    shape(
      canvas,
      Path()
        ..moveTo(12, 23)
        ..lineTo(14, 15)
        ..lineTo(25, 3)
        ..quadraticBezierTo(27, 2, 29, 5)
        ..lineTo(18, 18)
        ..close(),
      AppColors.yellow,
    );
    line(
      canvas,
      Path()
        ..moveTo(14, 15)
        ..lineTo(18, 18)
        ..moveTo(22, 6)
        ..lineTo(26, 10)
        ..moveTo(12, 23)
        ..lineTo(15, 20),
    );
  }

  void _search(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(21, 21)
        ..quadraticBezierTo(23, 19, 25, 22)
        ..lineTo(29, 27)
        ..quadraticBezierTo(29, 29, 27, 29)
        ..lineTo(21, 24)
        ..close(),
      AppColors.peach,
    );
    dot(canvas, 13.5, 13.5, 10, AppColors.blue);
    shape(
      canvas,
      Path()
        ..moveTo(14, 18)
        ..quadraticBezierTo(5, 14, 10, 9)
        ..quadraticBezierTo(15, 9, 14, 18)
        ..quadraticBezierTo(13, 10, 19, 10)
        ..quadraticBezierTo(21, 16, 14, 18)
        ..close(),
      AppColors.lime,
    );
  }

  void _dots(Canvas canvas) {
    line(
      canvas,
      Path()
        ..moveTo(6, 25)
        ..lineTo(15, 8)
        ..lineTo(27, 22),
      pigment: color ?? AppColors.green,
      width: 2.2,
    );
    dot(canvas, 6, 25, 3.8, AppColors.peach);
    dot(canvas, 15, 8, 3.8, AppColors.yellow);
    dot(canvas, 27, 22, 3.8, AppColors.blue);
  }

  void _pairs(Canvas canvas) {
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 4, 17, 22),
          const Radius.circular(4),
        ),
      ),
      AppColors.lavender,
    );
    canvas.save();
    canvas.translate(19, 17);
    canvas.rotate(.15);
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8.5, -11, 17, 22),
          const Radius.circular(4),
        ),
      ),
      AppColors.paper,
    );
    shape(canvas, roundedStar(0, 0, 5.7), AppColors.yellow);
    canvas.restore();
    line(
      canvas,
      Path()
        ..moveTo(7, 9)
        ..lineTo(10, 9)
        ..moveTo(7, 13)
        ..lineTo(9, 13),
    );
  }

  void _pattern(Canvas canvas) {
    dot(canvas, 8, 9, 4.7, AppColors.peach);
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 4, 9, 9),
          const Radius.circular(2),
        ),
      ),
      AppColors.lime,
    );
    shape(
      canvas,
      Path()
        ..moveTo(8, 18)
        ..lineTo(14, 28)
        ..lineTo(2, 28)
        ..close(),
      AppColors.yellow,
    );
    dot(canvas, 24, 24, 4.7, AppColors.lavender);
    line(
      canvas,
      Path()
        ..moveTo(15, 9)
        ..lineTo(17, 9)
        ..moveTo(17, 23)
        ..lineTo(16, 23),
      width: 1.3,
    );
  }

  void _puzzle(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(5, 5)
        ..lineTo(13, 5)
        ..cubicTo(11, 0, 21, 0, 19, 5)
        ..lineTo(27, 5)
        ..lineTo(27, 13)
        ..cubicTo(22, 11, 22, 21, 27, 19)
        ..lineTo(27, 27)
        ..lineTo(19, 27)
        ..cubicTo(21, 22, 11, 22, 13, 27)
        ..lineTo(5, 27)
        ..lineTo(5, 19)
        ..cubicTo(0, 21, 0, 11, 5, 13)
        ..close(),
      AppColors.lavender,
    );
    shape(canvas, roundedStar(16, 16, 5), AppColors.paper);
  }

  void _rope(Canvas canvas) {
    final rope = Path()
      ..moveTo(4, 23)
      ..cubicTo(9, 30, 27, 30, 27, 17)
      ..cubicTo(27, 6, 12, 4, 10, 13)
      ..cubicTo(8, 22, 22, 25, 22, 14)
      ..cubicTo(22, 5, 9, 4, 5, 8);
    line(canvas, rope, pigment: color ?? const Color(0xFFBA754B), width: 4);
    line(canvas, rope, pigment: color ?? AppColors.peach, width: 2);
    dot(canvas, 5, 8, 2.4, AppColors.lime);
    dot(canvas, 4, 23, 2.4, AppColors.yellow);
  }

  void _sparkle(Canvas canvas, double x, double y, double r, Color pigment) {
    shape(
      canvas,
      Path()
        ..moveTo(x, y - r)
        ..quadraticBezierTo(x + 1, y - 1, x + r, y)
        ..quadraticBezierTo(x + 1, y + 1, x, y + r)
        ..quadraticBezierTo(x - 1, y + 1, x - r, y)
        ..quadraticBezierTo(x - 1, y - 1, x, y - r)
        ..close(),
      pigment,
    );
  }

  void _album(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(3, 5)
        ..quadraticBezierTo(10, 2, 16, 7)
        ..quadraticBezierTo(22, 2, 29, 5)
        ..lineTo(29, 27)
        ..quadraticBezierTo(22, 24, 16, 28)
        ..quadraticBezierTo(9, 24, 3, 27)
        ..close(),
      AppColors.paper,
    );
    shape(
      canvas,
      Path()
        ..moveTo(16, 7)
        ..quadraticBezierTo(22, 2, 29, 5)
        ..lineTo(29, 27)
        ..quadraticBezierTo(22, 24, 16, 28)
        ..close(),
      AppColors.blue,
    );
    line(
      canvas,
      Path()
        ..moveTo(7, 20)
        ..lineTo(12, 20)
        ..moveTo(7, 23)
        ..lineTo(10, 23),
    );
    shape(canvas, roundedStar(9.5, 12, 4), AppColors.yellow);
    shape(
      canvas,
      Path()
        ..moveTo(19, 20)
        ..lineTo(22, 14)
        ..lineTo(25, 19)
        ..lineTo(27, 17),
      AppColors.lime,
    );
  }

  void _rest(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(19, 3)
        ..cubicTo(2, 0, 0, 24, 16, 28)
        ..quadraticBezierTo(25, 30, 29, 21)
        ..cubicTo(12, 27, 9, 11, 19, 3)
        ..close(),
      AppColors.yellow,
    );
    line(
      canvas,
      Path()
        ..moveTo(7, 17)
        ..quadraticBezierTo(9, 19, 11, 17),
    );
    _sparkle(canvas, 25, 8, 4, AppColors.lavender);
  }

  void _hint(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(11, 23)
        ..cubicTo(11, 18, 6, 18, 6, 12)
        ..cubicTo(6, 0, 26, 0, 26, 12)
        ..cubicTo(26, 18, 21, 18, 21, 23)
        ..close(),
      AppColors.yellow,
    );
    line(
      canvas,
      Path()
        ..moveTo(12, 27)
        ..lineTo(20, 27)
        ..moveTo(14, 30)
        ..lineTo(18, 30)
        ..moveTo(16, 22)
        ..lineTo(16, 16)
        ..lineTo(12, 13)
        ..moveTo(16, 16)
        ..lineTo(20, 13),
    );
  }

  void _settings(Canvas canvas) {
    final gear = Path();
    for (var i = 0; i < 48; i++) {
      final angle = -math.pi / 2 + i * math.pi / 24;
      final radius = (i % 6 == 0 || i % 6 == 5) ? 10.2 : 13;
      final x = 16 + math.cos(angle) * radius;
      final y = 16 + math.sin(angle) * radius;
      if (i == 0) {
        gear.moveTo(x, y);
      } else {
        gear.lineTo(x, y);
      }
    }
    shape(canvas, gear..close(), AppColors.lavender);
    dot(canvas, 16, 16, 5.5, AppColors.paper);
    line(
      canvas,
      Path()
        ..moveTo(15, 18)
        ..quadraticBezierTo(12, 14, 18, 13)
        ..quadraticBezierTo(20, 17, 15, 18),
      width: 1.15,
    );
  }

  void _speaker(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(4, 12)
        ..lineTo(10, 12)
        ..lineTo(18, 6)
        ..lineTo(18, 26)
        ..lineTo(10, 20)
        ..lineTo(4, 20)
        ..quadraticBezierTo(2, 16, 4, 12)
        ..close(),
      AppColors.blue,
    );
    line(
      canvas,
      Path()
        ..moveTo(22, 11)
        ..quadraticBezierTo(27, 16, 22, 21)
        ..moveTo(26, 6)
        ..quadraticBezierTo(35, 16, 26, 26),
      pigment: color ?? AppColors.green,
    );
  }

  void _offline(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(8, 23)
        ..cubicTo(0, 23, 0, 12, 8, 12)
        ..cubicTo(9, 2, 25, 1, 26, 13)
        ..cubicTo(33, 13, 32, 23, 25, 23)
        ..close(),
      AppColors.blue,
    );
    shape(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 15, 13, 14),
          const Radius.circular(3),
        ),
      ),
      AppColors.paper,
    );
    line(
      canvas,
      Path()
        ..moveTo(14, 22)
        ..lineTo(16, 24)
        ..lineTo(20, 19),
      pigment: color ?? AppColors.green,
      width: 1.9,
    );
  }

  void _heart(Canvas canvas) {
    shape(
      canvas,
      Path()
        ..moveTo(16, 28)
        ..cubicTo(12, 25, 3, 19, 3, 11)
        ..cubicTo(3, 2, 14, 1, 16, 9)
        ..cubicTo(19, 1, 29, 3, 29, 11)
        ..cubicTo(29, 19, 20, 25, 16, 28)
        ..close(),
      AppColors.peach,
    );
    line(
      canvas,
      Path()
        ..moveTo(7, 12)
        ..quadraticBezierTo(7, 8, 10, 8),
      pigment: color ?? AppColors.paper,
      width: 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TrailIconPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.selected != selected ||
      oldDelegate.color != color;
}
