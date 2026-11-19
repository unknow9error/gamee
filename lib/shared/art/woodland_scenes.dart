part of 'art_scene.dart';

void _garden(_Builder b, {bool night = false}) {
  b.region(
    'sky',
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 376, 376),
        const Radius.circular(25),
      ),
    ),
    night ? const Color(0xFFE4E0F5) : const Color(0xFFEAF3E5),
    200,
    55,
    subject: false,
  );
  b.region(
    'hill',
    Path()
      ..moveTo(12, 306)
      ..quadraticBezierTo(115, 259, 211, 309)
      ..quadraticBezierTo(312, 263, 388, 304)
      ..lineTo(388, 388)
      ..lineTo(12, 388)
      ..close(),
    const Color(0xFFD5E8C9),
    190,
    365,
    subject: false,
  );
  b.region(
    'leafleft',
    Path()
      ..moveTo(45, 328)
      ..quadraticBezierTo(21, 295, 35, 280)
      ..quadraticBezierTo(60, 294, 45, 328)
      ..close(),
    _leaf,
    39,
    303,
    subject: false,
  );
  b.region(
    'leafright',
    Path()
      ..moveTo(343, 328)
      ..quadraticBezierTo(316, 298, 329, 282)
      ..quadraticBezierTo(353, 296, 343, 328)
      ..close(),
    _teal,
    335,
    305,
    subject: false,
  );
  b.region(
    'cloud',
    Path()
      ..moveTo(54, 78)
      ..quadraticBezierTo(42, 57, 62, 55)
      ..quadraticBezierTo(70, 32, 89, 49)
      ..quadraticBezierTo(112, 46, 111, 66)
      ..quadraticBezierTo(125, 83, 100, 84)
      ..lineTo(62, 84)
      ..close(),
    _white,
    79,
    67,
    subject: false,
  );
  b.region(
    'sun',
    _oval(300, 43, 44, 44),
    night ? _lavender : _gold,
    322,
    65,
    subject: false,
  );
  b.region(
    'flower',
    Path()
      ..addOval(const Rect.fromLTWH(63, 314, 15, 15))
      ..addOval(const Rect.fromLTWH(74, 306, 15, 15))
      ..addOval(const Rect.fromLTWH(84, 317, 15, 15))
      ..addOval(const Rect.fromLTWH(75, 328, 15, 15))
      ..addOval(const Rect.fromLTWH(61, 327, 15, 15)),
    _coral,
    79,
    322,
    subject: false,
  );
  if (b.variant.isOdd) b.sparkle(62, 230, 12, _gold);
  if (b.variant >= 2) {
    b.region(
      'cloud2',
      Path()
        ..moveTo(283, 112)
        ..quadraticBezierTo(276, 97, 288, 92)
        ..quadraticBezierTo(297, 77, 311, 91)
        ..quadraticBezierTo(332, 89, 330, 108)
        ..quadraticBezierTo(338, 119, 320, 120)
        ..lineTo(291, 120)
        ..close(),
      _white,
      306,
      105,
      subject: false,
    );
    b.sparkle(54, 185, 10, _gold);
  }
}

