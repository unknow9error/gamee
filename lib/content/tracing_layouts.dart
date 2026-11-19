import 'dart:ui';

import '../domain/models.dart';

/// Curated teaching gestures annotated on the final 1254-square ImageGen art.
/// The 400-unit coordinates use the complete asset; no crop or guessed icon ROI.
class DrawingAction {
  const DrawingAction({
    required this.id,
    required this.title,
    required this.instruction,
    required this.path,
    this.checkpointCount = 6,
    this.requiredHorizontalRuns = const [],
    this.minimumPatternHeight = 0,
  });
  final String id;
  final LocalizedText title;
  final LocalizedText instruction;
  final Path path;
  final int checkpointCount;
  final List<int> requiredHorizontalRuns;
  final double minimumPatternHeight;
  double get width => 3.5;

  List<Offset> get checkpoints {
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold(0.0, (sum, item) => sum + item.length);
    return List.generate(checkpointCount, (index) {
      var distance = total * index / (checkpointCount - 1);
      for (final metric in metrics) {
        if (distance <= metric.length) {
          return metric
              .getTangentForOffset(
                distance.clamp(
                  0.0,
                  (metric.length - .001).clamp(0.0, metric.length),
                ),
              )!
              .position;
        }
        distance -= metric.length;
      }
      return metrics.last
          .getTangentForOffset(metrics.last.length - .001)!
          .position;
    });
  }

  /// Preschool guide targets stay fully tappable even where the artwork's
  /// contour approaches an image edge. Ink remains on the original contour.
  List<Offset> checkpointsForCanvas(double side) {
    final margin = 25 * 400 / side;
    return [
      for (final p in checkpoints)
        Offset(
          p.dx.clamp(margin, 400 - margin),
          p.dy.clamp(margin, 400 - margin),
        ),
    ];
  }
}

class GuidedDrawingLayout {
  const GuidedDrawingLayout({
    required this.id,
    required this.asset,
    required this.actions,
  });
  final String id;
  final String asset;
  final List<DrawingAction> actions;
}

GuidedDrawingLayout guidedDrawingLayout(String scene, AgeBand ageBand) =>
    switch (scene) {
      'duck' => _duck(ageBand),
      'cat' => _cat(ageBand),
      _ => throw ArgumentError.value(
        scene,
        'scene',
        'No curated drawing lesson',
      ),
    };

