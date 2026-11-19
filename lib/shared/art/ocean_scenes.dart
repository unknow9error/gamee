part of 'art_scene.dart';

void _ocean(_Builder b) {
  b.region(
    'sky',
    Path()
      ..moveTo(12, 12)
      ..lineTo(388, 12)
      ..lineTo(388, 95)
      ..cubicTo(328, 122, 290, 75, 239, 98)
      ..cubicTo(160, 130, 92, 70, 12, 100)
      ..close(),
    const Color(0xFFE8F6FA),
    200,
    49,
    subject: false,
  );
  b.region(
    'water',
    Path()
      ..moveTo(12, 100)
      ..cubicTo(92, 70, 160, 130, 239, 98)
      ..cubicTo(290, 75, 328, 122, 388, 95)
      ..lineTo(388, 335)
      ..cubicTo(280, 312, 180, 372, 12, 332)
      ..close(),
    const Color(0xFFD5EDF5),
    360,
    210,
    subject: false,
  );
  b.region(
    'sand',
    Path()
      ..moveTo(12, 332)
      ..cubicTo(180, 372, 280, 312, 388, 335)
      ..lineTo(388, 388)
      ..lineTo(12, 388)
      ..close(),
    const Color(0xFFF8E6C5),
    225,
    366,
    subject: false,
  );
  b.region(
    'wave',
    Path()
      ..moveTo(25, 91)
      ..cubicTo(39, 75, 52, 73, 54, 85)
      ..cubicTo(55, 95, 42, 102, 42, 90)
      ..cubicTo(49, 95, 47, 79, 38, 89)
      ..close(),
    _teal,
    38,
    88,
    subject: false,
  );
  b.region(
    'bubble1',
    _oval(300, 119, 21, 21),
    _white,
    310,
    130,
    subject: false,
  );
  b.region('bubble2', _oval(328, 81, 15, 15), _white, 335, 88, subject: false);
  b.region(
    'coral',
    Path()
      ..moveTo(43, 351)
      ..cubicTo(40, 323, 24, 321, 26, 303)
      ..cubicTo(32, 297, 37, 309, 38, 319)
      ..lineTo(42, 313)
      ..lineTo(40, 290)
      ..quadraticBezierTo(48, 279, 50, 292)
      ..lineTo(51, 311)
      ..lineTo(60, 301)
      ..quadraticBezierTo(70, 300, 66, 311)
      ..lineTo(53, 327)
      ..lineTo(53, 350)
      ..close(),
    _coral,
    46,
    332,
    subject: false,
  );
  b.region(
    'seaweed',
    Path()
      ..moveTo(339, 350)
      ..cubicTo(313, 326, 344, 306, 327, 279)
      ..cubicTo(358, 296, 332, 325, 350, 348)
      ..close(),
    _leaf,
    338,
    320,
    subject: false,
  );
  b.region(
    'pebble',
    _oval(81, 353, 31, 16),
    _lavender,
    96,
    361,
    subject: false,
  );
  if (b.variant.isOdd) {
    b.region(
      'fish',
      Path()
        ..moveTo(275, 315)
        ..quadraticBezierTo(296, 292, 318, 315)
        ..lineTo(332, 300)
        ..lineTo(332, 330)
        ..lineTo(318, 315)
        ..quadraticBezierTo(295, 336, 275, 315)
        ..close(),
      _gold,
      297,
      315,
      subject: false,
    );
    b.eye(285, 312, r: 2);
  }
  if (b.variant >= 2) {
    b.sparkle(79, 140, 10, _gold);
    b.region(
      'bubble3',
      _oval(343, 153, 24, 24),
      _white,
      355,
      165,
      subject: false,
    );
  }
}

