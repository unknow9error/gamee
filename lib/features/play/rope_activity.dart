import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/dots_rope_layouts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/rope_engine.dart';

const ropeMarkerRadius = 27.0;
const ropeArtworkInset = ropeMarkerRadius;

/// One registration transform for the entire master, motor corridor, markers,
/// and pointer input. Full 54dp targets fit even where a river enters an edge.
Rect ropeArtworkRect(double canvasSide) {
  final inset = math.min(ropeArtworkInset, canvasSide / 2);
  final extent = math.max(0.0, canvasSide - 2 * inset);
  return Rect.fromLTWH(inset, inset, extent, extent);
}

Offset ropeMarkerCenter(Offset normalizedPosition, double canvasSide) {
  final art = ropeArtworkRect(canvasSide);
  return art.topLeft + normalizedPosition * art.width;
}

class RopeActivity extends StatefulWidget {
  const RopeActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  State<RopeActivity> createState() => _RopeActivityState();
}

class _RopeActivityState extends State<RopeActivity>
    with SingleTickerProviderStateMixin {
  late RopeLayout _layout;
  late RopeSession _session;
  late AnimationController _pulse;
  int? _pointer;
  bool _sent = false;
  bool _loaded = false;
  bool _failed = false;
  bool _choiceWrong = false;
  String? _loading;
  ActivityConfig get config => widget.config;
  String t(String ru, String kk, String en) =>
      textFor(config.language, ru, kk, en);
  bool get _river => _layout.routes.length == 1;
  String get _symbolOrder => _session.route.symbols
      .map(
        (symbol) => switch (symbol) {
          'leaf' => t('лист', 'жапырақ', 'leaf'),
          'flower' => t('цветок', 'гүл', 'flower'),
          _ => t('звезда', 'жұлдыз', 'star'),
        },
      )
      .join(' → ');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _initialize();
    _motion();
  }

  void _initialize() {
    _layout = RopeLayout.forLevel(config.level, config.ageBand);
    _session = RopeSession(_layout, saved: config.initialData);
    _sent = false;
    _loaded = false;
    _failed = false;
    _loading = null;
    _pointer = null;
    _choiceWrong = false;
  }

  void _motion() {
    if (config.reducedMotion) {
      _pulse.stop();
      _pulse.value = .5;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    if (_loading == _layout.asset) return;
    final asset = _layout.asset;
    _loading = asset;
    var failed = false;
    precacheImage(
      AssetImage(asset),
      context,
      onError: (_, _) {
        failed = true;
      },
    ).then((_) {
      if (!mounted || _layout.asset != asset) return;
      setState(() {
        _loaded = !failed;
        _failed = failed;
      });
      if (_loaded && _session.complete) _finish();
    });
  }

  @override
  void didUpdateWidget(covariant RopeActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != config.level.id ||
        oldWidget.config.ageBand != config.ageBand) {
      _initialize();
      _load();
    }
    if (oldWidget.config.reducedMotion != config.reducedMotion) _motion();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _accept(RopeMove move) {
    if (move == RopeMove.ignored) return;
    setState(() {});
    if (move != RopeMove.moved) config.onFeedback();
    config.onChanged(_session.toJson());
    if (move == RopeMove.complete) _finish();
  }

  void _finish() {
    if (_sent || !_session.complete || !_loaded) return;
    _sent = true;
    config.onCompleted(_session.toJson());
  }

  void _tap(int checkpoint) {
    if (_loaded && !_sent) _accept(_session.tapCheckpoint(checkpoint));
  }

  void _confirm(String symbol) {
    if (!_loaded || _sent) return;
    final move = _session.confirmWaypoint(symbol);
    setState(() => _choiceWrong = move == RopeMove.ignored);
    _accept(move);
  }

  void _undo() {
    setState(() {
      _session.undo();
      _sent = false;
      _pointer = null;
      _choiceWrong = false;
    });
    config.onChanged(_session.toJson());
  }

  void _reset() {
    setState(() {
      _session.reset();
      _sent = false;
      _pointer = null;
      _choiceWrong = false;
    });
    config.onChanged(_session.toJson());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape =
          constraints.maxWidth > constraints.maxHeight &&
          constraints.maxHeight < 500;
      final board = Expanded(
        child: LayoutBuilder(
          builder: (context, space) {
            final side = math.min(space.maxWidth, space.maxHeight);
            final art = ropeArtworkRect(side);
            final radius = ropeMarkerRadius / art.width;
            final next = _session.nextCheckpoint;
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Listener(
                    key: const ValueKey('rope-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if (!_loaded || _sent || _pointer != null) return;
                      if (_session.begin(
                        (event.localPosition - art.topLeft) / art.width,
                        radius,
                      )) {
                        _pointer = event.pointer;
                      }
                    },
                    onPointerMove: (event) {
                      if (_pointer == event.pointer) {
                        _accept(
                          _session.move(
                            (event.localPosition - art.topLeft) / art.width,
                            radius,
                          ),
                        );
                      }
                    },
                    onPointerUp: (event) {
                      if (_pointer == event.pointer) {
                        _session.end();
                        _pointer = null;
                      }
                    },
                    onPointerCancel: (event) {
                      if (_pointer == event.pointer) {
                        _session.end();
                        _pointer = null;
                      }
                    },
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: AppColors.paper),
                        ),
                        Positioned.fromRect(
                          rect: art,
                          child: Image.asset(
                            _layout.asset,
                            fit: BoxFit.fill,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: AppColors.paper),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) => CustomPaint(
                              painter: _RopePainter(
                                layout: _layout,
                                session: _session,
                                hint: config.showHint,
                                pulse: _pulse.value,
                                river: _river,
                              ),
                            ),
                          ),
                        ),
                        if (config.ageBand == AgeBand.preschool &&
                            !_session.complete &&
                            _loaded)
                          Positioned(
                            left:
                                ropeMarkerCenter(
                                  _session.route.samples[next],
                                  side,
                                ).dx -
                                ropeMarkerRadius,
                            top:
                                ropeMarkerCenter(
                                  _session.route.samples[next],
                                  side,
                                ).dy -
                                ropeMarkerRadius,
                            width: ropeMarkerRadius * 2,
                            height: ropeMarkerRadius * 2,
                            child: Semantics(
                              button: true,
                              label: t(
                                'Следующая остановка',
                                'Келесі аялдама',
                                'Next stop',
                              ),
                              child: GestureDetector(
                                key: ValueKey('rope-checkpoint-$next'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _tap(next),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        if (!_loaded)
                          Positioned.fill(
                            child: ColoredBox(
                              color: AppColors.paper,
                              child: Center(
                                child: _failed
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            t(
                                              'Картинка пока не загрузилась',
                                              'Сурет әлі жүктелмеді',
                                              'The picture has not loaded yet',
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _loading = null;
                                              _failed = false;
                                              _load();
                                            },
                                            child: Text(
                                              t(
                                                'Повторить',
                                                'Қайталау',
                                                'Try again',
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      if (landscape) {
        return Row(
          children: [
            board,
            const SizedBox(width: 12),
            SizedBox(
              width: 214,
              child: Column(
                children: [
                  Expanded(child: SingleChildScrollView(child: _status())),
                  _controls(),
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          _status(compact: constraints.maxHeight < 500),
          const SizedBox(height: 4),
          board,
          _controls(),
        ],
      );
    },
  );

  Widget _status({bool compact = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              _river ? Icons.sailing_outlined : Icons.air_rounded,
              color: AppColors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _river
                    ? t(
                        compact
                            ? 'От старта — к отметке'
                            : 'Проведи лодочку от старта к отметке',
                        compact
                            ? 'Бастау нүктесінен белгіге'
                            : 'Қайықты бастау нүктесінен белгіге дейін жүргіз',
                        compact
                            ? 'From start to the marker'
                            : 'Guide the boat from the start to the marker',
                      )
                    : _session.routeIndex == 0
                    ? t(
                        'От лисёнка — к красному змею',
                        'Түлкіден қызыл батпырауыққа',
                        'From the fox to the red kite',
                      )
                    : t(
                        'От зайчонка — к голубому змею',
                        'Қояннан көк батпырауыққа',
                        'From the rabbit to the blue kite',
                      ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        if (config.ageBand == AgeBand.advanced)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              compact
                  ? _symbolOrder
                  : t(
                      'Собери: $_symbolOrder. Обходи тупик.',
                      'Жина: $_symbolOrder. Тұйық жолдан сақтан.',
                      'Collect: $_symbolOrder. Avoid the dead end.',
                    ),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: _session.progress,
          minHeight: 6,
          color: AppColors.green,
          backgroundColor: AppColors.line,
        ),
      ],
    ),
  );
  Widget _controls() => Column(
    children: [
      if (_session.awaitingSymbol)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Text(
                _choiceWrong
                    ? t(
                        'Посмотри на порядок меток',
                        'Белгілердің ретін қара',
                        'Look at the marker order',
                      )
                    : t(
                        'Какая метка нужна здесь?',
                        'Мұнда қай белгі керек?',
                        'Which marker belongs here?',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final symbol in const ['star', 'leaf', 'flower'])
                    IconButton.filledTonal(
                      key: ValueKey('rope-symbol-$symbol'),
                      tooltip: switch (symbol) {
                        'leaf' => t('Лист', 'Жапырақ', 'Leaf'),
                        'flower' => t('Цветок', 'Гүл', 'Flower'),
                        _ => t('Звезда', 'Жұлдыз', 'Star'),
                      },
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor:
                            config.showHint && symbol == _session.requiredSymbol
                            ? AppColors.yellow
                            : null,
                      ),
                      onPressed: () => _confirm(symbol),
                      icon: Icon(switch (symbol) {
                        'leaf' => Icons.eco_rounded,
                        'flower' => Icons.local_florist_rounded,
                        _ => Icons.star_rounded,
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: t('Назад', 'Артқа', 'Undo'),
              onPressed: _session.progress > 0 ? _undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: t('Сначала', 'Қайтадан', 'Start again'),
              onPressed: _session.progress > 0 ? _reset : null,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            Flexible(
              child: Text(
                config.ageBand == AgeBand.preschool
                    ? t(
                        'Можно нажимать на огоньки',
                        'Жарқыраған белгілерді басуға болады',
                        'You can tap the glowing stops',
                      )
                    : t(
                        'Начни у кружка',
                        'Дөңгелектен баста',
                        'Start at the circle',
                      ),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RopePainter extends CustomPainter {
  _RopePainter({
    required this.layout,
    required this.session,
    required this.hint,
    required this.pulse,
    required this.river,
  });
  final RopeLayout layout;
  final RopeSession session;
  final bool hint;
  final double pulse;
  final bool river;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final art = ropeArtworkRect(size.width);
    if (art.width <= 0) {
      canvas.restore();
      return;
    }
    canvas.translate(art.left, art.top);
    canvas.scale(art.width, art.height);
    final scale = art.width;
    for (var index = 0; index < layout.routes.length; index++) {
      final route = layout.routes[index];
      final done = index < session.completedRoutes;
      final active = index == session.routeIndex;
      if (layout.band == AgeBand.advanced && active) {
        for (final branch in route.branches) {
          _dash(
            canvas,
            branch,
            Paint()
              ..color = AppColors.muted.withValues(alpha: .8)
              ..strokeWidth = 3 / scale
              ..style = PaintingStyle.stroke,
          );
          final endpoint = branch.computeMetrics().single;
          final point = endpoint
              .getTangentForOffset(endpoint.length - .00001)!
              .position;
          canvas.drawCircle(
            point,
            12 / scale,
            Paint()..color = AppColors.peach,
          );
          canvas.drawLine(
            point - Offset(4 / scale, 4 / scale),
            point + Offset(4 / scale, 4 / scale),
            Paint()
              ..color = AppColors.ink
              ..strokeWidth = 2 / scale,
          );
          canvas.drawLine(
            point + Offset(-4 / scale, 4 / scale),
            point + Offset(4 / scale, -4 / scale),
            Paint()
              ..color = AppColors.ink
              ..strokeWidth = 2 / scale,
          );
        }
      }
      if (active && hint) {
        canvas.drawPath(
          route.path,
          Paint()
            ..color = AppColors.yellow.withValues(alpha: .7)
            ..strokeWidth = 16 / scale
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(
        route.path,
        Paint()
          ..color = Colors.white.withValues(alpha: active ? .9 : .4)
          ..strokeWidth = 7 / scale
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      _dash(
        canvas,
        route.path,
        Paint()
          ..color = route.color.withValues(alpha: active ? .75 : .4)
          ..strokeWidth = 2.5 / scale
          ..style = PaintingStyle.stroke,
      );
      final until = done
          ? 160
          : active
          ? session.positionIndex
          : 0;
      if (until > 0) {
        final path = Path()
          ..moveTo(route.samples.first.dx, route.samples.first.dy);
        for (final point in route.samples.take(until + 1).skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = route.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 / scale
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      if (active && !session.complete) {
        final points = session.checkpoints;
        for (var stop = 1; stop < points.length; stop++) {
          final position = route.samples[points[stop]];
          final reached = points[stop] <= session.positionIndex;
          final next = points[stop] == session.nextCheckpoint;
          if (next && layout.band == AgeBand.preschool) {
            canvas.drawCircle(
              position,
              (21 + 4 * pulse) / scale,
              Paint()..color = AppColors.yellow.withValues(alpha: .65),
            );
          }
          canvas.drawCircle(
            position,
            12 / scale,
            Paint()
              ..color = reached
                  ? AppColors.green
                  : Colors.white.withValues(alpha: .93),
          );
          if (layout.band == AgeBand.advanced && stop < points.length - 1) {
            _symbol(
              canvas,
              position,
              route.symbols[stop - 1],
              7 / scale,
              reached ? Colors.white : route.color,
            );
          } else if (stop == points.length - 1) {
            final path = Path()
              ..moveTo(position.dx - 5 / scale, position.dy)
              ..lineTo(position.dx - 1 / scale, position.dy + 5 / scale)
              ..lineTo(position.dx + 6 / scale, position.dy - 5 / scale);
            canvas.drawPath(
              path,
              Paint()
                ..color = reached ? Colors.white : route.color
                ..strokeWidth = 2.5 / scale
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round,
            );
          } else {
            canvas.drawCircle(
              position,
              4 / scale,
              Paint()..color = reached ? Colors.white : route.color,
            );
          }
        }
        final position = session.position;
        canvas.drawCircle(
          position,
          ropeMarkerRadius / scale,
          Paint()..color = route.color.withValues(alpha: .16),
        );
        canvas.drawCircle(position, 19 / scale, Paint()..color = Colors.white);
        canvas.drawCircle(position, 15 / scale, Paint()..color = route.color);
        final arrow = Path()
          ..moveTo(position.dx - 4 / scale, position.dy - 6 / scale)
          ..lineTo(position.dx + 5 / scale, position.dy)
          ..lineTo(position.dx - 4 / scale, position.dy + 6 / scale);
        canvas.drawPath(
          arrow,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3 / scale
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += .035) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + .015, metric.length),
          ),
          paint,
        );
      }
    }
  }

  void _symbol(
    Canvas canvas,
    Offset center,
    String symbol,
    double radius,
    Color color,
  ) {
    final paint = Paint()..color = color;
    if (symbol == 'leaf') {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.7);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 1.2,
          height: radius * 2,
        ),
        paint,
      );
      canvas.restore();
    } else if (symbol == 'flower') {
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .55,
          radius * .48,
          paint,
        );
      }
    } else {
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final angle = i * math.pi / 5 - math.pi / 2;
        final point =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                radius *
                (i.isEven ? 1 : .45);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter oldDelegate) => true;
}