GuidedDrawingLayout _duck(AgeBand ageBand) {
  final actions = <DrawingAction>[
    DrawingAction(
      id: 'head',
      title: const LocalizedText(
        'Плавная дуга головы',
        'Бастың доғасы',
        'A gentle head curve',
      ),
      instruction: const LocalizedText(
        'Начни у шеи и веди дугу вокруг пушистой головы.',
        'Мойыннан бастап, үлпілдек бастың доғасын бастыр.',
        'Start at the neck and trace around the fluffy head.',
      ),
      checkpointCount: 7,
      path: Path()
        ..moveTo(205, 157)
        ..cubicTo(163, 153, 140, 130, 150, 91)
        ..cubicTo(151, 42, 190, 10, 230, 12)
        ..cubicTo(269, 5, 286, 42, 290, 89),
    ),
    DrawingAction(
      id: 'beak',
      title: const LocalizedText(
        'Оранжевый клюв',
        'Қызғылт сары тұмсық',
        'The orange beak',
      ),
      instruction: const LocalizedText(
        'Обведи клюв: вверх, к кончику и обратно по нижнему краю.',
        'Тұмсықты бастыр: жоғары, ұшына қарай және төменгі шетімен кері.',
        'Trace up to the beak tip, then back along its lower edge.',
      ),
      checkpointCount: 5,
      path: Path()
        ..moveTo(240, 113)
        ..cubicTo(252, 106, 252, 88, 267, 86)
        ..cubicTo(283, 85, 290, 102, 315, 97)
        ..cubicTo(333, 104, 306, 117, 288, 122)
        ..cubicTo(270, 128, 250, 123, 240, 113),
    ),
    DrawingAction(
      id: 'body',
      title: const LocalizedText(
        'Круглый животик и хвост',
        'Домалақ дене мен құйрық',
        'A round body and tail',
      ),
      instruction: const LocalizedText(
        'От шеи обведи животик, хвостик и вернись по спинке.',
        'Мойыннан бастап денені, құйрықты бастырып, арқасымен қайт.',
        'From the neck, go around the belly and tail, then return along the back.',
      ),
      checkpointCount: 9,
      path: Path()
        ..moveTo(250, 147)
        ..cubicTo(269, 163, 281, 185, 277, 220)
        ..cubicTo(272, 265, 238, 290, 202, 296)
        ..cubicTo(159, 307, 112, 298, 81, 275)
        ..cubicTo(56, 252, 47, 216, 48, 171)
        ..cubicTo(55, 190, 67, 192, 82, 188)
        ..cubicTo(109, 178, 135, 160, 162, 160)
        ..cubicTo(177, 157, 188, 157, 201, 162),
    ),
    DrawingAction(
      id: 'wing',
      title: const LocalizedText('Крылышко', 'Қанатша', 'A little wing'),
      instruction: const LocalizedText(
        'Нарисуй большое крылышко одной плавной линией.',
        'Үлкен қанатты бір тегіс сызықпен сал.',
        'Draw the big wing with one smooth line.',
      ),
      checkpointCount: 6,
      path: Path()
        ..moveTo(92, 191)
        ..cubicTo(139, 161, 198, 167, 205, 197)
        ..cubicTo(211, 231, 165, 259, 119, 247)
        ..cubicTo(101, 242, 86, 229, 80, 214),
    ),
  ];
  if (ageBand != AgeBand.preschool) {
    actions.add(
      DrawingAction(
        id: 'webbed-foot',
        title: const LocalizedText(
          'Лапка с перепонками',
          'Жарғақты аяқ',
          'A webbed foot',
        ),
        instruction: const LocalizedText(
          'Веди вниз по ножке, затем нарисуй три широких пальчика.',
          'Аяқ бойымен төмен түсіп, үш жалпақ саусақты сал.',
          'Go down the leg, then trace the three broad toes.',
        ),
        checkpointCount: 7,
        path: Path()
          ..moveTo(122, 296)
          ..lineTo(123, 328)
          ..quadraticBezierTo(121, 340, 118, 346)
          ..cubicTo(139, 349, 172, 348, 194, 359)
          ..quadraticBezierTo(203, 364, 190, 366)
          ..lineTo(160, 368)
          ..lineTo(145, 374)
          ..lineTo(130, 370)
          ..quadraticBezierTo(118, 376, 117, 365)
          ..lineTo(119, 346),
      ),
    );
  }
  if (ageBand == AgeBand.advanced) {
    actions.add(
      DrawingAction(
        id: 'feather-pattern',
        requiredHorizontalRuns: const [1, -1, 1],
        minimumPatternHeight: 12,
        title: const LocalizedText(
          'Узор из пёрышек',
          'Қауырсын өрнегі',
          'A feather pattern',
        ),
        instruction: const LocalizedText(
          'Добавь на крыло узор из трёх чередующихся дуг.',
          'Қанатқа кезектесетін үш доғадан өрнек қос.',
          'Add a repeating pattern of three curved feathers to the wing.',
        ),
        path: Path()
          ..moveTo(94, 215)
          ..quadraticBezierTo(122, 228, 150, 213)
          ..quadraticBezierTo(137, 236, 112, 232)
          ..quadraticBezierTo(136, 248, 163, 228),
      ),
    );
  }
  return GuidedDrawingLayout(
    id: 'duck-photo-v2-${ageBand.name}',
    asset: 'assets/images/levels/09-duck.png',
    actions: List.unmodifiable(actions),
  );
}