void _whale(_Builder b) {
  _ocean(b);
  b.region(
    'tailupper',
    Path()
      ..moveTo(291, 232)
      ..cubicTo(298, 213, 319, 196, 345, 200)
      ..cubicTo(346, 226, 333, 244, 310, 252)
      ..close(),
    _blue,
    323,
    219,
  );
  b.region(
    'taillower',
    Path()
      ..moveTo(300, 244)
      ..cubicTo(322, 239, 344, 246, 359, 269)
      ..cubicTo(335, 283, 311, 276, 300, 258)
      ..close(),
    _teal,
    331,
    263,
  );
  b.region(
    'body',
    Path()
      ..moveTo(67, 219)
      ..cubicTo(63, 165, 102, 133, 158, 140)
      ..cubicTo(229, 149, 241, 236, 305, 246)
      ..cubicTo(265, 300, 184, 313, 125, 286)
      ..cubicTo(94, 273, 73, 251, 67, 219)
      ..close(),
    _blue,
    171,
    210,
  );
  b.region(
    'belly',
    Path()
      ..moveTo(68, 223)
      ..cubicTo(105, 254, 135, 276, 189, 279)
      ..cubicTo(231, 282, 264, 273, 305, 246)
      ..cubicTo(265, 300, 184, 313, 125, 286)
      ..cubicTo(94, 273, 73, 251, 68, 223)
      ..close(),
    _cream,
    174,
    289,
  );
  b.region(
    'flipper',
    Path()
      ..moveTo(174, 227)
      ..cubicTo(149, 240, 150, 279, 180, 302)
      ..cubicTo(197, 281, 206, 247, 190, 226)
      ..quadraticBezierTo(184, 221, 174, 227)
      ..close(),
    _teal,
    178,
    263,
  );
  b.region(
    'spoutleft',
    Path()
      ..moveTo(149, 140)
      ..cubicTo(137, 115, 107, 119, 110, 101)
      ..cubicTo(116, 81, 140, 99, 148, 116)
      ..cubicTo(143, 91, 157, 78, 165, 94)
      ..cubicTo(171, 109, 157, 122, 155, 140)
      ..close(),
    _teal,
    146,
    111,
  );
  b.region(
    'spoutright',
    Path()
      ..moveTo(155, 138)
      ..cubicTo(163, 107, 188, 94, 193, 109)
      ..cubicTo(198, 123, 174, 123, 164, 141)
      ..close(),
    _teal,
    175,
    118,
  );
  b.eye(111, 197, r: 6);
  b.stroke(
    Path()
      ..moveTo(76, 224)
      ..quadraticBezierTo(107, 241, 131, 218),
  );
  for (int i = 0; i < 3; i++) {
    b.stroke(
      Path()
        ..moveTo(87 + i * 13, 245 + i * 6)
        ..quadraticBezierTo(
          104 + i * 12,
          267 + i * 4,
          124 + i * 12,
          272 + i * 3,
        ),
      width: 1.8,
    );
  }
}

void _dolphin(_Builder b) {
  _ocean(b);
  b.region(
    'dorsal',
    Path()
      ..moveTo(202, 181)
      ..quadraticBezierTo(219, 137, 248, 133)
      ..quadraticBezierTo(230, 164, 242, 192)
      ..close(),
    _blue,
    225,
    163,
  );
  b.region(
    'tailupper',
    Path()
      ..moveTo(292, 274)
      ..quadraticBezierTo(294, 238, 328, 225)
      ..quadraticBezierTo(339, 260, 316, 287)
      ..close(),
    _teal,
    315,
    258,
  );
  b.region(
    'taillower',
    Path()
      ..moveTo(303, 283)
      ..quadraticBezierTo(336, 272, 358, 286)
      ..quadraticBezierTo(333, 315, 309, 298)
      ..close(),
    _teal,
    333,
    291,
  );
  b.region(
    'body',
    Path()
      ..moveTo(55, 173)
      ..quadraticBezierTo(69, 156, 103, 163)
      ..cubicTo(131, 116, 196, 132, 228, 180)
      ..cubicTo(262, 229, 269, 263, 307, 284)
      ..cubicTo(259, 297, 214, 263, 182, 234)
      ..cubicTo(150, 207, 124, 196, 82, 192)
      ..quadraticBezierTo(50, 191, 55, 173)
      ..close(),
    _blue,
    168,
    173,
  );
  b.region(
    'belly',
    Path()
      ..moveTo(82, 192)
      ..cubicTo(128, 179, 171, 204, 198, 230)
      ..cubicTo(231, 264, 263, 281, 307, 284)
      ..cubicTo(259, 297, 214, 263, 182, 234)
      ..cubicTo(150, 207, 124, 196, 82, 192)
      ..close(),
    _cream,
    179,
    216,
  );
  b.region(
    'flipper',
    Path()
      ..moveTo(171, 214)
      ..cubicTo(156, 233, 165, 267, 189, 278)
      ..quadraticBezierTo(209, 250, 188, 223)
      ..close(),
    _teal,
    183,
    249,
  );
  b.eye(117, 166, r: 5);
  b.stroke(
    Path()
      ..moveTo(61, 179)
      ..quadraticBezierTo(84, 193, 108, 182),
  );
}