void _fox(_Builder b) {
  _garden(b);
  b.region(
    'tail',
    Path()
      ..moveTo(235, 281)
      ..cubicTo(316, 300, 342, 250, 318, 214)
      ..cubicTo(314, 244, 272, 226, 251, 248)
      ..close(),
    _coral,
    286,
    263,
  );
  b.region(
    'tailtip',
    Path()
      ..moveTo(299, 239)
      ..quadraticBezierTo(317, 234, 318, 214)
      ..quadraticBezierTo(335, 241, 322, 264)
      ..lineTo(311, 257)
      ..lineTo(305, 267)
      ..close(),
    _cream,
    315,
    244,
  );
  b.region(
    'bodyleft',
    Path()
      ..moveTo(179, 212)
      ..quadraticBezierTo(147, 242, 146, 301)
      ..quadraticBezierTo(168, 323, 198, 308)
      ..lineTo(202, 230)
      ..close(),
    _coral,
    172,
    268,
  );
  b.region(
    'bodyright',
    Path()
      ..moveTo(202, 230)
      ..lineTo(225, 211)
      ..quadraticBezierTo(258, 248, 251, 305)
      ..quadraticBezierTo(228, 323, 198, 308)
      ..close(),
    const Color(0xFFEB855F),
    226,
    273,
  );
  b.region(
    'chest',
    Path()
      ..moveTo(181, 219)
      ..lineTo(200, 235)
      ..lineTo(219, 219)
      ..lineTo(231, 267)
      ..lineTo(217, 261)
      ..lineTo(204, 284)
      ..lineTo(190, 263)
      ..lineTo(179, 269)
      ..close(),
    _cream,
    205,
    253,
  );
  b.region(
    'earleft',
    _poly([
      const Offset(136, 162),
      const Offset(126, 83),
      const Offset(181, 125),
    ]),
    _coral,
    145,
    125,
  );
  b.region(
    'earright',
    _poly([
      const Offset(219, 123),
      const Offset(274, 83),
      const Offset(261, 164),
    ]),
    _coral,
    251,
    126,
  );
  b.region(
    'head',
    Path()
      ..moveTo(137, 141)
      ..quadraticBezierTo(199, 102, 262, 143)
      ..lineTo(279, 177)
      ..quadraticBezierTo(242, 225, 201, 232)
      ..quadraticBezierTo(158, 223, 120, 177)
      ..close(),
    _coral,
    200,
    153,
  );
  b.region(
    'cheekleft',
    Path()
      ..moveTo(121, 177)
      ..quadraticBezierTo(167, 169, 201, 212)
      ..lineTo(201, 232)
      ..quadraticBezierTo(157, 223, 121, 177)
      ..close(),
    _cream,
    169,
    201,
  );
  b.region(
    'cheekright',
    Path()
      ..moveTo(279, 177)
      ..quadraticBezierTo(233, 169, 201, 212)
      ..lineTo(201, 232)
      ..quadraticBezierTo(241, 225, 279, 177)
      ..close(),
    _cream,
    232,
    201,
  );
  b.eye(164, 169, r: 4);
  b.eye(238, 169, r: 4);
  b.stroke(
    _poly([
      const Offset(193, 207),
      const Offset(210, 207),
      const Offset(201, 216),
    ]),
    width: 4,
  );
  b.stroke(
    Path()
      ..moveTo(201, 215)
      ..lineTo(201, 222)
      ..quadraticBezierTo(192, 228, 185, 220)
      ..moveTo(201, 222)
      ..quadraticBezierTo(210, 228, 217, 220),
  );
  b.stroke(
    Path()
      ..moveTo(158, 301)
      ..lineTo(179, 301)
      ..moveTo(222, 301)
      ..lineTo(242, 301),
  );
}

