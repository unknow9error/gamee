part of 'art_scene.dart';

void _rocket(_Builder b) {
  b.region(
    'space',
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 376, 376),
        const Radius.circular(25),
      ),
    ),
    const Color(0xFFE8E2F3),
    330,
    180,
    subject: false,
  );
  b.region(
    'moon',
    Path()
      ..moveTo(86, 61)
      ..cubicTo(43, 54, 37, 110, 75, 122)
      ..quadraticBezierTo(108, 131, 119, 103)
      ..cubicTo(85, 120, 66, 83, 86, 61)
      ..close(),
    _gold,
    65,
    91,
    subject: false,
  );
  b.region('planet', _oval(289, 270, 56, 56), _coral, 317, 296, subject: false);
  b.stroke(
    Path()
      ..moveTo(277, 313)
      ..cubicTo(312, 269, 363, 275, 352, 290)
      ..cubicTo(339, 308, 294, 326, 277, 313)
      ..close(),
    width: 2,
  );
  for (final o in [
    const Offset(140, 61),
    const Offset(316, 87),
    const Offset(54, 209),
    const Offset(285, 176),
    const Offset(85, 333),
  ]) {
    b.sparkle(o.dx, o.dy, 8 + b.variant.toDouble(), _gold);
  }
  b.region(
    'flameouter',
    Path()
      ..moveTo(174, 277)
      ..quadraticBezierTo(154, 320, 198, 363)
      ..quadraticBezierTo(244, 319, 227, 277)
      ..close(),
    _coral,
    200,
    320,
  );
  b.region(
    'flameinner',
    Path()
      ..moveTo(188, 279)
      ..quadraticBezierTo(174, 310, 200, 340)
      ..quadraticBezierTo(226, 309, 212, 279)
      ..close(),
    _gold,
    200,
    309,
  );
  b.region(
    'finleft',
    Path()
      ..moveTo(170, 213)
      ..quadraticBezierTo(129, 225, 121, 282)
      ..lineTo(170, 266)
      ..close(),
    _teal,
    147,
    254,
  );
  b.region(
    'finright',
    Path()
      ..moveTo(231, 212)
      ..quadraticBezierTo(271, 227, 280, 282)
      ..lineTo(231, 266)
      ..close(),
    _teal,
    255,
    253,
  );
  b.region(
    'body',
    Path()
      ..moveTo(200, 93)
      ..cubicTo(158, 130, 151, 214, 168, 276)
      ..lineTo(232, 276)
      ..cubicTo(250, 213, 244, 131, 200, 93)
      ..close(),
    _white,
    199,
    222,
  );
  b.region(
    'nose',
    Path()
      ..moveTo(200, 93)
      ..quadraticBezierTo(173, 117, 163, 157)
      ..quadraticBezierTo(200, 174, 238, 157)
      ..quadraticBezierTo(229, 119, 200, 93)
      ..close(),
    _coral,
    201,
    135,
  );
  b.region('windowrim', _oval(175, 177, 51, 51), _gold, 200, 201);
  b.region('window', _oval(183, 185, 35, 35), _blue, 200, 202);
  b.region(
    'base',
    Path()
      ..moveTo(165, 258)
      ..lineTo(235, 258)
      ..lineTo(232, 280)
      ..lineTo(168, 280)
      ..close(),
    _lavender,
    200,
    269,
  );
  b.stroke(
    Path()
      ..moveTo(190, 194)
      ..quadraticBezierTo(194, 188, 203, 189),
    color: _white,
    width: 3,
  );
  if (b.variant >= 2) {
    b.region(
      'smallplanet',
      _oval(274, 39, 24, 24),
      _teal,
      286,
      51,
      subject: false,
    );
  }
}
