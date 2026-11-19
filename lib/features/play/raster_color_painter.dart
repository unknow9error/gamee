import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'engines/raster_color_document.dart';
import 'engines/raster_color_spec.dart';

/// Paints unchanged source art and reviewed interior masks. A correct answer
/// reveals source pixels; it never approximates the generated picture in code.
class RasterColorPainter extends CustomPainter {
  static final Map<(ColorSceneSpec, AgeBand, Size, String), _CluePlacement>
  _placements = {};
  const RasterColorPainter({
    required this.image,
    required this.spec,
    required this.ageBand,
    required this.fills,
    required this.strokes,
    this.creative = false,
    this.showClues = true,
    this.hintRegionId,
    this.debugRegions = false,
    this.focusedRegionId,
  });
  final ui.Image image;
  final ColorSceneSpec spec;
  final AgeBand ageBand;
  final Map<String, String> fills;
  final List<ColorPaintStroke> strokes;
  final bool creative;
  final bool showClues;
  final String? hintRegionId;
  final bool debugRegions;
  final String? focusedRegionId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final regions = creative ? spec.regions : spec.regionsFor(ageBand);
    final activeCallout = showClues && !creative ? _activeCallout(size) : null;
    canvas.save();
    canvas.scale(size.width, size.height);
    for (final region in regions) {
      final selected = fills[region.id];
      if (selected == region.paletteId) continue;
      final color = selected == null
          ? const Color(0xFFFFFDF8)
          : spec.paletteById(selected).color;
      canvas.drawPath(region.path, Paint()..color = color);
    }
    if (strokes.isNotEmpty) {
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 1, 1), Paint());
      for (final stroke in strokes) {
        if (stroke.points.isEmpty) continue;
        canvas.save();
        if (stroke.clipRegionId != null) {
          canvas.clipPath(spec.regionById(stroke.clipRegionId!).path);
        } else {
          final interiors = Path()..fillType = PathFillType.evenOdd;
          for (final region in spec.regions) {
            interiors.addPath(region.path, Offset.zero);
          }
          canvas.clipPath(interiors);
        }
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.normalizedWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver;
        if (stroke.points.length == 1) {
          canvas.drawCircle(
            stroke.points.single,
            stroke.normalizedWidth / 2,
            paint..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()
            ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (final point in stroke.points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, paint);
        }
        canvas.restore();
      }
      canvas.restore();
    }
    if (hintRegionId != null) {
      canvas.drawPath(
        spec.regionById(hintRegionId!).path,
        Paint()
          ..color = const Color(0xFF467A5B).withValues(alpha: .78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 / size.shortestSide,
      );
    }
    if (activeCallout != null) {
      canvas.drawPath(
        spec.regionById(activeCallout).path,
        Paint()
          ..color = const Color(0xFF467A5B).withValues(alpha: .78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / size.shortestSide,
      );
    }
    if (debugRegions) {
      for (var i = 0; i < spec.regions.length; i++) {
        canvas.drawPath(
          spec.regions[i].path,
          Paint()
            ..color = Colors.primaries[i % Colors.primaries.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 / size.shortestSide,
        );
      }
    }
    canvas.restore();
    if (showClues && !creative) {
      for (final region in regions) {
        if (!fills.containsKey(region.id) &&
            (!_placement(size, region).callout || activeCallout == region.id)) {
          _clue(canvas, size, region);
        }
      }
    }
    if (debugRegions) {
      for (var i = 0; i < spec.regions.length; i++) {
        final p = spec.regions[i].anchor;
        _text(
          canvas,
          '${i + 1}',
          Offset(p.dx * size.width, p.dy * size.height),
          14,
          background: Colors.white,
        );
      }
    }
    canvas.restore();
  }

  void _clue(Canvas canvas, Size size, ColorRegionSpec region) {
    final placement = _placement(size, region);
    final point = placement.point;
    final font = placement.font;
    if (placement.callout) {
      final badge = placement.bounds.shift(point).inflate(1.5);
      final target = Offset(
        region.anchor.dx * size.width,
        region.anchor.dy * size.height,
      );
      canvas.drawLine(
        badge.center,
        target,
        Paint()
          ..color = const Color(0xFF467A5B)
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(target, 3, Paint()..color = const Color(0xFF467A5B));
      canvas.drawRRect(
        RRect.fromRectAndRadius(badge, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFFFDF8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(badge, const Radius.circular(8)),
        Paint()
          ..color = const Color(0xFF467A5B)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }
    final mode = spec.ruleFor(ageBand).mode;
    switch (mode) {
      case ColorRuleMode.color:
        drawColorSymbol(
          canvas,
          point,
          font * 1.3,
          spec.paletteById(region.paletteId).symbol,
          spec.paletteById(region.paletteId).color,
        );
      case ColorRuleMode.number:
        _text(canvas, '${region.value}', point, font);
      case ColorRuleMode.shape:
        drawColorSymbol(
          canvas,
          point,
          font * 1.25,
          region.symbol,
          const Color(0xFF293F39),
        );
      case ColorRuleMode.numberAndShape:
        final value = region.advancedValue;
        final expression = value.isEven
            ? '${value ~/ 2}+${value ~/ 2}'
            : '${value + 4}−4';
        _text(canvas, expression, point - Offset(font * .55, 0), font * .8);
        drawColorSymbol(
          canvas,
          point + Offset(font * 1.15, 0),
          font * .85,
          region.advancedSymbol,
          const Color(0xFF293F39),
        );
      case ColorRuleMode.parityAndShape:
        _text(
          canvas,
          '${region.advancedValue}',
          point - Offset(font * .55, 0),
          font * .9,
        );
        drawColorSymbol(
          canvas,
          point + Offset(font * .8, 0),
          font * .9,
          region.advancedSymbol,
          const Color(0xFF293F39),
        );
    }
  }

  /// These rectangles use the same measured glyphs as painting. They also make
  /// it possible to verify label placement over the final masks in visual QA.
  Map<String, Rect> clueBounds(Size size) => Map.unmodifiable({
    for (final region in spec.regionsFor(ageBand))
      region.id: _placement(
        size,
        region,
      ).bounds.shift(_placement(size, region).point),
  });

  Map<String, ColorClueLayout> clueLayouts(Size size) => Map.unmodifiable({
    for (final region in spec.regionsFor(ageBand))
      region.id: ColorClueLayout(
        regionId: region.id,
        bounds: _placement(
          size,
          region,
        ).bounds.shift(_placement(size, region).point),
        badgeBounds: _placement(size, region).callout
            ? _placement(
                size,
                region,
              ).bounds.shift(_placement(size, region).point).inflate(1.5)
            : null,
        leaderTarget: Offset(
          region.anchor.dx * size.width,
          region.anchor.dy * size.height,
        ),
        fontSize: _placement(size, region).font,
      ),
  });
  Map<String, ColorClueLayout> visibleClueLayouts(Size size) {
    final active = _activeCallout(size);
    return Map.unmodifiable({
      for (final entry in clueLayouts(size).entries)
        if (!fills.containsKey(entry.key) &&
            (!entry.value.isCallout || entry.key == active))
          entry.key: entry.value,
    });
  }

  String? _activeCallout(Size size) {
    final external = spec
        .regionsFor(ageBand)
        .where((r) => !fills.containsKey(r.id) && _placement(size, r).callout);
    return external.where((r) => r.id == focusedRegionId).firstOrNull?.id ??
        external.firstOrNull?.id;
  }

  _CluePlacement _placement(Size size, ColorRegionSpec region) {
    final key = (spec, ageBand, size, region.id);
    final cached = _placements[key];
    if (cached != null) return cached;
    final anchor = Offset(
      region.anchor.dx * size.width,
      region.anchor.dy * size.height,
    );
    final path = region.path.transform(
      Matrix4.diagonal3Values(size.width, size.height, 1).storage,
    );
    final target = path.getBounds();
    final base = (size.shortestSide * .055).clamp(14.0, 22.0);
    _CluePlacement? best;
    for (final font in [base]) {
      final local = _relativeClueBounds(region, font);
      bool fits(Offset center) {
        for (final bounds in [
          local.shift(center),
          local.shift(center).inflate(.6),
        ]) {
          for (var x = 0; x <= 8; x++) {
            for (var y = 0; y <= 4; y++) {
              if (!region.path.contains(
                Offset(
                  (bounds.left + bounds.width * x / 8) / size.width,
                  (bounds.top + bounds.height * y / 4) / size.height,
                ),
              )) {
                return false;
              }
            }
          }
        }
        return true;
      }

      if (fits(anchor)) {
        best = _CluePlacement(anchor, font, local);
        break;
      }
      var distance = double.infinity;
      final step = math.max(2.0, font * .25);
      for (
        var x = target.left - local.left;
        x <= target.right - local.right;
        x += step
      ) {
        for (
          var y = target.top - local.top;
          y <= target.bottom - local.bottom;
          y += step
        ) {
          final candidate = Offset(x, y);
          final d = (candidate - anchor).distanceSquared;
          if (d >= distance || !fits(candidate)) continue;
          distance = d;
          best = _CluePlacement(candidate, font, local);
        }
      }
      if (best != null) break;
    }
    if (best == null) {
      final font = math.max(base, 16.0);
      final local = _relativeClueBounds(region, font);
      final slots = spec.labelSlots.toList()
        ..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
      for (final slot in slots) {
        final safe = Rect.fromLTWH(
          slot.left * size.width,
          slot.top * size.height,
          slot.width * size.width,
          slot.height * size.height,
        );
        final origin = safe.center - local.center;
        final badge = local.shift(origin).inflate(1.5);
        if (safe.contains(badge.topLeft) && safe.contains(badge.bottomRight)) {
          best = _CluePlacement(origin, font, local, callout: true);
          break;
        }
      }
    }
    if (best == null) {
      throw StateError('Coloring lesson has no readable clue placement');
    }
    if (_placements.length > 1024) _placements.clear();
    return _placements[key] = best;
  }

  Rect _relativeClueBounds(ColorRegionSpec region, double font) {
    Rect text(String value, double scale, Offset center) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: font * scale,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return Rect.fromCenter(
        center: center,
        width: painter.width,
        height: painter.height,
      );
    }

    Rect symbol(double scale, Offset center, String shape) {
      final extent = switch (shape) {
        'heart' => .52,
        'leaf' || 'flower' => .46,
        'square' => .40,
        _ => .44,
      };
      return Rect.fromCenter(
        center: center,
        width: font * scale * extent * 2,
        height: font * scale * extent * 2,
      );
    }

    switch (spec.ruleFor(ageBand).mode) {
      case ColorRuleMode.color:
        return symbol(
          1.3,
          Offset.zero,
          spec.paletteById(region.paletteId).symbol,
        );
      case ColorRuleMode.shape:
        return symbol(1.25, Offset.zero, region.symbol);
      case ColorRuleMode.number:
        return text('${region.value}', 1, Offset.zero);
      case ColorRuleMode.numberAndShape:
        final value = region.advancedValue;
        final expression = value.isEven
            ? '${value ~/ 2}+${value ~/ 2}'
            : '${value + 4}−4';
        return text(expression, .8, Offset(-font * .55, 0)).expandToInclude(
          symbol(.85, Offset(font * 1.15, 0), region.advancedSymbol),
        );
      case ColorRuleMode.parityAndShape:
        return text(
          '${region.advancedValue}',
          .9,
          Offset(-font * .55, 0),
        ).expandToInclude(
          symbol(.9, Offset(font * .8, 0), region.advancedSymbol),
        );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset point,
    double font, {
    Color? background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: font,
          color: const Color(0xFF293F39),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: point,
      width: painter.width + 8,
      height: painter.height + 2,
    );
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = background,
      );
    }
    painter.paint(
      canvas,
      point - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(RasterColorPainter old) =>
      old.image != image ||
      old.spec != spec ||
      old.ageBand != ageBand ||
      old.fills != fills ||
      old.strokes != strokes ||
      old.creative != creative ||
      old.showClues != showClues ||
      old.hintRegionId != hintRegionId ||
      old.debugRegions != debugRegions ||
      old.focusedRegionId != focusedRegionId;
}

class _CluePlacement {
  const _CluePlacement(
    this.point,
    this.font,
    this.bounds, {
    this.callout = false,
  });
  final Offset point;
  final double font;
  final Rect bounds;
  final bool callout;
}

class ColorClueLayout {
  const ColorClueLayout({
    required this.regionId,
    required this.bounds,
    required this.badgeBounds,
    required this.leaderTarget,
    required this.fontSize,
  });
  final String regionId;
  final Rect bounds;
  final Rect? badgeBounds;
  final Offset leaderTarget;
  final double fontSize;
  bool get isCallout => badgeBounds != null;
}

class ColorSymbol extends StatelessWidget {
  const ColorSymbol({
    super.key,
    required this.symbol,
    this.size = 24,
    this.color = const Color(0xFF293F39),
  });
  final String symbol;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SymbolPainter(symbol, color),
  );
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);
  final String symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => drawColorSymbol(
    canvas,
    size.center(Offset.zero),
    size.shortestSide,
    symbol,
    color,
  );
  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.symbol != symbol || old.color != color;
}

void drawColorSymbol(
  Canvas canvas,
  Offset center,
  double size,
  String symbol,
  Color color,
) {
  final r = size * .43;
  final paint = Paint()..color = color;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  switch (symbol) {
    case 'circle':
      canvas.drawCircle(Offset.zero, r, paint);
    case 'square':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 1.8),
          Radius.circular(r * .12),
        ),
        paint,
      );
    case 'triangle':
      canvas.drawPath(
        Path()..addPolygon([Offset(0, -r), Offset(r, r), Offset(-r, r)], true),
        paint,
      );
    case 'diamond':
      canvas.drawPath(
        Path()..addPolygon([
          Offset(0, -r),
          Offset(r, 0),
          Offset(0, r),
          Offset(-r, 0),
        ], true),
        paint,
      );
    case 'star':
      final points = List.generate(10, (i) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final radius = i.isEven ? r : r * .43;
        return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      });
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    case 'heart':
      canvas.drawPath(
        Path()
          ..moveTo(0, r)
          ..cubicTo(-r * 2, -r * .2, -r, -r * 1.6, 0, -r * .5)
          ..cubicTo(r, -r * 1.6, r * 2, -r * .2, 0, r)
          ..close(),
        paint,
      );
    case 'flower':
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        canvas.drawCircle(
          Offset(math.cos(a) * r * .52, math.sin(a) * r * .52),
          r * .5,
          paint,
        );
      }
      canvas.drawCircle(Offset.zero, r * .4, paint);
    case 'leaf':
      canvas.drawPath(
        Path()
          ..moveTo(-r, r)
          ..cubicTo(-r * 1.2, -r * .6, r * .2, -r * 1.1, r, -r)
          ..cubicTo(r * 1.2, r * .5, -r * .2, r * 1.1, -r, r)
          ..close(),
        paint,
      );
    default:
      canvas.drawCircle(Offset.zero, r, paint);
  }
  canvas.restore();
}