void _rabbit(_Builder b) {
  _garden(b);
  b.region('taillarge', _oval(260, 264, 39, 39), _white, 279, 283);
  b.region(
    'bodyleft',
    Path()
      ..moveTo(178, 215)
      ..cubicTo(131, 230, 133, 303, 174, 318)
      ..lineTo(207, 318)
      ..lineTo(207, 225)
      ..close(),
    _white,
    171,
    272,
  );
  b.region(
    'bodyright',
    Path()
      ..moveTo(207, 225)
      ..quadraticBezierTo(265, 222, 276, 286)
      ..quadraticBezierTo(270, 323, 207, 318)
      ..close(),
    _lavender,
    243,
    278,
  );
  b.region(
    'earleft',
    Path()
      ..moveTo(155, 147)
      ..cubicTo(115, 93, 127, 61, 145, 73)
      ..cubicTo(169, 91, 177, 118, 179, 144)
      ..close(),
    _white,
    146,
    110,
  );
  b.region(
    'earright',
    Path()
      ..moveTo(201, 143)
      ..cubicTo(199, 89, 222, 58, 239, 72)
      ..cubicTo(251, 91, 229, 127, 224, 150)
      ..close(),
    _white,
    222,
    110,
  );
  b.region(
    'earpinkleft',
    Path()
      ..moveTo(154, 132)
      ..quadraticBezierTo(131, 93, 142, 90)
      ..quadraticBezierTo(162, 111, 165, 134)
      ..close(),
    _coral,
    150,
    114,
  );
  b.region(
    'earpinkright',
    Path()
      ..moveTo(211, 133)
      ..quadraticBezierTo(214, 91, 230, 85)
      ..quadraticBezierTo(232, 107, 221, 136)
      ..close(),
    _coral,
    222,
    113,
  );
  b.region(
    'head',
    Path()
      ..moveTo(137, 172)
      ..cubicTo(136, 119, 224, 115, 247, 160)
      ..cubicTo(271, 209, 225, 237, 185, 229)
      ..cubicTo(150, 225, 130, 206, 137, 172)
      ..close(),
    _white,
    195,
    169,
  );
  b.region(
    'foot',
    Path()
      ..moveTo(198, 290)
      ..quadraticBezierTo(171, 293, 167, 315)
      ..quadraticBezierTo(178, 332, 230, 323)
      ..quadraticBezierTo(243, 306, 219, 295)
      ..close(),
    _cream,
    204,
    315,
  );
  b.eye(164, 171, r: 4);
  b.eye(217, 171, r: 4);
  b.stroke(
    _poly([
      const Offset(184, 189),
      const Offset(198, 189),
      const Offset(192, 197),
    ]),
    width: 3,
  );
  b.stroke(
    Path()
      ..moveTo(192, 195)
      ..lineTo(192, 202)
      ..quadraticBezierTo(183, 210, 176, 203)
      ..moveTo(192, 202)
      ..quadraticBezierTo(202, 211, 210, 201),
  );
  b.stroke(
    Path()
      ..moveTo(153, 188)
      ..lineTo(126, 181)
      ..moveTo(152, 195)
      ..lineTo(125, 199)
      ..moveTo(226, 187)
      ..lineTo(254, 180)
      ..moveTo(229, 195)
      ..lineTo(258, 199),
    width: 1.8,
  );
}

void _cat(_Builder b) {
  _garden(b);
  b.region(
    'tail',
    Path()
      ..moveTo(252, 291)
      ..cubicTo(306, 310, 327, 283, 309, 247)
      ..cubicTo(303, 233, 287, 241, 295, 254)
      ..cubicTo(307, 279, 285, 288, 261, 274)
      ..close(),
    _lavender,
    297,
    280,
  );
  b.region(
    'body',
    Path()
      ..moveTo(171, 217)
      ..quadraticBezierTo(153, 253, 157, 312)
      ..quadraticBezierTo(204, 331, 252, 311)
      ..quadraticBezierTo(251, 250, 227, 219)
      ..close(),
    _lavender,
    204,
    275,
  );
  b.region(
    'chest',
    Path()
      ..moveTo(179, 231)
      ..quadraticBezierTo(204, 241, 221, 231)
      ..lineTo(233, 279)
      ..quadraticBezierTo(205, 300, 175, 278)
      ..close(),
    _cream,
    204,
    265,
  );
  b.region(
    'earleft',
    _poly([
      const Offset(142, 158),
      const Offset(133, 94),
      const Offset(183, 123),
    ]),
    _lavender,
    151,
    126,
  );
  b.region(
    'earright',
    _poly([
      const Offset(219, 122),
      const Offset(267, 94),
      const Offset(259, 160),
    ]),
    _lavender,
    246,
    128,
  );
  b.region(
    'head',
    Path()
      ..moveTo(138, 142)
      ..quadraticBezierTo(200, 109, 262, 145)
      ..quadraticBezierTo(283, 204, 245, 223)
      ..quadraticBezierTo(200, 245, 153, 220)
      ..quadraticBezierTo(125, 201, 138, 142)
      ..close(),
    _lavender,
    201,
    161,
  );
  b.region(
    'muzzle',
    Path()
      ..moveTo(170, 195)
      ..quadraticBezierTo(180, 180, 200, 190)
      ..quadraticBezierTo(226, 179, 236, 197)
      ..quadraticBezierTo(225, 225, 202, 225)
      ..quadraticBezierTo(178, 224, 170, 195)
      ..close(),
    _cream,
    202,
    208,
  );
  b.region(
    'pawleft',
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(153, 296, 43, 28),
        const Radius.circular(13),
      ),
    ),
    _white,
    174,
    310,
  );
  b.region(
    'pawright',
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(212, 296, 43, 28),
        const Radius.circular(13),
      ),
    ),
    _white,
    234,
    310,
  );
  b.eye(164, 174, r: 4);
  b.eye(238, 174, r: 4);
  b.stroke(
    _poly([
      const Offset(195, 191),
      const Offset(209, 191),
      const Offset(202, 199),
    ]),
    width: 3,
  );
  b.stroke(
    Path()
      ..moveTo(202, 199)
      ..lineTo(202, 206)
      ..quadraticBezierTo(190, 215, 184, 206)
      ..moveTo(202, 206)
      ..quadraticBezierTo(216, 216, 222, 206),
  );
  b.stroke(
    Path()
      ..moveTo(157, 195)
      ..lineTo(125, 187)
      ..moveTo(158, 202)
      ..lineTo(124, 205)
      ..moveTo(244, 195)
      ..lineTo(278, 187)
      ..moveTo(244, 202)
      ..lineTo(279, 205),
    width: 1.8,
  );
  b.stroke(
    Path()
      ..moveTo(191, 129)
      ..lineTo(196, 146)
      ..moveTo(208, 128)
      ..lineTo(205, 146)
      ..moveTo(220, 133)
      ..lineTo(214, 148),
    width: 3.5,
  );
}