void _duck(_Builder b) {
  _ocean(b);
  b.region(
    'footleft',
    Path()
      ..moveTo(178, 301)
      ..lineTo(169, 320)
      ..lineTo(153, 326)
      ..lineTo(181, 330)
      ..lineTo(194, 318)
      ..close(),
    _gold,
    175,
    321,
  );
  b.region(
    'footright',
    Path()
      ..moveTo(226, 301)
      ..lineTo(239, 317)
      ..lineTo(254, 320)
      ..lineTo(231, 329)
      ..lineTo(214, 316)
      ..close(),
    _gold,
    235,
    320,
  );
  b.region(
    'body',
    Path()
      ..moveTo(155, 227)
      ..cubicTo(163, 198, 188, 195, 210, 209)
      ..cubicTo(248, 239, 277, 225, 300, 204)
      ..cubicTo(320, 269, 270, 309, 214, 310)
      ..cubicTo(172, 310, 145, 277, 155, 227)
      ..close(),
    _gold,
    239,
    262,
  );
  b.region(
    'wing',
    Path()
      ..moveTo(202, 239)
      ..cubicTo(213, 232, 234, 254, 264, 247)
      ..cubicTo(257, 282, 211, 289, 195, 262)
      ..quadraticBezierTo(189, 247, 202, 239)
      ..close(),
    _coral,
    229,
    263,
  );
  b.region(
    'head',
    Path()
      ..moveTo(117, 179)
      ..cubicTo(106, 136, 129, 104, 169, 104)
      ..cubicTo(212, 104, 235, 133, 225, 174)
      ..cubicTo(218, 205, 186, 222, 156, 209)
      ..cubicTo(137, 201, 121, 198, 117, 179)
      ..close(),
    _gold,
    168,
    151,
  );
  b.region(
    'beak',
    Path()
      ..moveTo(119, 171)
      ..quadraticBezierTo(84, 167, 83, 185)
      ..quadraticBezierTo(87, 201, 124, 190)
      ..quadraticBezierTo(131, 180, 119, 171)
      ..close(),
    _coral,
    105,
    182,
  );
  b.eye(151, 158, r: 6);
  b.stroke(
    Path()
      ..moveTo(89, 185)
      ..lineTo(118, 182),
  );
  b.stroke(
    Path()
      ..moveTo(167, 106)
      ..quadraticBezierTo(157, 91, 164, 86)
      ..quadraticBezierTo(175, 91, 173, 104),
  );
  b.stroke(
    Path()
      ..moveTo(173, 104)
      ..quadraticBezierTo(180, 90, 186, 95),
  );
}

void _turtle(_Builder b) {
  _ocean(b);
  b.region(
    'backflipper',
    Path()
      ..moveTo(260, 240)
      ..quadraticBezierTo(298, 238, 318, 275)
      ..quadraticBezierTo(275, 289, 253, 266)
      ..close(),
    _teal,
    287,
    265,
  );
  b.region(
    'leftflipper',
    Path()
      ..moveTo(137, 246)
      ..quadraticBezierTo(101, 264, 91, 297)
      ..quadraticBezierTo(131, 308, 161, 273)
      ..close(),
    _teal,
    124,
    279,
  );
  b.region(
    'head',
    Path()
      ..moveTo(111, 183)
      ..cubicTo(78, 163, 52, 187, 58, 214)
      ..cubicTo(63, 240, 105, 243, 125, 219)
      ..close(),
    _leaf,
    83,
    209,
  );
  b.region(
    'shelltop',
    Path()
      ..moveTo(117, 216)
      ..cubicTo(117, 129, 245, 109, 288, 204)
      ..lineTo(259, 228)
      ..lineTo(149, 235)
      ..close(),
    _teal,
    198,
    170,
  );
  b.region(
    'shellbottom',
    Path()
      ..moveTo(117, 216)
      ..quadraticBezierTo(187, 195, 288, 204)
      ..cubicTo(301, 250, 257, 278, 207, 278)
      ..quadraticBezierTo(134, 280, 117, 216)
      ..close(),
    _gold,
    209,
    253,
  );
  b.region(
    'shellcenter',
    _poly([
      const Offset(174, 184),
      const Offset(221, 177),
      const Offset(247, 213),
      const Offset(222, 248),
      const Offset(177, 244),
      const Offset(154, 215),
    ]),
    _leaf,
    201,
    213,
  );
  b.region(
    'frontflipper',
    Path()
      ..moveTo(163, 248)
      ..cubicTo(159, 271, 171, 306, 201, 317)
      ..quadraticBezierTo(222, 287, 197, 263)
      ..close(),
    _teal,
    186,
    289,
  );
  b.region(
    'tail',
    _poly([
      const Offset(283, 212),
      const Offset(316, 223),
      const Offset(286, 233),
    ]),
    _leaf,
    295,
    223,
  );
  b.eye(76, 199, r: 4);
  b.stroke(
    Path()
      ..moveTo(62, 218)
      ..quadraticBezierTo(77, 226, 89, 216),
  );
  b.stroke(
    Path()
      ..moveTo(174, 184)
      ..lineTo(153, 155)
      ..moveTo(221, 177)
      ..lineTo(236, 147)
      ..moveTo(247, 213)
      ..lineTo(288, 204)
      ..moveTo(222, 248)
      ..lineTo(239, 271)
      ..moveTo(177, 244)
      ..lineTo(154, 263),
  );
}
