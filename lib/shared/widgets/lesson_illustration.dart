import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

/// The authored lesson picture, with a bounded decode size for album grids.
class LessonIllustration extends StatefulWidget {
  const LessonIllustration({
    super.key,
    required this.level,
    this.language = 'ru',
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final LevelDefinition level;
  final String language;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  State<LessonIllustration> createState() => _LessonIllustrationState();
}

class _LessonIllustrationState extends State<LessonIllustration> {
  int _attempt = 0;
  ImageProvider? _provider;

  Future<void> _retry() async {
    await _provider?.evict(
      configuration: createLocalImageConfiguration(context),
    );
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final asset = widget.level.illustrationAsset;
      if (asset == null) return _unavailable();
      final logicalSide = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.sizeOf(context).width;
      final decodeSize = (logicalSide * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(128, 1024)
          .toInt();
      final provider = ResizeImage(AssetImage(asset), width: decodeSize);
      _provider = provider;
      return Image(
        key: ValueKey('$asset-$_attempt'),
        image: provider,
        fit: widget.fit,
        semanticLabel:
            widget.semanticLabel ?? widget.level.title.resolve(widget.language),
        frameBuilder: (context, child, frame, synchronous) {
          if (synchronous || frame != null) return child;
          return const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stack) => _unavailable(),
      );
    },
  );

  Widget _unavailable() => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxHeight < 125 || box.maxWidth < 150;
      final retry = textFor(
        widget.language,
        'Ещё раз',
        'Қайталау',
        'Try again',
      );
      return ColoredBox(
        color: AppColors.blue.withValues(alpha: .45),
        child: Center(
          child: compact
              ? IconButton(
                  onPressed: _retry,
                  tooltip: retry,
                  icon: const Icon(Icons.refresh_rounded),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined, color: AppColors.green),
                      const SizedBox(height: 5),
                      Text(
                        textFor(
                          widget.language,
                          'Картинка не загрузилась',
                          'Сурет жүктелмеді',
                          'The picture could not load',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(retry),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
