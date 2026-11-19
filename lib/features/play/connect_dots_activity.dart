import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/dots_rope_layouts.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/dots_engine.dart';

const dotsCanvasInset = 24.0;

class ConnectDotsActivity extends StatefulWidget {
  const ConnectDotsActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  State<ConnectDotsActivity> createState() => _ConnectDotsActivityState();
}

class _ConnectDotsActivityState extends State<ConnectDotsActivity>
    with SingleTickerProviderStateMixin {
  late DotsLayout _layout;
  late DotsSession _session;
  late AnimationController _pulse;
  final _transform = TransformationController();
  bool _sent = false;
  bool _wrong = false;
  bool _loaded = false;
  bool _failed = false;
  String? _loading;
  ActivityConfig get config => widget.config;
  String t(String ru, String kk, String en) =>
      textFor(config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initialize();
    _motion();
  }

  void _initialize() {
    _layout = DotsLayout.forLevel(config.level, config.ageBand);
    _session = DotsSession(_layout, saved: config.initialData);
    _sent = false;
    _wrong = false;
    _loaded = false;
    _failed = false;
    _loading = null;
    _transform.value = Matrix4.identity();
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
  void didUpdateWidget(covariant ConnectDotsActivity oldWidget) {
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
    _transform.dispose();
    super.dispose();
  }

  void _choose(Offset local, double side) {
    if (!_loaded || _sent) return;
    final before = _session.visited;
    final artSide = side - dotsCanvasInset * 2;
    final point =
        (local - const Offset(dotsCanvasInset, dotsCanvasInset)) / artSide;
    final labels = dotLabelPositions(_layout.points, artSide);
    final selected =
        !_session.complete &&
            (point - labels[_session.expected]).distance <= 26 / artSide
        ? _session.select(_session.expected)
        : _session.selectAt(point, 26 / artSide);
    setState(() => _wrong = !selected && !_session.complete);
    if (_session.visited != before) {
      config.onFeedback();
      config.onChanged(_session.toJson());
      if (_session.complete) _finish();
    }
  }

  void _finish() {
    if (_sent || !_session.complete || !_loaded) return;
    _sent = true;
    config.onCompleted(_session.toJson());
  }

  void _undo() {
    setState(() {
      _session.undo();
      _wrong = false;
      _sent = false;
    });
    config.onChanged(_session.toJson());
  }

  void _reset() {
    setState(() {
      _session.reset();
      _wrong = false;
      _sent = false;
    });
    config.onChanged(_session.toJson());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape =
          constraints.maxWidth > constraints.maxHeight &&
          constraints.maxHeight < 500;
      final status = _status();
      final controls = _controls();
      final board = Expanded(
        child: LayoutBuilder(
          builder: (context, space) {
            final side = math.min(space.maxWidth, space.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 3,
                          child: GestureDetector(
                            key: const ValueKey('dots-canvas'),
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) =>
                                _choose(details.localPosition, side),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      dotsCanvasInset,
                                    ),
                                    child: Image.asset(
                                      _layout.asset,
                                      fit: BoxFit.fill,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: AppColors.paper,
                                          ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _pulse,
                                    builder: (context, _) => CustomPaint(
                                      painter: _DotsPainter(
                                        layout: _layout,
                                        visited: _session.visited,
                                        hint:
                                            config.showHint ||
                                            config.ageBand == AgeBand.preschool,
                                        pulse: _pulse.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: IconButton.filledTonal(
                          tooltip: t(
                            'Увеличить картинку',
                            'Суретті үлкейту',
                            'Zoom the picture',
                          ),
                          onPressed: () {
                            final zoomed =
                                _transform.value.getMaxScaleOnAxis() > 1.1;
                            _transform.value = zoomed
                                ? Matrix4.identity()
                                : (Matrix4.diagonal3Values(1.8, 1.8, 1)
                                    ..setTranslationRaw(
                                      -side * .4,
                                      -side * .4,
                                      0,
                                    ));
                          },
                          icon: const Icon(Icons.zoom_in_rounded),
                        ),
                      ),
                    ],
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
                  Expanded(child: SingleChildScrollView(child: status)),
                  controls,
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        children: [status, const SizedBox(height: 6), board, controls],
      );
    },
  );

  Widget _status() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.scatter_plot_outlined, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _wrong
                    ? t(
                        'Попробуй следующее число',
                        'Келесі санды байқап көр',
                        'Try the next number',
                      )
                    : config.ageBand == AgeBand.preschool
                    ? t(
                        'Нажимай на светящуюся точку',
                        'Жарқыраған нүктені бас',
                        'Tap the glowing dot',
                      )
                    : config.ageBand == AgeBand.advanced
                    ? t(
                        'Считай по ${_layout.labelStep}: найди ${_session.complete ? _layout.label(_layout.points.length - 1) : _layout.label(_session.expected)}',
                        '${_layout.labelStep} қадаммен сана: ${_session.complete ? _layout.label(_layout.points.length - 1) : _layout.label(_session.expected)} санын тап',
                        'Count by ${_layout.labelStep}: find ${_session.complete ? _layout.label(_layout.points.length - 1) : _layout.label(_session.expected)}',
                      )
                    : t(
                        'Соединяй числа по порядку',
                        'Сандарды ретімен қос',
                        'Connect the numbers in order',
                      ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_session.visited}/${_layout.points.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
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

  Widget _controls() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: t('Назад', 'Артқа', 'Undo'),
          onPressed: _session.visited > 0 ? _undo : null,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: t('Сначала', 'Қайтадан', 'Start again'),
          onPressed: _session.visited > 0 ? _reset : null,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
        IconButton(
          tooltip: t(
            'Послушать следующее число',
            'Келесі санды тыңдау',
            'Hear the next number',
          ),
          onPressed: config.onSpeak != null && !_session.complete
              ? () => config.onSpeak?.call(
                  t(
                    'Следующая точка — ${_layout.label(_session.expected)}',
                    'Келесі нүкте — ${_layout.label(_session.expected)}',
                    'The next dot is ${_layout.label(_session.expected)}',
                  ),
                )
              : null,
          icon: const Icon(Icons.volume_up_outlined),
        ),
        Flexible(
          child: Text(
            config.ageBand == AgeBand.advanced
                ? t('Можно увеличить', 'Үлкейтуге болады', 'Pinch to zoom')
                : t('Без спешки', 'Асықпай', 'Take your time'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.layout,
    required this.visited,
    required this.hint,
    required this.pulse,
  });
  final DotsLayout layout;
  final int visited;
  final bool hint;
  final double pulse;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.width - dotsCanvasInset * 2;
    canvas.translate(dotsCanvasInset, dotsCanvasInset);
    canvas.scale(scale, scale);
    canvas.drawPath(
      layout.outline,
      Paint()
        ..color = Colors.white.withValues(
          alpha: .83 * (1 - visited / layout.points.length),
        ),
    );
    if (visited > 1) {
      final path = Path()
        ..moveTo(layout.points.first.dx, layout.points.first.dy);
      for (final point in layout.points.take(visited).skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (visited == layout.points.length) path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 / scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final labels = dotLabelPositions(layout.points, scale);
    for (var index = 0; index < layout.points.length; index++) {
      final anchor = layout.points[index];
      final point = labels[index];
      canvas.drawLine(
        anchor,
        point,
        Paint()
          ..color = AppColors.ink.withValues(alpha: .6)
          ..strokeWidth = 1 / scale,
      );
      canvas.drawCircle(
        anchor,
        3 / scale,
        Paint()..color = index < visited ? AppColors.green : AppColors.ink,
      );
      final active = hint && index == visited;
      if (active) {
        canvas.drawCircle(
          point,
          (22 + pulse * 4) / scale,
          Paint()..color = AppColors.yellow.withValues(alpha: .4 + pulse * .25),
        );
      }
      final completed = index < visited;
      canvas.drawCircle(
        point,
        13 / scale,
        Paint()
          ..color = completed
              ? AppColors.green
              : Colors.white.withValues(alpha: .95),
      );
      canvas.drawCircle(
        point,
        13 / scale,
        Paint()
          ..color = completed ? Colors.white : AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${layout.label(index)}',
          style: TextStyle(
            color: completed ? Colors.white : AppColors.ink,
            fontFamily: 'Nunito',
            fontSize: 12 / scale,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => true;
}
