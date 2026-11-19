import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../art/scene_illustration.dart';
import 'trail_icon.dart';

/// The result is already saved before this presentation is opened. Closing the
/// overlay never owns progress or rewards, so navigation cannot award twice.
Future<void> showCelebration(
  BuildContext context, {
  required LevelDefinition level,
  required CompletionReward reward,
  required String language,
  required bool reducedMotion,
  required VoidCallback onNext,
  required VoidCallback onHome,
  AgeBand ageBand = AgeBand.primary,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: AppColors.ink.withValues(alpha: .42),
  animationStyle: reducedMotion || MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (dialogContext) => PopScope(
    canPop: false,
    child: _Celebration(
      level: level,
      reward: reward,
      language: language,
      reducedMotion: reducedMotion,
      ageBand: ageBand,
      onNext: () {
        Navigator.of(dialogContext).pop();
        onNext();
      },
      onHome: () {
        Navigator.of(dialogContext).pop();
        onHome();
      },
    ),
  ),
);

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.level,
    required this.reward,
    required this.language,
    required this.reducedMotion,
    required this.onNext,
    required this.onHome,
    required this.ageBand,
  });

  final LevelDefinition level;
  final CompletionReward reward;
  final String language;
  final bool reducedMotion;
  final VoidCallback onNext;
  final VoidCallback onHome;
  final AgeBand ageBand;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  bool _started = false;
  bool _leaving = false;

  void _leave(VoidCallback callback) {
    if (_leaving) return;
    _leaving = true;
    callback();
  }

  bool get _still =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _motion.value = 1;
    } else if (!_started) {
      _started = true;
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  String _t(String ru, String kk, String en) =>
      textFor(widget.language, ru, kk, en);

  Color get _accent => switch (widget.level.worldId) {
    'ocean' => AppColors.blue,
    'forest' => AppColors.lime,
    'meadow' => AppColors.lavender,
    'farm' => AppColors.yellow,
    'safari' => AppColors.peach,
    'space' => AppColors.lavender,
    _ => AppColors.lime,
  };

  String get _message => switch (widget.level.kind) {
    ActivityKind.numberColor => _t(
      'Все цвета нашли своё место!',
      'Әр түс өз орнын тапты!',
      'Every color found its place!',
    ),
    ActivityKind.oddFragment => _t(
      'Отличие найдено. Ты внимательно сравнил детали!',
      'Айырмашылық табылды. Бөлшектерді мұқият салыстырдың!',
      'Difference found. You compared the details carefully!',
    ),
    ActivityKind.connectDots => _t(
      'Точка за точкой — получилась картинка!',
      'Нүктелер қосылып, сурет пайда болды!',
      'Dot by dot, a picture appeared!',
    ),
    ActivityKind.matchPairs => _t(
      'Все пары вместе!',
      'Барлық жұп бірге!',
      'Every pair is together!',
    ),
    ActivityKind.patternSequence => _t(
      'Ты нашёл, что идёт дальше!',
      'Әрі қарай не болатынын таптың!',
      'You found what comes next!',
    ),
    ActivityKind.missingPuzzle => _t(
      'Кусочки сошлись. Картинка целая!',
      'Бөліктер бірікті. Сурет толық болды!',
      'The pieces fit. The picture is complete!',
    ),
    ActivityKind.ropeTrace => _t(
      'Ты проследил путь до самого конца!',
      'Жолды аяғына дейін қадағаладың!',
      'You followed the trail all the way!',
    ),
    ActivityKind.freeColor => _t(
      'Твои цвета сделали мир ярче.',
      'Сенің түстерің әлемді түрлендірді.',
      'Your colors made the world brighter.',
    ),
    ActivityKind.maze => _t(
      'Ура, мы добрались! Отличный маршрут.',
      'Алақай, біз жеттік! Тамаша жол.',
      'We made it! What a great route.',
    ),
    ActivityKind.guidedDraw => _t(
      'Шаг за шагом — и рисунок ожил!',
      'Қадам сайын суретке жан бітті!',
      'Step by step, your drawing came to life!',
    ),
    ActivityKind.hiddenAnimals => _t(
      'Все друзья нашлись. Вот это глаз!',
      'Барлық дос табылды. Көзің қырағы екен!',
      'You found every friend. Great spotting!',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: height - 48),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final progress = _motion.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _t(
                        'Приключение пройдено',
                        'Шытырман аяқталды',
                        'Adventure complete',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: height < 650 ? 145 : 205,
                    width: double.infinity,
                    child: _RewardScene(
                      level: widget.level,
                      progress: progress,
                      accent: _accent,
                      still: _still,
                    ),
                  ),
                  Semantics(
                    label: _t(
                      'Звёзд заработано: ${widget.reward.stars}',
                      'Жиналған жұлдыз: ${widget.reward.stars}',
                      '${widget.reward.stars} stars earned',
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.reward.stars, (index) {
                          final local = ((progress - .10 - index * .08) / .32)
                              .clamp(0.0, 1.0);
                          final scale = _still
                              ? 1.0
                              : Curves.easeOutBack.transform(local);
                          return Transform.translate(
                            offset: Offset(0, index == 1 ? -5 : 2),
                            child: Transform.scale(
                              scale: scale,
                              child: const TrailIcon(
                                TrailIconKind.star,
                                selected: true,
                                size: 47,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reward.firstCompletion
                        ? widget.ageBand == AgeBand.preschool
                              ? _t('Получилось!', 'Бәрекелді!', 'You did it!')
                              : widget.ageBand == AgeBand.advanced
                              ? _t(
                                  'Отличное открытие!',
                                  'Тамаша жаңалық!',
                                  'A great discovery!',
                                )
                              : _t(
                                  'Вот это здорово!',
                                  'Қандай керемет!',
                                  'You did it!',
                                )
                        : _t(
                            'Снова здорово!',
                            'Тағы да керемет!',
                            'Wonderful again!',
                          ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.reward.newSticker case final sticker?) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const TrailIcon(TrailIconKind.sparkles),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t(
                                'Новая наклейка в альбоме',
                                'Альбомда жаңа жапсырма',
                                'A new sticker in your album',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (sticker.illustrationAsset case final asset?)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                asset,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.reward.completedDailyQuests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'И маленькая миссия выполнена!',
                        'Кішкентай миссия да орындалды!',
                        'And a little mission is complete!',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (widget.reward.newAchievements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...widget.reward.newAchievements.map(
                      (achievement) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Row(
                          children: [
                            const TrailIcon(TrailIconKind.rewards, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t(
                                      'Новый значок',
                                      'Жаңа белгі',
                                      'New badge',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    achievement.title.resolve(widget.language),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _leave(widget.onNext),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      iconAlignment: IconAlignment.end,
                      label: Text(
                        _t(
                          'Дальше играть',
                          'Ойынды жалғастыру',
                          'Keep exploring',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: () => _leave(widget.onHome),
                    child: Text(
                      _t(
                        'На карту приключений',
                        'Шытырман картасына',
                        'Back to adventures',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RewardScene extends StatelessWidget {
  const _RewardScene({
    required this.level,
    required this.progress,
    required this.accent,
    required this.still,
  });
  final LevelDefinition level;
  final double progress;
  final Color accent;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final settling = Curves.easeOutCubic.transform(
      (progress / .7).clamp(0.0, 1.0),
    );
    final hop = still ? 0.0 : math.sin(progress * math.pi * 4) * (1 - progress);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RewardPainter(
              kind: level.kind,
              progress: progress,
              accent: accent,
              still: still,
              aquatic: level.scene == 'whale' || level.scene == 'dolphin',
            ),
          ),
        ),
        if (level.illustrationAsset case final asset?)
          Positioned.fill(
            left: 32,
            right: 32,
            top: 8,
            bottom: 6,
            child: _CuratedRewardImage(
              asset: asset,
              kind: level.kind,
              progress: progress,
              still: still,
            ),
          )
        else if (level.kind == ActivityKind.maze)
          Positioned.fill(
            child: CustomPaint(painter: _BusArrivalPainter(progress: settling)),
          )
        else if (level.kind == ActivityKind.hiddenAnimals)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final reveal = ((progress - index * .12) / .45).clamp(0.0, 1.0);
              final scale = still ? 1.0 : Curves.easeOutBack.transform(reveal);
              return Flexible(
                child: Transform.translate(
                  offset: Offset(0, index == 1 ? -6 : 13),
                  child: Transform.scale(
                    scale: scale,
                    child: SceneIllustration(
                      scene: ['cat', 'giraffe', 'turtle'][index],
                      size: 110,
                    ),
                  ),
                ),
              );
            }),
          )
        else
          FractionallySizedBox(
            widthFactor: .64,
            heightFactor: .91,
            child: Transform.translate(
              offset: Offset(
                level.kind == ActivityKind.guidedDraw ? hop * 8 : 0,
                level.kind == ActivityKind.guidedDraw
                    ? -hop.abs() * 14
                    : hop * 4,
              ),
              child: Transform.rotate(
                angle: level.kind == ActivityKind.guidedDraw ? hop * .08 : 0,
                child: SceneIllustration(
                  scene: level.scene,
                  variant: level.variant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CuratedRewardImage extends StatelessWidget {
  const _CuratedRewardImage({
    required this.asset,
    required this.kind,
    required this.progress,
    required this.still,
  });
  final String asset;
  final ActivityKind kind;
  final double progress;
  final bool still;

  Widget _image() => Image.asset(
    asset,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        const TrailIcon(TrailIconKind.sparkles, size: 88),
  );

  @override
  Widget build(BuildContext context) {
    final arrival = still
        ? 1.0
        : Curves.easeOutCubic.transform((progress / .75).clamp(0.0, 1.0));
    final bounce = still
        ? 0.0
        : math.sin(progress * math.pi * 4) * (1 - progress);
    Widget image = _image();
    if (kind == ActivityKind.missingPuzzle) {
      image = LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            for (var row = 0; row < 2; row++)
              for (var column = 0; column < 2; column++)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      (column == 0 ? -1 : 1) * (1 - arrival) * 28,
                      (row == 0 ? -1 : 1) * (1 - arrival) * 18,
                    ),
                    child: ClipRect(
                      clipper: _QuadrantClipper(row, column),
                      child: _image(),
                    ),
                  ),
                ),
          ],
        ),
      );
    } else if (kind == ActivityKind.connectDots) {
      image = Transform.translate(
        offset: Offset(0, (1 - arrival) * 24),
        child: Opacity(opacity: arrival, child: image),
      );
    } else if (kind == ActivityKind.maze || kind == ActivityKind.ropeTrace) {
      image = Transform.translate(
        offset: Offset((1 - arrival) * -45, 0),
        child: image,
      );
    } else if (kind == ActivityKind.guidedDraw) {
      image = Transform.rotate(
        angle: bounce * .055,
        child: Transform.translate(
          offset: Offset(0, -bounce.abs() * 12),
          child: image,
        ),
      );
    } else if (kind == ActivityKind.hiddenAnimals ||
        kind == ActivityKind.oddFragment) {
      image = Transform.scale(
        scale: .9 + arrival * .1,
        child: Opacity(opacity: arrival, child: image),
      );
    } else if (kind == ActivityKind.matchPairs ||
        kind == ActivityKind.patternSequence) {
      image = Transform.scale(
        scale: still
            ? 1
            : .88 +
                  Curves.easeOutBack.transform(
                        (progress / .65).clamp(0.0, 1.0),
                      ) *
                      .12,
        child: image,
      );
    } else {
      image = Opacity(opacity: arrival, child: image);
    }
    return ExcludeSemantics(
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: image),
    );
  }
}

class _QuadrantClipper extends CustomClipper<Rect> {
  const _QuadrantClipper(this.row, this.column);
  final int row;
  final int column;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    column * size.width / 2,
    row * size.height / 2,
    size.width / 2,
    size.height / 2,
  );
  @override
  bool shouldReclip(_QuadrantClipper oldClipper) =>
      row != oldClipper.row || column != oldClipper.column;
}

class _RewardPainter extends CustomPainter {
  _RewardPainter({
    required this.kind,
    required this.progress,
    required this.accent,
    required this.still,
    required this.aquatic,
  });
  final ActivityKind kind;
  final double progress;
  final Color accent;
  final bool still;
  final bool aquatic;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .55);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * .7,
        height: size.height * .73,
      ),
      Paint()..color = accent.withValues(alpha: .42),
    );
    final random = math.Random(21 + kind.index);
    const colors = [
      AppColors.peach,
      AppColors.green,
      AppColors.yellow,
      Color(0xFFA898D2),
      Color(0xFF72AEC7),
    ];
    for (var index = 0; index < 25; index++) {
      final phase = random.nextDouble();
      final spread = random.nextDouble();
      final t = still ? .65 : progress;
      final angle = (index / 25) * math.pi * 2;
      final radius = size.shortestSide * (.16 + t * (.35 + spread * .25));
      final x = center.dx + math.cos(angle) * radius * 1.25;
      final y = center.dy + math.sin(angle) * radius + (still ? 0 : t * t * 18);
      final alpha = still
          ? .75
          : (1 - math.max(0.0, progress - .72) * 2.7).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase * 5 + t * 3);
      if (index.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -5, 6, 10),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 3 + phase * 2, paint);
      }
      canvas.restore();
    }

    if ((kind == ActivityKind.numberColor || kind == ActivityKind.freeColor) &&
        aquatic) {
      final fountainT = still
          ? .55
          : math.sin(progress * math.pi).clamp(0.0, 1.0);
      final blue = Paint()
        ..color = const Color(0xFF72AEC7)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var index = -2; index <= 2; index++) {
        final path = Path()
          ..moveTo(center.dx - 17, size.height * .44)
          ..quadraticBezierTo(
            center.dx - 17 + index * 8,
            size.height * (.44 - fountainT * .23),
            center.dx - 17 + index * 15,
            size.height * (.44 - fountainT * .17),
          );
        canvas.drawPath(path, blue);
        canvas.drawCircle(
          Offset(
            center.dx - 17 + index * 15,
            size.height * (.44 - fountainT * .17),
          ),
          3,
          Paint()..color = const Color(0xFF72AEC7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RewardPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.still != still ||
      oldDelegate.kind != kind;
}

class _BusArrivalPainter extends CustomPainter {
  _BusArrivalPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 380, size.height / 205);
    final fill = Paint();
    final outline = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 151, 340, 23),
        const Radius.circular(12),
      ),
      fill..color = const Color(0xFFE5E6D8),
    );
    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var x = 28.0; x < 355; x += 21) {
      canvas.drawLine(Offset(x, 163), Offset(x + 10, 163), dash);
    }
    // The school is always visible, so the destination is understandable even
    // with motion disabled or a platform running at a low frame rate.
    final school = RRect.fromRectAndRadius(
      const Rect.fromLTWH(248, 70, 88, 82),
      const Radius.circular(5),
    );
    canvas.drawRRect(school, fill..color = const Color(0xFFEFBB92));
    canvas.drawRRect(school, outline);
    final roof = Path()
      ..moveTo(239, 73)
      ..lineTo(292, 35)
      ..lineTo(345, 73)
      ..close();
    canvas.drawPath(roof, fill..color = AppColors.green);
    canvas.drawPath(roof, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(280, 116, 25, 36),
        const Radius.circular(4),
      ),
      fill..color = AppColors.paper,
    );
    for (final y in [85.0, 111.0]) {
      for (final x in [258.0, 313.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 13, 17),
            const Radius.circular(2),
          ),
          fill..color = AppColors.paper,
        );
      }
    }
    canvas.drawCircle(const Offset(292, 65), 7, fill..color = AppColors.paper);
    canvas.drawLine(
      const Offset(292, 65),
      const Offset(292, 60),
      outline..strokeWidth = 1.5,
    );
    canvas.drawLine(const Offset(292, 65), const Offset(296, 65), outline);
    canvas.drawLine(
      const Offset(335, 70),
      const Offset(335, 25),
      outline..strokeWidth = 2.2,
    );
    final flag = Path()
      ..moveTo(335, 25)
      ..lineTo(356, 31)
      ..lineTo(335, 39)
      ..close();
    canvas.drawPath(flag, fill..color = AppColors.peach);
    // Little round trees keep the composition playful without visual clutter.
    for (final x in [44.0, 224.0]) {
      canvas.drawLine(Offset(x, 107), Offset(x, 151), outline..strokeWidth = 5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 101), width: 31, height: 45),
        fill..color = AppColors.green,
      );
    }
    canvas.save();
    canvas.translate(26 + progress * 149, 109);
    final bus = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 87, 40),
      const Radius.circular(10),
    );
    canvas.drawRRect(bus, fill..color = AppColors.yellow);
    canvas.drawRRect(bus, outline..strokeWidth = 2.2);
    for (final x in [10.0, 31.0, 52.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 7, 15, 15),
          const Radius.circular(4),
        ),
        fill..color = AppColors.blue,
      );
    }
    for (final x in [19.0, 69.0]) {
      canvas.drawCircle(Offset(x, 40), 10, fill..color = AppColors.ink);
      canvas.drawCircle(Offset(x, 40), 4, fill..color = AppColors.paper);
    }
    canvas.drawCircle(const Offset(83, 29), 3, fill..color = AppColors.paper);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BusArrivalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
