import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A real paw-wave and blink, with a fixed canvas so Fini never jumps between
/// sprite cells. The finite greeting settles quietly after [cycles] waves.
class FiniCompanion extends StatefulWidget {
  const FiniCompanion({
    super.key,
    required this.size,
    this.height,
    this.reducedMotion = false,
    this.animate = true,
    this.semanticLabel,
    this.cycles = 2,
  }) : assert(size > 0),
       assert(cycles > 0);

  final double size;
  final double? height;
  final bool reducedMotion;
  final bool animate;
  final String? semanticLabel;
  final int cycles;

  @override
  State<FiniCompanion> createState() => _FiniCompanionState();
}

class _FiniCompanionState extends State<FiniCompanion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _frames = [0, 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1];
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..addStatusListener(_cycle);
  late final _listener = ImageStreamListener(
    _receiveImage,
    onError: _imageError,
  );
  ImageStream? _stream;
  ImageInfo? _sheet;
  bool _foreground = true;
  int _completedCycles = 0;

  bool get _still =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

  bool get _canAnimate =>
      widget.animate &&
      !_still &&
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      _sheet != null &&
      _completedCycles < widget.cycles;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = const AssetImage('assets/images/fini-wave-sheet.png')
        .resolve(createLocalImageConfiguration(context));
    if (next.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = next..addListener(_listener);
    }
    _syncMotion();
  }

  @override
  void didUpdateWidget(FiniCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.animate && widget.animate) ||
        (oldWidget.reducedMotion && !widget.reducedMotion)) {
      _completedCycles = 0;
      _wave.value = 0;
    }
    _syncMotion();
  }

  void _receiveImage(ImageInfo image, bool synchronousCall) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final previous = _sheet;
    setState(() => _sheet = image);
    // The previous RenderCustomPaint can still paint until this frame ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    _syncMotion();
  }

  void _imageError(Object error, StackTrace? stack) {
    // The original portrait remains usable if an asset cannot be decoded.
  }

  void _syncMotion() {
    if (!_canAnimate) {
      _wave.stop();
      if (_still || !widget.animate) _wave.value = 0;
    } else if (!_wave.isAnimating) {
      _wave.forward();
    }
  }

  void _cycle(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _completedCycles++;
    if (mounted && _canAnimate) {
      _wave.forward(from: 0);
    } else {
      _wave.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stream?.removeListener(_listener);
    _sheet?.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _sheet?.image;
    final visual = SizedBox(
      width: widget.size,
      height: widget.height ?? widget.size,
      child: image == null
          ? Image.asset(
              'assets/images/fini.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : AnimatedBuilder(
              animation: _wave,
              builder: (context, _) => CustomPaint(
                key: const Key('fini-wave-sprite'),
                painter: _FiniFramePainter(
                  image,
                  _frames[(_wave.value * _frames.length).floor().clamp(
                    0,
                    _frames.length - 1,
                  )],
                ),
              ),
            ),
    );
    return widget.semanticLabel == null
        ? ExcludeSemantics(child: visual)
        : Semantics(image: true, label: widget.semanticLabel, child: visual);
  }
}

class _FiniFramePainter extends CustomPainter {
  const _FiniFramePainter(this.image, this.frame);
  final ui.Image image;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    // Source dimensions may be fractional (1774×887 =>443.5px cells).
    // Keep the whole cell instead of tightening the crop around each pose.
    final width = image.width / 4;
    final height = image.height / 2;
    final source = Rect.fromLTWH(
      frame % 4 * width,
      frame ~/ 4 * height,
      width,
      height,
    );
    final fitted = applyBoxFit(BoxFit.contain, Size(width, height), size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
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
  bool shouldRepaint(_FiniFramePainter oldDelegate) =>
      image != oldDelegate.image || frame != oldDelegate.frame;
}