void _butterfly(_Builder b) {
  _garden(b);
  b.region(
    'winglefttop',
    Path()
      ..moveTo(193, 189)
      ..cubicTo(151, 102, 78, 92, 64, 138)
      ..cubicTo(44, 195, 117, 222, 184, 221)
      ..close(),
    _coral,
    127,
    161,
  );
  b.region(
    'wingrighttop',
    Path()
      ..moveTo(208, 188)
      ..cubicTo(250, 103, 323, 92, 337, 138)
      ..cubicTo(358, 196, 285, 223, 216, 221)
      ..close(),
    _gold,
    274,
    161,
  );
  b.region(
    'wingleftbottom',
    Path()
      ..moveTo(185, 213)
      ..cubicTo(120, 208, 81, 246, 104, 286)
      ..cubicTo(133, 334, 184, 286, 195, 249)
      ..close(),
    _lavender,
    144,
    263,
  );
  b.region(
    'wingrightbottom',
    Path()
      ..moveTo(216, 213)
      ..cubicTo(281, 208, 320, 246, 297, 286)
      ..cubicTo(268, 334, 217, 286, 207, 249)
      ..close(),
    _teal,
    257,
    263,
  );
  b.region(
    'spotleft',
    Path()
      ..moveTo(162, 179)
      ..cubicTo(146, 142, 102, 127, 95, 150)
      ..cubicTo(92, 170, 125, 187, 162, 179)
      ..close(),
    _cream,
    123,
    158,
  );
  b.region(
    'spotright',
    Path()
      ..moveTo(239, 179)
      ..cubicTo(255, 142, 299, 127, 306, 150)
      ..cubicTo(309, 170, 277, 187, 239, 179)
      ..close(),
    _cream,
    278,
    158,
  );
  b.region('bottomleftdot', _oval(126, 248, 27, 27), _gold, 139, 261);
  b.region('bottomrightdot', _oval(248, 248, 27, 27), _coral, 261, 261);
  b.region(
    'body',
    Path()
      ..moveTo(189, 180)
      ..quadraticBezierTo(200, 169, 212, 180)
      ..quadraticBezierTo(221, 225, 207, 265)
      ..quadraticBezierTo(200, 278, 194, 265)
      ..quadraticBezierTo(181, 225, 189, 180)
      ..close(),
    _lavender,
    201,
    222,
  );
  b.region('head', _oval(181, 154, 40, 39), _gold, 201, 171);
  b.stroke(
    Path()
      ..moveTo(190, 158)
      ..quadraticBezierTo(185, 140, 174, 142)
      ..moveTo(212, 158)
      ..quadraticBezierTo(219, 140, 229, 142),
  );
  b.eye(193, 169, r: 2);
  b.eye(209, 169, r: 2);
  b.stroke(
    Path()
      ..moveTo(196, 179)
      ..quadraticBezierTo(201, 183, 206, 178),
    width: 1.6,
  );
  b.stroke(
    Path()
      ..moveTo(187, 208)
      ..lineTo(215, 208)
      ..moveTo(188, 227)
      ..lineTo(214, 227)
      ..moveTo(191, 246)
      ..lineTo(210, 246),
    width: 1.8,
  );
}