GuidedDrawingLayout _cat(AgeBand ageBand) {
  // Annotated after viewing the final safe-inset19-cat.png, not its earlier crop.
  final actions = <DrawingAction>[
    DrawingAction(
      id: 'ears',
      title: const LocalizedText(
        'Два острых ушка',
        'Екі сүйір құлақ',
        'Two pointed ears',
      ),
      instruction: const LocalizedText(
        'Начни слева. Поднимись к ушку, пройди по макушке и нарисуй второе ушко.',
        'Сол жақтан баста. Құлаққа көтеріліп, төбесімен өтіп, екінші құлақты сал.',
        'Start on the left. Go up one ear, across the head, and around the second ear.',
      ),
      checkpointCount: 7,
      path: Path()
        ..moveTo(128, 100)
        ..cubicTo(125, 79, 135, 55, 147, 48)
        ..cubicTo(157, 49, 167, 70, 173, 79)
        ..quadraticBezierTo(187, 78, 197, 83)
        ..lineTo(226, 65)
        ..cubicTo(238, 55, 235, 86, 230, 107),
    ),
    DrawingAction(
      id: 'face',
      title: const LocalizedText(
        'Пушистые щёчки',
        'Үлпілдек ұрттар',
        'Fluffy cheeks',
      ),
      instruction: const LocalizedText(
        'Обведи щёчки и подбородок большой плавной дугой.',
        'Ұрттар мен иекті үлкен тегіс доғамен бастыр.',
        'Trace the cheeks and chin with one big gentle curve.',
      ),
      checkpointCount: 6,
      path: Path()
        ..moveTo(129, 101)
        ..cubicTo(113, 116, 114, 137, 132, 148)
        ..cubicTo(150, 161, 190, 164, 213, 152)
        ..cubicTo(228, 145, 230, 131, 224, 114),
    ),
    DrawingAction(
      id: 'body',
      title: const LocalizedText(
        'Тело и мягкие лапки',
        'Дене мен жұмсақ аяқтар',
        'A body and soft paws',
      ),
      instruction: const LocalizedText(
        'От шеи веди линию вокруг тела и мягких лапок.',
        'Мойыннан бастап дене мен жұмсақ аяқтарды айналдыра сал.',
        'From the neck, trace around the body and soft paws.',
      ),
      checkpointCount: 9,
      path: Path()
        ..moveTo(134, 154)
        ..cubicTo(120, 183, 124, 212, 132, 229)
        ..cubicTo(101, 241, 99, 275, 115, 301)
        ..quadraticBezierTo(117, 314, 128, 316)
        ..lineTo(144, 321)
        ..quadraticBezierTo(154, 328, 167, 324)
        ..quadraticBezierTo(181, 331, 192, 323)
        ..quadraticBezierTo(215, 327, 237, 316)
        ..cubicTo(267, 294, 258, 246, 218, 197)
        ..cubicTo(210, 187, 208, 173, 204, 158),
    ),
    DrawingAction(
      id: 'tail',
      title: const LocalizedText(
        'Хвостик крючком',
        'Иілген құйрық',
        'A curling tail',
      ),
      instruction: const LocalizedText(
        'От лапок веди хвостик вверх, закругли кончик и вернись вниз.',
        'Аяқтан бастап құйрықты жоғары сал, ұшын дөңгелетіп, төмен қайт.',
        'Start by the paws, curl up around the tail tip, and come back down.',
      ),
      checkpointCount: 7,
      path: Path()
        ..moveTo(249, 310)
        ..cubicTo(287, 311, 321, 283, 321, 252)
        ..cubicTo(322, 227, 302, 209, 281, 207)
        ..cubicTo(267, 206, 254, 217, 259, 230)
        ..cubicTo(265, 248, 279, 236, 287, 241)
        ..cubicTo(307, 264, 284, 291, 251, 297),
    ),
  ];
  if (ageBand != AgeBand.preschool) {
    actions.add(
      DrawingAction(
        id: 'front-paw',
        title: const LocalizedText(
          'Передняя лапка',
          'Алдыңғы аяқ',
          'A front paw',
        ),
        instruction: const LocalizedText(
          'Проведи длинную линию вниз и закругли мягкую лапку.',
          'Ұзын сызықты төмен жүргізіп, жұмсақ аяқты дөңгелет.',
          'Draw a long line down, then curve around the soft front paw.',
        ),
        path: Path()
          ..moveTo(161, 196)
          ..cubicTo(165, 229, 163, 275, 162, 309)
          ..cubicTo(155, 315, 156, 326, 169, 327)
          ..cubicTo(181, 329, 189, 323, 188, 315),
      ),
    );
  }
  if (ageBand == AgeBand.advanced) {
    actions.add(
      DrawingAction(
        id: 'stripe-pattern',
        requiredHorizontalRuns: const [-1, 1, -1],
        minimumPatternHeight: 12,
        title: const LocalizedText(
          'Полосатый узор',
          'Жолақты өрнек',
          'A striped pattern',
        ),
        instruction: const LocalizedText(
          'Добавь на бок котёнка узор из трёх чередующихся полосок.',
          'Марғаудың бүйіріне кезектесетін үш жолақтан өрнек қос.',
          'Add a repeating pattern of three stripes to the kitten’s side.',
        ),
        path: Path()
          ..moveTo(215, 204)
          ..quadraticBezierTo(200, 210, 187, 225)
          ..quadraticBezierTo(202, 220, 216, 222)
          ..quadraticBezierTo(203, 234, 187, 244),
      ),
    );
  }
  return GuidedDrawingLayout(
    id: 'cat-safe-inset-v2-${ageBand.name}',
    asset: 'assets/images/levels/19-cat.png',
    actions: List.unmodifiable(actions),
  );
}
