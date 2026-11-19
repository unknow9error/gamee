import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

/// A first-use explanation that demonstrates the gesture rather than putting
/// a long instruction screen between the child and their first activity.
class ActivityTutorial extends StatefulWidget {
  const ActivityTutorial({
    super.key,
    required this.kind,
    required this.language,
    required this.reducedMotion,
    required this.onDismiss,
    this.ageBand = AgeBand.primary,
    this.level,
  });

  final ActivityKind kind;
  final String language;
  final bool reducedMotion;
  final VoidCallback onDismiss;
  final AgeBand ageBand;
  final LevelDefinition? level;

  @override
  State<ActivityTutorial> createState() => _ActivityTutorialState();
}

class _ActivityTutorialState extends State<ActivityTutorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..addStatusListener(_cycle);
  var _cycles = 0;
  var _started = false;
  var _dismissed = false;

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  bool get _still =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  void _cycle(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        !_still &&
        ++_cycles < 3) {
      _gesture.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _gesture.value = 1;
    } else if (!_started) {
      _started = true;
      _gesture.forward();
    }
  }

  @override
  void dispose() {
    _gesture.dispose();
    super.dispose();
  }

  String _t(String ru, String kk, String en) =>
      textFor(widget.language, ru, kk, en);

  bool get _shapes => widget.level?.activityData['ruleMode'] == 'shapes';
  int get _dotStep => widget.ageBand == AgeBand.advanced
      ? (widget.level?.scene == 'rocket' ? 5 : 2)
      : 1;

  List<String> get _steps {
    final short = widget.ageBand == AgeBand.preschool;
    final older = widget.ageBand == AgeBand.advanced;
    final steps = switch (widget.kind) {
      ActivityKind.numberColor =>
        short
            ? [
                _t('Выбери краску.', 'Бояуды таңда.', 'Pick a color.'),
                _t(
                  'Найди такой же цвет на картинке.',
                  'Суреттен дәл сондай түсті тап.',
                  'Find the matching color in the picture.',
                ),
              ]
            : older
            ? [
                _shapes
                    ? _t(
                        'Определи чётность числа и сравни фигуру.',
                        'Санның жұптығын анықтап, пішінді салыстыр.',
                        'Check the number’s parity and compare the shape.',
                      )
                    : _t(
                        'Реши пример и сравни фигуру.',
                        'Мысалды шешіп, пішінді салыстыр.',
                        'Solve the sum and compare the shape.',
                      ),
                _t(
                  'Выбери краску по двум подсказкам.',
                  'Екі белгіге сәйкес бояуды таңда.',
                  'Choose a color using both clues.',
                ),
                _t(
                  'Раскрась все большие части.',
                  'Барлық үлкен бөлікті боя.',
                  'Color all the large parts.',
                ),
              ]
            : [
                _shapes
                    ? _t(
                        'Выбери цвет со значком.',
                        'Белгісі бар түсті таңда.',
                        'Choose a color with a symbol.',
                      )
                    : _t(
                        'Выбери цвет с числом.',
                        'Саны бар түсті таңда.',
                        'Choose a numbered color.',
                      ),
                _shapes
                    ? _t(
                        'Коснись такой же фигуры.',
                        'Дәл сондай пішінді түрт.',
                        'Tap the matching shape.',
                      )
                    : _t(
                        'Коснись такого же числа.',
                        'Дәл сол санды түрт.',
                        'Tap the matching number.',
                      ),
                _t(
                  'Раскрась все большие части.',
                  'Барлық үлкен бөлікті боя.',
                  'Color all the large parts.',
                ),
              ],
      ActivityKind.freeColor => [
        _t(
          'Выбери любимый цвет.',
          'Сүйікті түсіңді таңда.',
          'Pick a color you love.',
        ),
        _t(
          'Заливай части или рисуй кистью.',
          'Бөліктерді боя немесе қылқаламмен сал.',
          'Fill the shapes or paint with the brush.',
        ),
        _t(
          'Сохрани рисунок, когда будешь готов.',
          'Дайын болғанда суретіңді сақта.',
          'Save your picture when you are ready.',
        ),
      ],
      ActivityKind.oddFragment => [
        _t(
          'Посмотри на картинки.',
          'Суреттерге қара.',
          'Look at the pictures.',
        ),
        _t(
          'Найди ту, которая отличается.',
          'Өзгеше суретті тап.',
          'Find the one that is different.',
        ),
        older
            ? _t(
                'Сравни форму, цвет и направление деталей.',
                'Бөлшектердің пішінін, түсін және бағытын салыстыр.',
                'Compare the shape, color and direction of each detail.',
              )
            : _t(
                'Коснись своего ответа.',
                'Жауабыңды түрт.',
                'Tap your answer.',
              ),
      ],
      ActivityKind.connectDots => [
        short
            ? _t(
                'Коснись светящейся точки.',
                'Жарқыраған нүктені түрт.',
                'Tap the glowing dot.',
              )
            : _t(
                'Найди первую точку.',
                'Бірінші нүктені тап.',
                'Find the first dot.',
              ),
        older
            ? _t(
                'Считай с шагом $_dotStep и соединяй точки.',
                '$_dotStep қадаммен санап, нүктелерді қос.',
                'Count by $_dotStep and connect the dots.',
              )
            : _t(
                'Соединяй точки по порядку.',
                'Нүктелерді ретімен қос.',
                'Connect the dots in order.',
              ),
        _t(
          'Следующая точка подскажет путь.',
          'Келесі нүкте жолды көрсетеді.',
          'The next dot shows you the way.',
        ),
      ],
      ActivityKind.matchPairs => [
        older
            ? _t(
                'Открой картинку и запомни её.',
                'Суретті ашып, есте сақта.',
                'Reveal a picture and remember it.',
              )
            : _t(
                'Выбери одну картинку.',
                'Бір суретті таңда.',
                'Choose a picture.',
              ),
        _t(
          'Найди и выбери её пару.',
          'Оның жұбын тауып, таңда.',
          'Find and choose its match.',
        ),
        older
            ? _t(
                'Открывай по две карточки без спешки.',
                'Асықпай екі картадан аш.',
                'Open two cards at a time. Take your time.',
              )
            : _t('Собери все пары.', 'Барлық жұпты тап.', 'Find every pair.'),
      ],
      ActivityKind.patternSequence => [
        _t(
          'Посмотри на ряд картинок.',
          'Суреттер қатарына қара.',
          'Look at the row of pictures.',
        ),
        _t(
          'Выбери, что будет дальше.',
          'Әрі қарай не болатынын таңда.',
          'Choose what comes next.',
        ),
        older
            ? _t(
                'Найди правило и проверь весь ряд.',
                'Ережені тауып, бүкіл қатарды тексер.',
                'Find the rule and check the whole sequence.',
              )
            : _t(
                'Можно посмотреть на ряд ещё раз.',
                'Қатарға тағы бір қарауға болады.',
                'You can look at the row again.',
              ),
      ],
      ActivityKind.missingPuzzle => [
        _t(
          'Посмотри на пустое место.',
          'Бос орынға қара.',
          'Look at the empty space.',
        ),
        _t(
          'Выбери подходящий кусочек.',
          'Сәйкес бөлікті таңда.',
          'Choose the piece that fits.',
        ),
        _t(
          'Сравни линии и цвета по краям.',
          'Шетіндегі сызықтар мен түстерді салыстыр.',
          'Match the lines and colors around the edges.',
        ),
      ],
      ActivityKind.ropeTrace => [
        _t(
          'Найди начало дорожки.',
          'Жолдың басын тап.',
          'Find the start of the line.',
        ),
        short
            ? _t(
                'Нажимай на огоньки по пути.',
                'Жолдағы жарқыраған белгілерді бас.',
                'Tap the glowing stops along the way.',
              )
            : _t(
                'Проследи по ней до конца.',
                'Оны аяғына дейін қадағала.',
                'Follow it all the way to the end.',
              ),
        older
            ? _t(
                'На остановках выбирай метки по порядку.',
                'Аялдамада белгілерді ретімен таңда.',
                'At each stop, choose the markers in order.',
              )
            : _t(
                'На пересечении оставайся на своей линии.',
                'Қиылыста өз сызығыңнан шықпа.',
                'At a crossing, stay on your own line.',
              ),
      ],
      ActivityKind.maze => [
        _t(
          'Начни у своего героя.',
          'Кейіпкеріңнен баста.',
          'Start beside your character.',
        ),
        _t(
          'Веди его по открытой дорожке.',
          'Оны ашық жолмен жүргіз.',
          'Guide them along the open path.',
        ),
        _t(
          'Обходи преграды и доберись до цели.',
          'Кедергілерді айналып өтіп, мақсатқа жет.',
          'Go around obstacles and reach the goal.',
        ),
      ],
      ActivityKind.guidedDraw => [
        short
            ? _t(
                'Нажимай на светящиеся кружки.',
                'Жарқыраған шеңберлерді бас.',
                'Tap the glowing circles.',
              )
            : _t(
                'Обведи светлую линию.',
                'Ашық түсті сызықты бастыр.',
                'Trace the pale line.',
              ),
        _t(
          'Добавляй части по шагам.',
          'Бөліктерді қадамдап қос.',
          'Add the parts one step at a time.',
        ),
        _t(
          'Потом добавь свои детали.',
          'Содан кейін өзіңше толықтыр.',
          'Then add your own details.',
        ),
      ],
      ActivityKind.hiddenAnimals => [
        older
            ? _t(
                'Рассмотри фрагмент на карточке.',
                'Картадағы бөлікті мұқият қара.',
                'Look closely at the fragment on the card.',
              )
            : _t(
                'Посмотри на маленькую карточку.',
                'Кішкентай картаға қара.',
                'Look at the little card.',
              ),
        _t(
          'Коснись такого же друга на большой картинке.',
          'Үлкен суреттен дәл сондай досыңды түрт.',
          'Tap the matching friend in the big picture.',
        ),
        older
            ? _t(
                'Картинку можно приблизить двумя пальцами.',
                'Суретті екі саусақпен үлкейтуге болады.',
                'You can zoom in with two fingers.',
              )
            : _t(
                'Затем найди друга с новой карточки.',
                'Содан кейін жаңа картадағы досыңды тап.',
                'Then find the friend on the next card.',
              ),
      ],
    };
    return short ? steps.take(2).toList(growable: false) : steps;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.ageBand == AgeBand.preschool
                      ? _t(
                          'Смотри и повторяй',
                          'Қара да, қайтала',
                          'Watch and try',
                        )
                      : widget.ageBand == AgeBand.advanced
                      ? _t(
                          'Как это работает',
                          'Бұл қалай жасалады',
                          'How it works',
                        )
                      : _t(
                          'Давай попробуем!',
                          'Бірге жасап көрейік!',
                          'Let’s give it a try!',
                        ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  activityName(widget.kind, widget.language),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: SizedBox(
                    height: 165,
                    child: AnimatedBuilder(
                      animation: _gesture,
                      builder: (context, _) => CustomPaint(
                        painter: _TutorialPainter(
                          kind: widget.kind,
                          progress: _gesture.value,
                          still: _still,
                          shapes: _shapes,
                          ageBand: widget.ageBand,
                          language: widget.language,
                          dotStep: _dotStep,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._steps.indexed.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.lime,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${step.$1 + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              step.$2,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Без спешки. Можно пробовать снова.',
                    'Асықпа. Қайта байқап көруге болады.',
                    'Take your time. You can try again.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _t('Начать играть', 'Ойынды бастау', 'Let’s play'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialPainter extends CustomPainter {
  _TutorialPainter({
    required this.kind,
    required this.progress,
    required this.still,
    required this.shapes,
    required this.ageBand,
    required this.language,
    required this.dotStep,
  });
  final bool shapes;
  final AgeBand ageBand;
  final String language;
  final int dotStep;
  final ActivityKind kind;
  final double progress;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 340, size.height / 165);
    canvas.translate(
      (size.width - 340 * scale) / 2,
      (size.height - 165 * scale) / 2,
    );
    canvas.scale(scale);
    final fill = Paint();
    final outline = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 340, 165),
        const Radius.circular(24),
      ),
      fill..color = const Color(0xFFF0F3E8),
    );
    final t = still
        ? 1.0
        : Curves.easeInOutCubic.transform((progress / .8).clamp(0.0, 1.0));
    Offset pointer;

    switch (kind) {
      case ActivityKind.oddFragment:
        for (var i = 0; i < 3; i++) {
          final rect = Rect.fromLTWH(41 + i * 91, 43, 76, 76);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(16)),
            fill..color = Colors.white,
          );
          canvas.save();
          canvas.clipRRect(
            RRect.fromRectAndRadius(rect.deflate(8), const Radius.circular(10)),
          );
          if (i == 2) {
            for (var n = 0; n < 6; n++) {
              canvas.drawCircle(
                Offset(
                  rect.left + 20 + (n % 2) * 30,
                  rect.top + 17 + (n ~/ 2) * 20,
                ),
                6,
                fill..color = AppColors.ink,
              );
            }
          } else {
            for (var x = rect.left - 30; x < rect.right + 30; x += 18) {
              canvas.drawLine(
                Offset(x, rect.bottom),
                Offset(x + 37, rect.top),
                outline
                  ..color = AppColors.ink
                  ..strokeWidth = 6,
              );
            }
          }
          canvas.restore();
          if (i == 2 && t > .55) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                rect.inflate(3),
                const Radius.circular(19),
              ),
              outline
                ..color = AppColors.green
                ..strokeWidth = 3,
            );
          }
        }
        pointer = Offset.lerp(const Offset(76, 135), const Offset(261, 82), t)!;
      case ActivityKind.connectDots:
        const dots = [
          Offset(76, 116),
          Offset(107, 77),
          Offset(146, 54),
          Offset(194, 43),
          Offset(233, 67),
          Offset(260, 111),
          Offset(201, 124),
          Offset(137, 129),
        ];
        final route = Path()..moveTo(dots.first.dx, dots.first.dy);
        for (final dot in dots.skip(1)) {
          route.lineTo(dot.dx, dot.dy);
        }
        final metric = route.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * t),
          outline
            ..color = AppColors.green
            ..strokeWidth = 4,
        );
        final reached = (t * (dots.length - 1)).floor();
        for (var i = 0; i < dots.length; i++) {
          canvas.drawCircle(
            dots[i],
            7,
            fill..color = i <= reached ? AppColors.green : Colors.white,
          );
          canvas.drawCircle(
            dots[i],
            7,
            outline
              ..color = AppColors.green
              ..strokeWidth = 2,
          );
          if (ageBand != AgeBand.preschool) {
            _label(
              canvas,
              '${(i + 1) * dotStep}',
              dots[i] + const Offset(0, -18),
              12,
            );
          }
          if (ageBand == AgeBand.preschool && i == reached + 1) {
            canvas.drawCircle(
              dots[i],
              12,
              Paint()..color = AppColors.yellow.withValues(alpha: .45),
            );
          }
        }
        pointer = metric.getTangentForOffset(metric.length * t)!.position;
      case ActivityKind.matchPairs:
        for (var i = 0; i < 4; i++) {
          final center = Offset(77 + (i % 2) * 182, 48 + (i ~/ 2) * 72);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: 73, height: 56),
              const Radius.circular(13),
            ),
            fill..color = Colors.white,
          );
          final sock = Path()
            ..moveTo(center.dx - 8, center.dy - 18)
            ..lineTo(center.dx + 8, center.dy - 18)
            ..lineTo(center.dx + 8, center.dy + 4)
            ..quadraticBezierTo(
              center.dx + 28,
              center.dy + 17,
              center.dx + 12,
              center.dy + 19,
            )
            ..lineTo(center.dx - 8, center.dy + 19)
            ..close();
          canvas.drawPath(
            sock,
            fill..color = i == 0 || i == 3 ? AppColors.peach : AppColors.blue,
          );
          canvas.drawPath(
            sock,
            outline
              ..color = AppColors.ink
              ..strokeWidth = 1.7,
          );
          if (ageBand == AgeBand.advanced &&
              !(i == 0 && t > .2) &&
              !(i == 3 && t > .7)) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: center, width: 73, height: 56),
                const Radius.circular(13),
              ),
              fill..color = AppColors.lavender,
            );
            _label(canvas, '?', center, 22);
          }
          if ((i == 0 || i == 3) && t > .7) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: center, width: 78, height: 61),
                const Radius.circular(16),
              ),
              outline
                ..color = AppColors.green
                ..strokeWidth = 2.5,
            );
          }
        }
        final line = Path()
          ..moveTo(118, 48)
          ..cubicTo(153, 48, 183, 120, 218, 120);
        final metric = line.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * t),
          outline
            ..color = AppColors.green
            ..strokeWidth = 3,
        );
        pointer = Offset.lerp(const Offset(77, 48), const Offset(259, 120), t)!;
      case ActivityKind.patternSequence:
        for (var i = 0; i < 4; i++) {
          final center = Offset(74 + i * 64, 55);
          final chosen = i < 3 || t > .6;
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 34, height: 43),
            fill
              ..color = !chosen
                  ? Colors.white
                  : i.isEven
                  ? AppColors.peach
                  : AppColors.blue,
          );
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 34, height: 43),
            outline
              ..color = AppColors.ink
              ..strokeWidth = 2,
          );
          canvas.drawLine(
            center + const Offset(0, 22),
            center + const Offset(0, 37),
            outline,
          );
          if (!chosen) _label(canvas, '?', center, 21);
        }
        for (var i = 0; i < 3; i++) {
          final center = Offset(100 + i * 70, 132);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: center, width: 51, height: 40),
              const Radius.circular(12),
            ),
            fill..color = Colors.white,
          );
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 20, height: 26),
            fill
              ..color = [
                AppColors.peach,
                AppColors.blue,
                AppColors.lavender,
              ][i],
          );
        }
        pointer = Offset.lerp(
          const Offset(278, 55),
          const Offset(170, 132),
          t,
        )!;
      case ActivityKind.missingPuzzle:
        const picture = Rect.fromLTWH(43, 24, 141, 117);
        canvas.drawRRect(
          RRect.fromRectAndRadius(picture, const Radius.circular(15)),
          fill..color = AppColors.blue,
        );
        final hill = Path()
          ..moveTo(43, 125)
          ..quadraticBezierTo(91, 64, 142, 109)
          ..quadraticBezierTo(164, 79, 184, 107)
          ..lineTo(184, 141)
          ..lineTo(43, 141)
          ..close();
        canvas.drawPath(hill, fill..color = AppColors.lime);
        canvas.drawCircle(
          const Offset(76, 51),
          15,
          fill..color = AppColors.yellow,
        );
        const hole = Rect.fromLTWH(117, 69, 50, 49);
        canvas.drawRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(7)),
          fill..color = t > .65 ? AppColors.lime : Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(7)),
          outline
            ..color = AppColors.ink
            ..strokeWidth = 2,
        );
        for (var i = 0; i < 3; i++) {
          final piece = Rect.fromLTWH(228, 21 + i * 46, 58, 37);
          canvas.drawRRect(
            RRect.fromRectAndRadius(piece, const Radius.circular(9)),
            fill
              ..color = [
                AppColors.peach,
                AppColors.lime,
                AppColors.lavender,
              ][i],
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(piece, const Radius.circular(9)),
            outline
              ..color = i == 1 && t > .6 ? AppColors.green : AppColors.line
              ..strokeWidth = 2,
          );
        }
        pointer = Offset.lerp(const Offset(142, 93), const Offset(257, 85), t)!;
      case ActivityKind.ropeTrace:
        final routes = [
          Path()
            ..moveTo(65, 29)
            ..cubicTo(300, 39, 30, 122, 266, 141),
          Path()
            ..moveTo(167, 29)
            ..cubicTo(28, 50, 298, 106, 63, 141),
          Path()
            ..moveTo(271, 29)
            ..cubicTo(110, 62, 230, 103, 165, 141),
        ];
        const colors = [AppColors.peach, AppColors.lavender, AppColors.blue];
        for (var i = 0; i < routes.length; i++) {
          canvas.drawPath(
            routes[i],
            outline
              ..color = colors[i]
              ..strokeWidth = 5,
          );
          final start = routes[i]
              .computeMetrics()
              .first
              .getTangentForOffset(0)!
              .position;
          final kite = Path()
            ..moveTo(start.dx, start.dy - 18)
            ..lineTo(start.dx + 12, start.dy - 6)
            ..lineTo(start.dx, start.dy + 6)
            ..lineTo(start.dx - 12, start.dy - 6)
            ..close();
          canvas.drawPath(kite, fill..color = colors[i]);
          canvas.drawPath(
            kite,
            outline
              ..color = AppColors.ink
              ..strokeWidth = 1.8,
          );
        }
        final active = routes.first.computeMetrics().first;
        canvas.drawPath(
          active.extractPath(0, active.length * t),
          outline
            ..color = AppColors.green
            ..strokeWidth = 3.5,
        );
        pointer = active.getTangentForOffset(active.length * t)!.position;
      case ActivityKind.maze:
        final road = Path()
          ..moveTo(45, 122)
          ..lineTo(125, 122)
          ..quadraticBezierTo(150, 122, 150, 97)
          ..lineTo(150, 69)
          ..quadraticBezierTo(150, 47, 174, 47)
          ..lineTo(275, 47);
        canvas.drawPath(
          road,
          outline
            ..strokeWidth = 26
            ..color = Colors.white,
        );
        canvas.drawPath(
          road,
          outline
            ..strokeWidth = 2.5
            ..color = AppColors.line,
        );
        final branch = Path()
          ..moveTo(150, 97)
          ..lineTo(245, 97);
        canvas.drawPath(
          branch,
          outline
            ..strokeWidth = 20
            ..color = Colors.white,
        );
        final blocked = RRect.fromRectAndRadius(
          const Rect.fromLTWH(204, 85, 12, 26),
          const Radius.circular(2),
        );
        canvas.drawRRect(blocked, fill..color = AppColors.peach);
        for (var y = 88.0; y < 108; y += 7) {
          canvas.drawLine(
            Offset(205, y),
            Offset(215, y + 4),
            outline
              ..strokeWidth = 3
              ..color = AppColors.ink,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(270, 28, 35, 39),
            const Radius.circular(4),
          ),
          fill..color = AppColors.peach,
        );
        canvas.drawPath(
          Path()
            ..moveTo(265, 28)
            ..lineTo(287, 13)
            ..lineTo(309, 28)
            ..close(),
          fill..color = AppColors.green,
        );
        canvas.drawRect(
          const Rect.fromLTWH(283, 46, 10, 21),
          fill..color = AppColors.paper,
        );
        final metric = road.computeMetrics().first;
        pointer = metric.getTangentForOffset(metric.length * t)!.position;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pointer, width: 30, height: 20),
            const Radius.circular(5),
          ),
          fill..color = AppColors.yellow,
        );
        for (final offset in [-9.0, 9.0]) {
          canvas.drawCircle(
            pointer + Offset(offset, 11),
            4,
            fill..color = AppColors.ink,
          );
        }
      case ActivityKind.guidedDraw:
        final duck = Path()
          ..moveTo(132, 79)
          ..cubicTo(100, 25, 179, 4, 186, 52)
          ..cubicTo(189, 72, 174, 83, 168, 89)
          ..cubicTo(207, 102, 237, 89, 244, 87)
          ..cubicTo(243, 133, 166, 151, 141, 111)
          ..cubicTo(135, 102, 133, 88, 132, 79);
        canvas.drawPath(
          duck,
          outline
            ..color = AppColors.muted.withValues(alpha: .3)
            ..strokeWidth = 4,
        );
        final metric = duck.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * t),
          outline
            ..color = AppColors.green
            ..strokeWidth = 4,
        );
        canvas.drawCircle(
          const Offset(164, 49),
          3.5,
          fill..color = AppColors.ink,
        );
        final beak = Path()
          ..moveTo(131, 58)
          ..quadraticBezierTo(108, 61, 120, 70)
          ..lineTo(134, 68);
        canvas.drawPath(
          beak,
          outline
            ..color = AppColors.peach
            ..strokeWidth = 4,
        );
        if (ageBand == AgeBand.preschool) {
          for (var index = 0; index <= 8; index++) {
            final point = metric
                .getTangentForOffset(metric.length * index / 8)!
                .position;
            canvas.drawCircle(
              point,
              4.5,
              fill
                ..color = index <= (t * 8).floor()
                    ? AppColors.green
                    : AppColors.peach,
            );
          }
        }
        pointer = metric
            .getTangentForOffset(
              metric.length *
                  (ageBand == AgeBand.preschool ? (t * 8).floor() / 8 : t),
            )!
            .position;
      case ActivityKind.hiddenAnimals:
        final scene = RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 18, 205, 130),
          const Radius.circular(17),
        );
        canvas.drawRRect(scene, fill..color = const Color(0xFFDFEACD));
        for (final tree in [const Offset(55, 69), const Offset(190, 53)]) {
          canvas.drawLine(
            tree,
            tree + const Offset(0, 65),
            outline
              ..color = AppColors.green
              ..strokeWidth = 6,
          );
          canvas.drawOval(
            Rect.fromCenter(center: tree, width: 53, height: 70),
            fill..color = AppColors.green.withValues(alpha: .55),
          );
        }
        _hiddenDog(canvas, const Offset(123, 84), 1.0);
        final leaf = Path()
          ..moveTo(57, 143)
          ..quadraticBezierTo(56, 108, 79, 105)
          ..quadraticBezierTo(111, 113, 105, 145)
          ..close();
        canvas.drawPath(leaf, fill..color = const Color(0xFF9ABA7A));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(251, 41, 65, 81),
            const Radius.circular(14),
          ),
          fill..color = Colors.white,
        );
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(256, 46, 55, 71),
            const Radius.circular(10),
          ),
        );
        _hiddenDog(
          canvas,
          ageBand == AgeBand.advanced
              ? const Offset(283, 92)
              : const Offset(283, 78),
          ageBand == AgeBand.advanced ? 1.45 : .64,
        );
        canvas.restore();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(251, 41, 65, 81),
            const Radius.circular(14),
          ),
          outline
            ..color = AppColors.green
            ..strokeWidth = 2.5,
        );
        if (t > .6) {
          canvas.drawOval(
            const Rect.fromLTWH(93, 51, 63, 81),
            outline
              ..color = AppColors.green
              ..strokeWidth = 3,
          );
        }
        pointer = Offset.lerp(const Offset(283, 80), const Offset(123, 83), t)!;
      case ActivityKind.numberColor:
      case ActivityKind.freeColor:
        final petal = Path()
          ..moveTo(193, 92)
          ..cubicTo(147, 115, 122, 80, 145, 57)
          ..cubicTo(151, 24, 192, 31, 193, 67)
          ..cubicTo(203, 24, 245, 32, 243, 64)
          ..cubicTo(276, 71, 257, 111, 218, 98)
          ..cubicTo(242, 123, 203, 145, 193, 112)
          ..cubicTo(175, 143, 142, 121, 169, 99)
          ..close();
        canvas.drawPath(
          petal,
          fill..color = t > .6 ? AppColors.peach : Colors.white,
        );
        canvas.drawPath(
          petal,
          outline
            ..color = AppColors.ink
            ..strokeWidth = 2.5,
        );
        canvas.drawCircle(
          const Offset(196, 87),
          15,
          fill..color = AppColors.yellow,
        );
        canvas.drawCircle(const Offset(196, 87), 15, outline);
        for (var index = 0; index < 3; index++) {
          final color = [
            AppColors.peach,
            AppColors.lavender,
            AppColors.blue,
          ][index];
          canvas.drawCircle(
            Offset(63, 45 + index * 39),
            15,
            fill..color = color,
          );
          if (kind == ActivityKind.numberColor &&
              ageBand != AgeBand.preschool) {
            if (ageBand == AgeBand.advanced) {
              final marker = shapes
                  ? [
                      textFor(language, 'Чёт', 'Жұп', 'Even'),
                      textFor(language, 'Нечёт', 'Тақ', 'Odd'),
                      textFor(language, 'Чёт', 'Жұп', 'Even'),
                    ][index]
                  : ['6', '6', '8'][index];
              _label(canvas, marker, Offset(99, 45 + index * 39), 11);
              _shape(
                canvas,
                index == 1 && !shapes || index == 2 && shapes ? 1 : 2,
                Offset(130, 45 + index * 39),
                11,
              );
            } else {
              if (shapes) {
                _shape(canvas, index, Offset(63, 45 + index * 39), 11);
              } else {
                _label(canvas, '${index + 6}', Offset(63, 45 + index * 39), 15);
              }
            }
          }
        }
        if (kind == ActivityKind.numberColor && t <= .6) {
          if (ageBand == AgeBand.preschool) {
            canvas.drawCircle(
              const Offset(166, 59),
              6,
              fill..color = AppColors.peach,
            );
          } else if (ageBand == AgeBand.advanced) {
            _label(canvas, shapes ? '6' : '2+4', const Offset(160, 59), 12);
            _shape(canvas, 2, const Offset(187, 59), 10);
          } else {
            if (shapes) {
              _shape(canvas, 0, const Offset(167, 59), 11);
            } else {
              _label(canvas, '6', const Offset(167, 59), 18);
            }
          }
        }
        pointer = Offset.lerp(
          const Offset(63, 45),
          const Offset(167, 66),
          (t / .65).clamp(0.0, 1.0),
        )!;
    }
    // A light touch ring communicates the tap without relying on color alone.
    final ring = still
        ? 1.0
        : .65 + math.sin(progress * math.pi * 4).abs() * .35;
    canvas.drawCircle(
      pointer,
      16 * ring,
      fill..color = AppColors.green.withValues(alpha: .12),
    );
    canvas.drawCircle(pointer, 8, fill..color = AppColors.paper);
    canvas.drawCircle(
      pointer,
      8,
      outline
        ..color = AppColors.green
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      pointer + const Offset(4, 5),
      pointer + const Offset(14, 18),
      outline
        ..strokeWidth = 5
        ..color = AppColors.paper,
    );
    canvas.drawLine(
      pointer + const Offset(4, 5),
      pointer + const Offset(14, 18),
      outline
        ..strokeWidth = 2
        ..color = AppColors.green,
    );
    canvas.restore();
  }

  void _hiddenDog(Canvas canvas, Offset center, double scale) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final fill = Paint()..color = AppColors.peach;
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(const Rect.fromLTWH(-20, 7, 40, 38), fill);
    canvas.drawOval(const Rect.fromLTWH(-20, 7, 40, 38), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-21, -29, 42, 40),
        const Radius.circular(16),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-21, -29, 42, 40),
        const Radius.circular(16),
      ),
      line,
    );
    for (final sign in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(sign * 17, -25)
        ..quadraticBezierTo(sign * 41, -19, sign * 27, 3)
        ..quadraticBezierTo(sign * 21, -3, sign * 17, -25)
        ..close();
      canvas.drawPath(ear, Paint()..color = const Color(0xFFD49873));
      canvas.drawPath(ear, line);
      canvas.drawCircle(
        Offset(sign * 8, -10),
        2.6,
        Paint()..color = AppColors.ink,
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(-7, -3, 14, 10),
      Paint()..color = AppColors.paper,
    );
    canvas.drawCircle(const Offset(0, -1), 3, Paint()..color = AppColors.ink);
    final mouth = Path()
      ..moveTo(0, 1)
      ..quadraticBezierTo(0, 9, 7, 5);
    canvas.drawPath(mouth, line..strokeWidth = 1.6);
    canvas.restore();
  }

  void _shape(Canvas canvas, int kind, Offset center, double size) {
    final paint = Paint()..color = AppColors.ink;
    final half = size / 2;
    switch (kind) {
      case 0:
        canvas.drawCircle(center, half, paint);
      case 1:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: size, height: size),
          paint,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - half)
            ..lineTo(center.dx + half, center.dy + half)
            ..lineTo(center.dx - half, center.dy + half)
            ..close(),
          paint,
        );
    }
  }

  void _label(Canvas canvas, String text, Offset center, double fontSize) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.ink,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    label.dispose();
  }

  @override
  bool shouldRepaint(_TutorialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.kind != kind ||
      oldDelegate.still != still ||
      oldDelegate.shapes != shapes ||
      oldDelegate.ageBand != ageBand ||
      oldDelegate.language != language ||
      oldDelegate.dotStep != dotStep;
}