void _lion(_Builder b) {
  _garden(b);
  b.region(
    'tail',
    Path()
      ..moveTo(251, 284)
      ..cubicTo(311, 300, 308, 265, 291, 256)
      ..quadraticBezierTo(294, 246, 303, 249)
      ..cubicTo(331, 279, 310, 317, 253, 299)
      ..close(),
    _gold,
    300,
    293,
  );
  b.region(
    'body',
    Path()
      ..moveTo(163, 209)
      ..quadraticBezierTo(137, 267, 149, 316)
      ..quadraticBezierTo(201, 335, 252, 316)
      ..quadraticBezierTo(263, 260, 235, 210)
      ..close(),
    _gold,
    199,
    280,
  );
  b.region('chest', _oval(178, 239, 45, 56), _cream, 200, 265);
  b.region(
    'maneleft',
    Path()
      ..moveTo(201, 97)
      ..lineTo(174, 87)
      ..lineTo(159, 105)
      ..lineTo(132, 104)
      ..lineTo(130, 130)
      ..lineTo(106, 146)
      ..lineTo(115, 171)
      ..lineTo(107, 195)
      ..lineTo(132, 210)
      ..lineTo(138, 236)
      ..lineTo(165, 231)
      ..lineTo(185, 248)
      ..lineTo(202, 231)
      ..close(),
    _coral,
    140,
    167,
  );
  b.region(
    'maneright',
    Path()
      ..moveTo(201, 97)
      ..lineTo(226, 88)
      ..lineTo(243, 107)
      ..lineTo(270, 105)
      ..lineTo(272, 132)
      ..lineTo(295, 149)
      ..lineTo(285, 173)
      ..lineTo(293, 197)
      ..lineTo(268, 212)
      ..lineTo(261, 238)
      ..lineTo(235, 232)
      ..lineTo(215, 249)
      ..lineTo(202, 231)
      ..close(),
    const Color(0xFFE99659),
    261,
    168,
  );
  b.region('earleft', _oval(137, 125, 33, 33), _gold, 153, 141);
  b.region('earright', _oval(233, 125, 33, 33), _gold, 249, 141);
  b.region(
    'face',
    Path()
      ..moveTo(155, 143)
      ..quadraticBezierTo(201, 114, 246, 144)
      ..quadraticBezierTo(267, 195, 236, 216)
      ..quadraticBezierTo(202, 238, 167, 215)
      ..quadraticBezierTo(137, 192, 155, 143)
      ..close(),
    _gold,
    200,
    166,
  );
  b.region('muzzleleft', _oval(168, 181, 37, 33), _cream, 183, 199);
  b.region('muzzleright', _oval(200, 181, 37, 33), _cream, 221, 199);
  b.region('pawleft', _oval(142, 299, 47, 28), _cream, 164, 313);
  b.region('pawright', _oval(213, 299, 47, 28), _cream, 236, 313);
  b.eye(173, 167, r: 4);
  b.eye(230, 167, r: 4);
  b.stroke(
    _poly([
      const Offset(193, 187),
      const Offset(211, 187),
      const Offset(202, 198),
    ]),
    width: 3,
  );
  b.stroke(
    Path()
      ..moveTo(202, 198)
      ..lineTo(202, 209)
      ..quadraticBezierTo(196, 217, 188, 211)
      ..moveTo(202, 209)
      ..quadraticBezierTo(211, 217, 217, 210),
  );
}

