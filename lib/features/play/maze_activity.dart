import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/maze_engine.dart';

class MazeActivity extends StatefulWidget {
  const MazeActivity({super.key, required this.config});
  final ActivityConfig config;
  @override
  State<MazeActivity> createState() => _MazeActivityState();
}

class _MazeActivityState extends State<MazeActivity> {
  late MazeNetwork _network;
  late MazeSession _session;
  bool _completedSent = false;
  MazeMove? _message;
  ActivityConfig get config => widget.config;
  String t(String ru, String kk, String en) =>
      textFor(config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant MazeActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != config.level.id ||
        oldWidget.config.ageBand != config.ageBand ||
        oldWidget.config.level.scene != config.level.scene) {
      _initialize();
    }
  }

  void _initialize() {
    _network = MazeNetwork.forLevel(
      levelId: config.level.id,
      scene: config.level.scene,
      ageBand: config.ageBand,
    );
    _session = MazeSession(_network, saved: config.initialData);
    _completedSent = false;
    _message = null;
    final identity = _network.identity;
    final levelId = config.level.id;
    if (_session.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            config.level.id != levelId ||
            _network.identity != identity) {
          return;
        }
        _finishIfNeeded();
      });
    }
  }

  void _finishIfNeeded() {
    if (_session.isComplete && !_completedSent) {
      _completedSent = true;
      config.onCompleted(_session.toJson());
    }
  }

  void _accept(MazeMove move) {
    if (move == MazeMove.ignored) {
      return;
    }
    setState(() => _message = move);
    if (move == MazeMove.arrived ||
        move == MazeMove.completed ||
        move == MazeMove.needsStops) {
      config.onFeedback();
      config.onChanged(_session.toJson());
    }
    if (move == MazeMove.completed) {
      _finishIfNeeded();
    }
  }

  void _tapNode(int node) => _accept(_session.tapNode(node));
  void _undo() {
    setState(() {
      _session.undo();
      _message = null;
      _completedSent = false;
    });
    config.onChanged(_session.toJson());
  }

  void _reset() {
    setState(() {
      _session.reset();
      _message = null;
      _completedSent = false;
    });
    config.onChanged(_session.toJson());
  }

  String get _instruction {
    if (_message == MazeMove.blocked) {
      return t(
        'Здесь ремонт. Найди другой путь!',
        'Мұнда жөндеу. Басқа жолды тап!',
        'Roadworks. Find another way!',
      );
    }
    if (_message == MazeMove.needsStops) {
      return t(
        'Сначала собери оба флажка. Можно ехать дальше!',
        'Алдымен екі жалаушаны жина. Жолды жалғастыр!',
        'Collect both flags first. You can keep going!',
      );
    }
    if (config.ageBand == AgeBand.advanced) {
      return t(
        'Собери оба флажка и доберись до цели. Объезжай ремонт.',
        'Екі жалаушаны жинап, мақсатқа жет. Жөндеуді айналып өт.',
        'Collect both flags, then reach the goal. Avoid roadworks.',
      );
    }
    return _network.scene == 'park'
        ? t(
            'Доберись до пикника: веди по дорожке или нажимай на точки.',
            'Соқпақпен жүр немесе нүктелерді басып, пикникке жет.',
            'Reach the picnic: follow the path or tap the dots.',
          )
        : t(
            'Доставь автобус в школу: веди по дороге или нажимай на точки.',
            'Автобусты жолмен жүргіз немесе нүктелерді басып, мектепке жеткіз.',
            'Take the bus to school: follow the road or tap the dots.',
          );
  }

  Widget _status(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: .48),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _network.scene == 'park'
                ? Icons.park_rounded
                : Icons.directions_bus_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _instruction,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
  Widget _actions(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('maze-undo'),
        onPressed: _session.route.length > 1 ? _undo : null,
        icon: const Icon(Icons.undo_rounded, size: 20),
        label: Text(t('Назад', 'Артқа', 'Undo')),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      OutlinedButton.icon(
        key: const ValueKey('maze-restart'),
        onPressed: _session.route.length > 1 || _session.isDragging
            ? _reset
            : null,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: Text(t('Сначала', 'Қайтадан', 'Restart')),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      if (_network.requiredStops.isNotEmpty)
        Chip(
          avatar: const Icon(Icons.flag_rounded, size: 18),
          label: Text(
            '${_session.collectedStops.length} / ${_network.requiredStops.length}',
          ),
          backgroundColor: AppColors.yellow.withValues(alpha: .35),
          side: BorderSide.none,
        ),
    ],
  );

  Widget _board() => Expanded(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x15304A37),
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GestureDetector(
                  key: const ValueKey('maze-canvas'),
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onTapUp: (details) {
                    final location = details.localPosition / side;
                    final candidates =
                        _network.roads
                            .where(
                              (r) =>
                                  r.a == _session.current ||
                                  r.b == _session.current,
                            )
                            .map((r) => r.other(_session.current))
                            .toList()
                          ..sort(
                            (a, b) => (_network.nodes[a] - location).distance
                                .compareTo(
                                  (_network.nodes[b] - location).distance,
                                ),
                          );
                    if (candidates.isNotEmpty &&
                        (_network.nodes[candidates.first] - location).distance *
                                side <=
                            26) {
                      _tapNode(candidates.first);
                    }
                  },
                  onPanStart: (details) => setState(() {
                    _session.beginDrag(details.localPosition / side);
                  }),
                  onPanUpdate: (details) =>
                      _accept(_session.dragTo(details.localPosition / side)),
                  onPanEnd: (_) => setState(_session.endDrag),
                  onPanCancel: () => setState(_session.endDrag),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          config.level.illustrationAsset ??
                              (_network.scene == 'park'
                                  ? 'assets/images/levels/18-park.png'
                                  : 'assets/images/levels/08-school.png'),
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: MazeArtOverlayPainter(
                              network: _network,
                              route: List.of(_session.route),
                              bus: _session.busPosition,
                              collectedStops: _session.collectedStops,
                              hintRoute: config.showHint
                                  ? _session.hintRoute
                                  : const [],
                              activeRoad: _session.activeRoad,
                              edgeProgress: _session.edgeProgress,
                            ),
                          ),
                        ),
                      ),
                      for (final road in _network.roadsFrom(_session.current))
                        Positioned(
                          left:
                              _network.nodes[road.other(_session.current)].dx *
                                  side -
                              24,
                          top:
                              _network.nodes[road.other(_session.current)].dy *
                                  side -
                              24,
                          width: 48,
                          height: 48,
                          child: Semantics(
                            button: true,
                            label: t(
                              'Следующая точка дороги',
                              'Келесі жол нүктесі',
                              'Next road point',
                            ),
                            child: GestureDetector(
                              key: ValueKey(
                                'maze-node-${road.other(_session.current)}',
                              ),
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _tapNode(road.other(_session.current)),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      Positioned(
                        left: _session.busPosition.dx * side - 17,
                        top: _session.busPosition.dy * side - 17,
                        width: 34,
                        height: 34,
                        child: IgnorePointer(
                          key: const ValueKey('maze-player'),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _network.scene == 'park'
                                  ? Icons.directions_walk_rounded
                                  : Icons.directions_bus_rounded,
                              size: 23,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sideRail =
          constraints.maxWidth >= 620 && constraints.maxHeight <= 450;
      if (sideRail) {
        return Row(
          children: [
            _board(),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _status(context),
                      const SizedBox(height: 12),
                      _actions(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          _status(context),
          _board(),
          const SizedBox(height: 8),
          _actions(context),
        ],
      );
    },
  );
}

/// The ImageGen illustration is the primary artwork. This transparent layer
/// adds only playable corridors, route feedback, construction and checkpoints.
class MazeArtOverlayPainter extends CustomPainter {
  MazeArtOverlayPainter({
    required this.network,
    required this.route,
    required this.bus,
    required this.collectedStops,
    this.hintRoute = const [],
    this.activeRoad,
    this.edgeProgress = 0,
  });
  final MazeNetwork network;
  final List<int> route;
  final Offset bus;
  final Set<int> collectedStops;
  final List<int> hintRoute;
  final MazeRoad? activeRoad;
  final double edgeProgress;
  void _stroke(Canvas c, Path p, Color color, double width) => c.drawPath(
    p,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width,
  );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    for (final road in network.roads) {
      _stroke(canvas, road.path, const Color(0x406F8060), .054);
      _stroke(canvas, road.path, const Color(0xF7FFF7DB), .043);
      _dash(canvas, road.path, const Color(0xFFDED5AE), .003, .012, .018);
    }
    for (var i = 1; i < route.length; i++) {
      final road = network.roadBetween(route[i - 1], route[i]);
      if (road != null) {
        _stroke(canvas, road.path, const Color(0xFF79A988), .012);
      }
    }
    if (activeRoad != null && edgeProgress > 0) {
      final metric = activeRoad!.path.computeMetrics().first;
      final forward = route.last == activeRoad!.a;
      final part = forward
          ? metric.extractPath(0, metric.length * edgeProgress)
          : metric.extractPath(
              metric.length * (1 - edgeProgress),
              metric.length,
            );
      _stroke(canvas, part, const Color(0xFF79A988), .012);
    }
    for (final road in network.roads.where((r) => r.blocked)) {
      _barrier(canvas, road.point(.5), size.width);
    }
    if (hintRoute.length > 1) {
      final road = network.roadBetween(hintRoute[0], hintRoute[1]);
      if (road != null) {
        _dash(canvas, road.path, const Color(0xFFE2A63B), .012, .014, .018);
      }
    }
    for (final road in network.roadsFrom(route.last)) {
      final point = network.nodes[road.other(route.last)];
      canvas.drawCircle(
        point,
        8 / size.width,
        Paint()..color = const Color(0xFFF3FAE6),
      );
      canvas.drawCircle(
        point,
        4 / size.width,
        Paint()..color = const Color(0xFF568365),
      );
    }
    for (final stop in network.requiredStops) {
      _flag(
        canvas,
        network.nodes[stop],
        collectedStops.contains(stop),
        size.width,
      );
    }
    _goal(canvas, network.nodes[network.goal], size.width);
    canvas.restore();
  }

  void _dash(
    Canvas c,
    Path path,
    Color color,
    double width,
    double dash,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += dash + gap) {
        _stroke(
          c,
          metric.extractPath(offset, math.min(offset + dash, metric.length)),
          color,
          width,
        );
      }
    }
  }

  void _barrier(Canvas c, Offset center, double side) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(1 / side);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -7, 32, 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF6C85C),
    );
    for (var x = -12.0; x < 15; x += 9) {
      _stroke(
        c,
        Path()
          ..moveTo(x, -6)
          ..lineTo(x + 6, 6),
        const Color(0xFF9D6845),
        4,
      );
    }
    c.restore();
  }

  void _flag(Canvas c, Offset point, bool collected, double side) {
    c.save();
    c.translate(point.dx, point.dy);
    c.scale(1 / side);
    c.drawCircle(
      Offset.zero,
      12,
      Paint()
        ..color = collected ? const Color(0xFF669471) : const Color(0xFFF4C75F),
    );
    if (collected) {
      _stroke(
        c,
        Path()
          ..moveTo(-5, 0)
          ..lineTo(-1, 4)
          ..lineTo(6, -4),
        Colors.white,
        2.5,
      );
    } else {
      _stroke(
        c,
        Path()
          ..moveTo(-3, 7)
          ..lineTo(-3, -7),
        const Color(0xFF71572B),
        2,
      );
      c.drawPath(
        Path()
          ..moveTo(-2, -7)
          ..lineTo(7, -4)
          ..lineTo(-2, 0)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
    c.restore();
  }

  void _goal(Canvas c, Offset point, double side) {
    c.save();
    c.translate(point.dx, point.dy);
    c.scale(1 / side);
    c.drawCircle(Offset.zero, 11, Paint()..color = const Color(0xFFE8F6DF));
    _stroke(
      c,
      Path()
        ..moveTo(-3, 7)
        ..lineTo(-3, -7),
      const Color(0xFF467A5B),
      2,
    );
    c.drawPath(
      Path()
        ..moveTo(-2, -7)
        ..lineTo(7, -4)
        ..lineTo(-2, 0)
        ..close(),
      Paint()..color = const Color(0xFF467A5B),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant MazeArtOverlayPainter old) =>
      old.network != network ||
      old.bus != bus ||
      old.route.length != route.length ||
      old.collectedStops.length != collectedStops.length ||
      old.hintRoute.length != hintRoute.length ||
      old.edgeProgress != edgeProgress;
}
