import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show StringProperty, DiagnosticsProperty;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'engines/hidden_picture.dart';

/// A picture-matching activity over an unchanged, bundled ImageGen painting.
/// The source picture, the token crops, and input coordinates share one space.
class RasterHiddenActivity extends StatefulWidget {
  const RasterHiddenActivity({
    super.key,
    required this.config,
    this.debugHotspots = false,
  });

  final ActivityConfig config;
  final bool debugHotspots;

  @override
  State<RasterHiddenActivity> createState() => _RasterHiddenActivityState();
}

class _RasterHiddenActivityState extends State<RasterHiddenActivity>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _hintPulse;
  HiddenPictureSpec? _spec;
  HiddenPictureSession? _session;
  ui.Image? _image;
  String? _selected;
  bool _loading = true;
  bool _loadFailed = false;
  bool _mismatch = false;
  bool _completionSent = false;
  int _loadEpoch = 0;
  Size? _lastCanvasSize;
  final Map<String, GlobalKey> _tokenKeys = {};
  String _loadStage = 'metadata';
  Object? _lastLoadError;

  String _t(String ru, String kk, String en) =>
      textFor(widget.config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncHintAnimation();
    _load();
  }

  @override
  void didUpdateWidget(covariant RasterHiddenActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != widget.config.level.id) {
      _load();
    } else if (oldWidget.config.ageBand != widget.config.ageBand &&
        _spec != null &&
        _session != null) {
      _session = HiddenPictureSession(
        _spec!,
        widget.config.ageBand,
        draft: _session!.toJson(),
      );
      _chooseNext();
      _completionSent = false;
    }
    _syncHintAnimation();
  }

  void _syncHintAnimation() {
    if (widget.config.showHint && !widget.config.reducedMotion) {
      _hintPulse.repeat(reverse: true);
    } else {
      _hintPulse.stop();
      _hintPulse.value = 0.5;
    }
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    _loading = true;
    _loadFailed = false;
    _lastLoadError = null;
    _loadStage = 'metadata';
    _completionSent = false;
    _mismatch = false;
    _transform.value = Matrix4.identity();
    final specAsset = widget.config.level.activityData['hiddenSpecAsset'];
    ui.Image? decodedImage;
    try {
      if (specAsset is! String) {
        throw const FormatException('Missing picture specification');
      }
      final spec = HiddenPictureSpec.decode(
        await rootBundle.loadString(specAsset),
      );
      if (spec.asset != widget.config.level.illustrationAsset) {
        throw const FormatException('Picture and specification do not match');
      }
      _loadStage = 'bitmap';
      final bytes = await rootBundle.load(spec.asset);
      final imageBytes = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      if (spec.imageSha256 != null &&
          sha256.convert(imageBytes).toString() != spec.imageSha256) {
        throw const FormatException('Picture revision changed');
      }
      _loadStage = 'codec';
      final codec = await ui.instantiateImageCodec(imageBytes);
      try {
        decodedImage = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (decodedImage.width != spec.imageSize.width ||
          decodedImage.height != spec.imageSize.height) {
        throw const FormatException('Picture dimensions changed');
      }
      _loadStage = 'session';
      if (!mounted || epoch != _loadEpoch) {
        decodedImage.dispose();
        return;
      }
      final oldImage = _image;
      setState(() {
        _spec = spec;
        _session = HiddenPictureSession(
          spec,
          widget.config.ageBand,
          draft: widget.config.initialData,
        );
        _image = decodedImage;
        _loading = false;
        _chooseNext();
        final savedSelection = widget.config.initialData?['selected'];
        if (savedSelection is String &&
            _session!.activeTargets.any(
              (target) =>
                  target.id == savedSelection &&
                  !_session!.found.contains(target.id),
            )) {
          _selected = savedSelection;
        }
      });
      oldImage?.dispose();
      _loadStage = 'ready';
      _revealSelectedToken();
    } on Object catch (error) {
      decodedImage?.dispose();
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _lastLoadError = error;
      });
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('pictureLoadStage', _loadStage));
    properties.add(
      DiagnosticsProperty<Object>(
        'pictureLoadError',
        _lastLoadError,
        defaultValue: null,
      ),
    );
  }

  @override
  void dispose() {
    _loadEpoch++;
    _hintPulse.dispose();
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  void _chooseNext() {
    _selected = _session?.activeTargets
        .where((target) => !_session!.found.contains(target.id))
        .firstOrNull
        ?.id;
    _transform.value = Matrix4.identity();
    _revealSelectedToken();
  }

  void _revealSelectedToken() {
    final selected = _selected;
    if (selected == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selected != selected) return;
      final tokenContext = _tokenKeys[selected]?.currentContext;
      if (tokenContext != null) {
        Scrollable.ensureVisible(
          tokenContext,
          alignment: .5,
          duration: widget.config.reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
        );
      }
    });
  }

  Map<String, dynamic> get _data => {
    ..._session!.toJson(),
    'selected': _selected,
    'imageAsset': _spec!.asset,
    'worldId': widget.config.level.worldId,
    'scene': widget.config.level.scene,
  };

  void _tapPicture(Offset sourcePoint, double displayScale) {
    final session = _session!;
    if (_completionSent || session.isComplete) return;
    final toleranceDp = switch (widget.config.ageBand) {
      AgeBand.preschool => 22.0,
      AgeBand.primary => 15.0,
      AgeBand.advanced => 8.0,
    };
    final zoom = _transform.value.getMaxScaleOnAxis();
    final target = session.findAt(
      sourcePoint,
      tolerance: toleranceDp / (displayScale * zoom),
    );
    if (target == null || target.id != _selected) {
      setState(() => _mismatch = true);
      return;
    }
    if (!session.discover(target.id)) return;
    setState(() {
      _mismatch = false;
      _chooseNext();
    });
    widget.config.onFeedback();
    widget.config.onChanged(_data);
  }

  void _select(String id) {
    if (_completionSent || _session!.found.contains(id)) return;
    setState(() {
      _selected = id;
      _mismatch = false;
    });
    _transform.value = Matrix4.identity();
    widget.config.onChanged(_data);
    _revealSelectedToken();
  }

  void _complete() {
    if (!_session!.isComplete || _completionSent) return;
    setState(() => _completionSent = true);
    widget.config.onCompleted(_data);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        key: Key('hidden-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_loadFailed) {
      return Center(
        key: const Key('hidden-load-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.landscape_outlined, size: 44),
              const SizedBox(height: 12),
              Text(
                _t(
                  'Картинка не загрузилась. Попробуем ещё раз?',
                  'Сурет жүктелмеді. Қайта байқап көрейік пе?',
                  'The picture could not load. Shall we try again?',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: Text(_t('Ещё раз', 'Қайта', 'Try again')),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        if (wide) {
          return Row(
            children: [
              Expanded(child: _canvas()),
              SizedBox(
                width: 224,
                child: Column(
                  children: [
                    _status(),
                    Expanded(child: _tokens(vertical: true)),
                    _finish(),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _status(),
            _tokens(vertical: false),
            Expanded(child: _canvas()),
            _finish(),
          ],
        );
      },
    );
  }

  Widget _status() {
    final session = _session!;
    final message = session.isComplete
        ? _t(
            'Все друзья найдены!',
            'Барлық достар табылды!',
            'You found every friend!',
          )
        : _mismatch
        ? _t(
            'Сравни с карточкой. Попробуй ещё!',
            'Карточкамен салыстыр. Қайта байқап көр!',
            'Match the little picture. Try again!',
          )
        : widget.config.ageBand == AgeBand.advanced
        ? _t(
            'Найди друга по фрагменту.',
            'Досыңды сурет бөлігіне қарап тап.',
            'Find the friend from its picture detail.',
          )
        : _t(
            'Найди на картинке такого же друга.',
            'Суреттен дәл осындай досты тап.',
            'Find the same friend in the picture.',
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: widget.config.reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                message,
                key: ValueKey(message),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${session.found.length} / ${session.activeTargets.length}',
              key: const Key('hidden-progress'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokens({required bool vertical}) {
    final targets = _session!.activeTargets;
    final children = [for (final target in targets) _token(target)];
    if (vertical) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: children,
        ),
      );
    }
    return SizedBox(
      height: _tokenExtent + 6,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(right: 8), child: child),
          ],
        ),
      ),
    );
  }

  double get _tokenExtent => switch (widget.config.ageBand) {
    AgeBand.preschool => 84,
    AgeBand.primary => 72,
    AgeBand.advanced => 66,
  };

  Widget _token(HiddenPictureTarget target) {
    final found = _session!.found.contains(target.id);
    final selected = _selected == target.id;
    return KeyedSubtree(
      key: _tokenKeys.putIfAbsent(
        target.id,
        () => GlobalKey(debugLabel: 'hidden-token-${target.id}'),
      ),
      child: Semantics(
        label:
            '${target.name.resolve(widget.config.language)}, ${found ? _t('найдено', 'табылды', 'found') : _t('найди на рисунке', 'суреттен тап', 'find in the picture')}',
        button: !found,
        selected: selected,
        onTap: found ? null : () => _select(target.id),
        child: ExcludeSemantics(
          child: Tooltip(
            message: target.name.resolve(widget.config.language),
            child: InkWell(
              key: ValueKey('hidden-target-${target.id}'),
              onTap: found ? null : () => _select(target.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: widget.config.reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                width: _tokenExtent,
                height: _tokenExtent,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: found ? AppColors.lime : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.green : AppColors.line,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomPaint(
                        painter: _SourceCropPainter(
                          _image!,
                          _previewCrop(target),
                        ),
                      ),
                    ),
                    if (found)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect _previewCrop(HiddenPictureTarget target) {
    if (widget.config.ageBand != AgeBand.advanced) return target.cropRect;
    final full = target.cropRect;
    final width = math.max(full.width * .38, 70.0).clamp(1.0, full.width);
    final height = math.max(full.height * .38, 70.0).clamp(1.0, full.height);
    final left = (target.anchor.dx - width / 2).clamp(
      full.left,
      full.right - width,
    );
    final top = (target.anchor.dy - height / 2).clamp(
      full.top,
      full.bottom - height,
    );
    return Rect.fromLTWH(left, top, width, height);
  }

  Widget _canvas() => LayoutBuilder(
    builder: (context, constraints) {
      final available = Size(
        math.max(1, constraints.maxWidth - 16),
        math.max(1, constraints.maxHeight - 16),
      );
      final source = _spec!.imageSize;
      final fit = applyBoxFit(BoxFit.contain, source, available).destination;
      if (_lastCanvasSize != null && _lastCanvasSize != fit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _transform.value = Matrix4.identity();
        });
      }
      _lastCanvasSize = fit;
      return Center(
        child: SizedBox.fromSize(
          size: fit,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: RepaintBoundary(
              key: const Key('hidden-artwork'),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: GestureDetector(
                  key: const Key('hidden-canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _tapPicture(
                    Offset(
                      details.localPosition.dx * source.width / fit.width,
                      details.localPosition.dy * source.height / fit.height,
                    ),
                    fit.width / source.width,
                  ),
                  child: AnimatedBuilder(
                    animation: _hintPulse,
                    builder: (_, _) => CustomPaint(
                      painter: _HiddenPicturePainter(
                        image: _image!,
                        spec: _spec!,
                        session: _session!,
                        hintId: widget.config.showHint ? _selected : null,
                        hintOpacity: .5 + _hintPulse.value * .5,
                        debug: widget.debugHotspots,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _finish() => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(12, 5, 12, 8),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('hidden-finish'),
        onPressed: _session!.isComplete && !_completionSent ? _complete : null,
        icon: Icon(
          _session!.isComplete
              ? Icons.celebration_rounded
              : Icons.search_rounded,
        ),
        label: Text(
          _session!.isComplete
              ? _t('Готово!', 'Дайын!', 'All done!')
              : _t(
                  'Найди всех друзей',
                  'Барлық досты тап',
                  'Find every friend',
                ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _SourceCropPainter extends CustomPainter {
  const _SourceCropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    final destination = Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, source.size, size).destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _SourceCropPainter oldDelegate) =>
      image != oldDelegate.image || source != oldDelegate.source;
}

class _HiddenPicturePainter extends CustomPainter {
  const _HiddenPicturePainter({
    required this.image,
    required this.spec,
    required this.session,
    required this.hintId,
    required this.hintOpacity,
    required this.debug,
  });
  final ui.Image image;
  final HiddenPictureSpec spec;
  final HiddenPictureSession session;
  final String? hintId;
  final double hintOpacity;
  final bool debug;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Offset.zero & spec.imageSize,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
    final scale = size.width / spec.imageSize.width;
    canvas.save();
    canvas.scale(scale);
    for (final target in spec.targets) {
      final found = session.found.contains(target.id);
      final hint = hintId == target.id;
      if (!found && !hint && !debug) continue;
      final color = hint
          ? AppColors.yellow.withValues(alpha: hintOpacity)
          : found
          ? AppColors.green
          : Colors.pinkAccent;
      canvas.drawPath(
        target.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (hint ? 3.5 : 2) / scale
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      if (hint) {
        canvas.drawPath(
          target.path,
          Paint()
            ..color = AppColors.yellow.withValues(alpha: .12 * hintOpacity),
        );
      }
      if (debug) {
        final label = TextPainter(
          text: TextSpan(
            text: target.id,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12 / scale,
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, target.anchor);
      }
      if (found) {
        final center = target.anchor;
        canvas.drawCircle(center, 10 / scale, Paint()..color = AppColors.green);
        final check = Path()
          ..moveTo(center.dx - 5 / scale, center.dy)
          ..lineTo(center.dx - 1 / scale, center.dy + 4 / scale)
          ..lineTo(center.dx + 6 / scale, center.dy - 4 / scale);
        canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2 / scale,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HiddenPicturePainter oldDelegate) => true;
}