void _giraffe(_Builder b) {
  _garden(b);
  b.region(
    'tail',
    Path()
      ..moveTo(245, 258)
      ..quadraticBezierTo(283, 264, 277, 294)
      ..lineTo(267, 292)
      ..quadraticBezierTo(275, 270, 241, 269)
      ..close(),
    _gold,
    265,
    272,
  );
  b.region(
    'legback',
    Path()
      ..moveTo(223, 271)
      ..lineTo(245, 273)
      ..lineTo(252, 329)
      ..lineTo(227, 329)
      ..close(),
    _gold,
    239,
    309,
  );
  b.region(
    'body',
    Path()
      ..moveTo(155, 220)
      ..cubicTo(199, 202, 253, 225, 258, 256)
      ..quadraticBezierTo(260, 289, 210, 293)
      ..lineTo(159, 284)
      ..close(),
    _gold,
    217,
    253,
  );
  b.region(
    'neck',
    Path()
      ..moveTo(147, 141)
      ..lineTo(186, 137)
      ..lineTo(183, 274)
      ..lineTo(157, 295)
      ..lineTo(147, 257)
      ..close(),
    _gold,
    164,
    210,
  );
  b.region(
    'legfront',
    Path()
      ..moveTo(157, 272)
      ..lineTo(180, 273)
      ..lineTo(181, 329)
      ..lineTo(155, 329)
      ..close(),
    _gold,
    168,
    309,
  );
  b.region(
    'earleft',
    Path()
      ..moveTo(145, 119)
      ..quadraticBezierTo(118, 88, 113, 107)
      ..quadraticBezierTo(117, 129, 145, 131)
      ..close(),
    _gold,
    129,
    118,
  );
  b.region(
    'earright',
    Path()
      ..moveTo(193, 119)
      ..quadraticBezierTo(222, 90, 226, 110)
      ..quadraticBezierTo(219, 131, 193, 133)
      ..close(),
    _gold,
    210,
    119,
  );
  b.region(
    'head',
    Path()
      ..moveTo(143, 110)
      ..quadraticBezierTo(169, 93, 196, 110)
      ..lineTo(202, 156)
      ..quadraticBezierTo(172, 178, 139, 157)
      ..close(),
    _gold,
    169,
    130,
  );
  b.region(
    'muzzle',
    Path()
      ..moveTo(139, 144)
      ..quadraticBezierTo(168, 153, 202, 144)
      ..lineTo(203, 163)
      ..quadraticBezierTo(168, 184, 137, 164)
      ..close(),
    _cream,
    168,
    161,
  );
  b.region(
    'spotneck1',
    _poly([
      const Offset(155, 183),
      const Offset(171, 177),
      const Offset(178, 193),
      const Offset(161, 200),
    ]),
    _coral,
    166,
    190,
  );
  b.region(
    'spotneck2',
    _poly([
      const Offset(151, 216),
      const Offset(167, 212),
      const Offset(174, 230),
      const Offset(155, 235),
    ]),
    _coral,
    162,
    224,
  );
  b.region(
    'spotbody1',
    _poly([
      const Offset(198, 228),
      const Offset(216, 232),
      const Offset(212, 250),
      const Offset(192, 247),
    ]),
    _coral,
    204,
    240,
  );
  b.region(
    'spotbody2',
    _poly([
      const Offset(223, 258),
      const Offset(240, 252),
      const Offset(246, 270),
      const Offset(229, 277),
    ]),
    _coral,
    235,
    266,
  );
  b.eye(153, 132, r: 3.5);
  b.eye(185, 132, r: 3.5);
  b.eye(152, 159, r: 1.7);
  b.eye(188, 159, r: 1.7);
  b.stroke(
    Path()
      ..moveTo(151, 107)
      ..lineTo(149, 88)
      ..moveTo(186, 106)
      ..lineTo(188, 87),
    width: 5,
  );
  b.stroke(_oval(143, 80, 12, 12), width: 5);
  b.stroke(_oval(182, 79, 12, 12), width: 5);
  b.stroke(
    Path()
      ..moveTo(159, 167)
      ..quadraticBezierTo(171, 174, 181, 166),
  );
}

