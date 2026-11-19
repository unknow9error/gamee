import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../shared/art/art_scene.dart';
import '../../shared/widgets/lesson_illustration.dart';
import '../play/color_activity.dart';
import '../play/drawing_activity.dart';

class ArtworkPreview extends StatelessWidget {
  const ArtworkPreview({super.key, required this.level, required this.data});
  final LevelDefinition level;
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    if (level.kind == ActivityKind.numberColor ||
        level.kind == ActivityKind.freeColor) {
      return ColorArtworkPreview(level: level, data: data);
    }
    if (level.illustrationAsset != null) {
      if (level.kind == ActivityKind.guidedDraw) {
        return DrawingArtworkPreview(level: level, data: data);
      }
      return LessonIllustration(level: level);
    }
    final scene = SceneFactory.create(
      level.scene,
      variant: level.variant,
      geometric: level.kind == ActivityKind.hiddenAnimals,
      segmented: level.kind == ActivityKind.numberColor,
      worldId: level.worldId,
    );
    final fills = <String, Color>{};
    final raw = data['fills'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.key is String && e.value is num) {
          fills[e.key as String] = Color((e.value as num).toInt());
        }
      }
    }
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide;
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: ArtScenePainter(
                    scene: scene,
                    fills: fills,
                    colored:
                        level.kind == ActivityKind.hiddenAnimals &&
                        fills.isEmpty,
                  ),
                ),
                if (data['strokes'] is List)
                  CustomPaint(
                    painter: _SavedStrokePainter(
                      data['strokes'] as List,
                      scene,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedStrokePainter extends CustomPainter {
  _SavedStrokePainter(this.strokes, this.scene);
  final List strokes;
  final ArtScene scene;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final item in strokes) {
      if (item is! Map || item['points'] is! List) continue;
      canvas.save();
      final clipId = item['clipRegionId'];
      if (clipId is String) {
        final region = scene.regions.where((r) => r.id == clipId).firstOrNull;
        if (region != null) {
          final matrix = Matrix4.diagonal3Values(
            size.width / scene.viewBox.width,
            size.height / scene.viewBox.height,
            1,
          );
          canvas.clipPath(region.path.transform(matrix.storage));
        }
      }
      final path = Path();
      bool first = true;
      Offset? firstPoint;
      var pointCount = 0;
      for (final point in item['points'] as List) {
        if (point is! List ||
            point.length != 2 ||
            point[0] is! num ||
            point[1] is! num ||
            !(point[0] as num).isFinite ||
            !(point[1] as num).isFinite) {
          continue;
        }
        final p = Offset(
          (point[0] as num).toDouble() * size.width,
          (point[1] as num).toDouble() * size.height,
        );
        if (first) {
          firstPoint = p;
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
        pointCount++;
      }
      final rawColor = item['color'];
      final rawWidth = item['width'];
      final paint = Paint()
        ..color = Color(
          rawColor is num && rawColor.isFinite ? rawColor.toInt() : 0xFF293F39,
        )
        ..strokeWidth =
            (rawWidth is num && rawWidth.isFinite && rawWidth > 0
                ? rawWidth.toDouble()
                : 3.5) *
            size.width /
            400
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = item['eraser'] == true
            ? BlendMode.clear
            : BlendMode.srcOver;
      if (pointCount == 1 && firstPoint != null) {
        canvas.drawCircle(
          firstPoint,
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SavedStrokePainter old) => old.strokes != strokes;
}