void _owl(_Builder b) {
  _garden(b, night: true);
  b.region(
    'branch',
    Path()
      ..moveTo(66, 310)
      ..quadraticBezierTo(194, 326, 328, 304)
      ..lineTo(338, 317)
      ..quadraticBezierTo(199, 339, 64, 326)
      ..close(),
    const Color(0xFFCEA47B),
    200,
    322,
    subject: false,
  );
  b.region(
    'body',
    Path()
      ..moveTo(141, 180)
      ..quadraticBezierTo(122, 262, 153, 298)
      ..quadraticBezierTo(201, 326, 248, 299)
      ..quadraticBezierTo(281, 258, 259, 180)
      ..close(),
    _lavender,
    199,
    263,
  );
  b.region(
    'wingleft',
    Path()
      ..moveTo(141, 198)
      ..quadraticBezierTo(111, 230, 132, 279)
      ..quadraticBezierTo(161, 270, 164, 223)
      ..close(),
    _teal,
    141,
    241,
  );
  b.region(
    'wingright',
    Path()
      ..moveTo(259, 198)
      ..quadraticBezierTo(290, 230, 269, 279)
      ..quadraticBezierTo(241, 270, 237, 223)
      ..close(),
    _teal,
    259,
    241,
  );
  b.region(
    'head',
    Path()
      ..moveTo(128, 173)
      ..lineTo(124, 100)
      ..lineTo(164, 121)
      ..quadraticBezierTo(199, 102, 236, 122)
      ..lineTo(279, 101)
      ..lineTo(273, 174)
      ..quadraticBezierTo(267, 221, 201, 230)
      ..quadraticBezierTo(135, 220, 128, 173)
      ..close(),
    _lavender,
    200,
    136,
  );
  b.region(
    'faceleft',
    Path()
      ..moveTo(201, 165)
      ..cubicTo(177, 127, 135, 139, 138, 174)
      ..cubicTo(141, 211, 182, 221, 201, 192)
      ..close(),
    _cream,
    166,
    174,
  );
  b.region(
    'faceright',
    Path()
      ..moveTo(201, 165)
      ..cubicTo(225, 127, 269, 139, 265, 174)
      ..cubicTo(262, 211, 220, 221, 201, 192)
      ..close(),
    _cream,
    238,
    174,
  );
  b.region(
    'belly',
    Path()
      ..moveTo(172, 235)
      ..quadraticBezierTo(201, 217, 230, 235)
      ..lineTo(235, 281)
      ..quadraticBezierTo(201, 305, 166, 281)
      ..close(),
    _cream,
    202,
    263,
  );
  b.region(
    'beak',
    _poly([
      const Offset(190, 187),
      const Offset(212, 187),
      const Offset(201, 208),
    ]),
    _gold,
    201,
    194,
  );
  b.region(
    'footleft',
    _poly([
      const Offset(169, 298),
      const Offset(163, 312),
      const Offset(179, 310),
      const Offset(185, 314),
      const Offset(189, 299),
    ]),
    _gold,
    177,
    306,
  );
  b.region(
    'footright',
    _poly([
      const Offset(216, 299),
      const Offset(213, 313),
      const Offset(227, 309),
      const Offset(237, 312),
      const Offset(234, 298),
    ]),
    _gold,
    225,
    305,
  );
  b.eye(165, 173, r: 7);
  b.eye(237, 173, r: 7);
  for (int y = 0; y < 2; y++) {
    for (int x = 0; x < 3; x++) {
      final px = 180.0 + x * 20;
      final py = 246.0 + y * 20;
      b.stroke(
        Path()
          ..moveTo(px - 4, py)
          ..quadraticBezierTo(px, py + 7, px + 4, py),
        width: 2,
      );
    }
  }
}
