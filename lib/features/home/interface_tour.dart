import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../shared/widgets/fini_companion.dart';

enum InterfaceTourStep { begin, chapters, studio, rewards, settings }

extension InterfaceTourContent on InterfaceTourStep {
  int get tab => switch (this) {
    InterfaceTourStep.studio => 1,
    InterfaceTourStep.rewards => 2,
    _ => 0,
  };

  String title(String language) => switch (this) {
    InterfaceTourStep.begin => textFor(
      language,
      'Пойдём со мной!',
      'Менімен бірге жүр!',
      'Come along with me!',
    ),
    InterfaceTourStep.chapters => textFor(
      language,
      'Выбирай свой путь',
      'Өз жолыңды таңда',
      'Choose your own trail',
    ),
    InterfaceTourStep.studio => textFor(
      language,
      'Твоя мастерская',
      'Сенің шеберханаң',
      'Your little studio',
    ),
    InterfaceTourStep.rewards => textFor(
      language,
      'Твои открытия',
      'Сенің жаңалықтарың',
      'Your discoveries',
    ),
    InterfaceTourStep.settings => textFor(
      language,
      'Всё по-твоему',
      'Бәрі өз қалауыңша',
      'Make yourself at home',
    ),
  };

  String body(String language) => switch (this) {
    InterfaceTourStep.begin => textFor(
      language,
      'Эта кнопка начинает или продолжает игру. Покажу другие разделы!',
      'Бұл батырма ойынды бастайды не жалғастырады. Басқа бөлімдерді де көрсетейін!',
      'This button starts or continues a game. I’ll show you the other sections!',
    ),
    InterfaceTourStep.chapters => textFor(
      language,
      'В главах можно выбрать любую игру. Все 20 приключений доступны сразу.',
      'Тарауларда кез келген ойын ашық. 20 шытырманның бәрі бірден қолжетімді.',
      'You can choose any game in the chapters. All 20 adventures are ready to play.',
    ),
    InterfaceTourStep.studio => textFor(
      language,
      'Здесь сохраняются твои рисунки. В играх с рисованием можно создать свою версию.',
      'Суреттерің осында сақталады. Сурет салу ойындарында өз нұсқаңды жасай аласың.',
      'Your saved pictures live here. In drawing games, you can create your own version.',
    ),
    InterfaceTourStep.rewards => textFor(
      language,
      'За пройденные игры здесь появляются наклейки и звёзды. Собери свою коллекцию!',
      'Ойындарды аяқтағанда осында жапсырмалар мен жұлдыздар пайда болады. Өз жинағыңды жина!',
      'Finish games to collect stickers and stars here. Build your own collection!',
    ),
    InterfaceTourStep.settings => textFor(
      language,
      'Здесь можно выбрать язык, звук и подсказки. В Настройках меня можно позвать снова.',
      'Мұнда тілді, дыбысты және кеңестерді таңдайсың. Баптауларда мені қайта шақыра аласың.',
      'You can choose language, sound, and hints here. Ask me for another tour in Settings.',
    ),
  };
}

/// A shell-owned, finite tour: real targets stay visible behind a focus-safe
/// overlay, and the shell changes the actual destination before each step.
class InterfaceTour extends StatefulWidget {
  const InterfaceTour({
    super.key,
    required this.step,
    required this.target,
    required this.language,
    required this.reducedMotion,
    required this.onNext,
    required this.onBack,
    required this.onDismiss,
  });

  final InterfaceTourStep step;
  final GlobalKey target;
  final String language;
  final bool reducedMotion;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onDismiss;

  @override
  State<InterfaceTour> createState() => _InterfaceTourState();
}

class _InterfaceTourState extends State<InterfaceTour>
    with WidgetsBindingObserver {
  final _layerKey = GlobalKey();
  Rect? _target;
  int _revealGeneration = 0;
  bool _revealQueued = false;
  bool _foreground = true;

  bool get _still =>
      widget.reducedMotion || MediaQuery.disableAnimationsOf(context);

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
    _queueReveal();
  }

  @override
  void didUpdateWidget(InterfaceTour oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || oldWidget.target != widget.target) {
      _target = null;
      _queueReveal();
    }
  }

  @override
  void didChangeMetrics() => _queueReveal();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _queueReveal();
  }

  void _queueReveal() {
    if (_revealQueued) return;
    _revealQueued = true;
    final generation = ++_revealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealQueued = false;
      if (!mounted || !_foreground) return;
      unawaited(_reveal(generation));
    });
  }

  Future<void> _reveal(int generation) async {
    final targetContext = widget.target.currentContext;
    if (targetContext == null) return;
    // No fixed offsets: this survives a long translation, stored scroll
    // positions, a persistence banner, and a phone rotated during the guide.
    await Scrollable.ensureVisible(
      targetContext,
      alignment: widget.step == InterfaceTourStep.chapters ? .45 : .12,
      duration: _still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _revealGeneration) return;
    final layer = _layerKey.currentContext?.findRenderObject();
    final target = widget.target.currentContext?.findRenderObject();
    if (layer is! RenderBox || target is! RenderBox || !target.attached) return;
    final rect =
        (target.localToGlobal(Offset.zero) - layer.localToGlobal(Offset.zero)) &
        target.size;
    if (rect != _target) setState(() => _target = rect);
  }

  @override
  void dispose() {
    _revealGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _t(String ru, String kk, String en) =>
      textFor(widget.language, ru, kk, en);

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: _layerKey,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final safe = MediaQuery.paddingOf(context);
        final bounds = Rect.fromLTRB(
          safe.left + 12,
          safe.top + 12,
          constraints.maxWidth - safe.right - 12,
          constraints.maxHeight - safe.bottom - 12,
        );
        final visibleTarget = _target
            ?.inflate(7)
            .intersect(Offset.zero & constraints.biggest);
        final region = _cardRegion(bounds, visibleTarget);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(dismissible: false, color: Colors.transparent),
            IgnorePointer(
              child: CustomPaint(
                key: const Key('fini-tour-spotlight'),
                painter: _SpotlightPainter(
                  target: visibleTarget,
                  cardRegion: region,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: region,
              child: Align(
                alignment:
                    _target != null && _target!.center.dy > region.center.dy
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: region.height),
                  child: FocusScope(
                    autofocus: true,
                    child: Semantics(
                      scopesRoute: true,
                      explicitChildNodes: true,
                      namesRoute: true,
                      label: _t(
                        'Подсказки Фини',
                        'Финидің кеңестері',
                        'Fini’s tour',
                      ),
                      child: Material(
                        key: const Key('fini-interface-tour'),
                        elevation: 12,
                        color: AppColors.paper,
                        shadowColor: AppColors.ink.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(28),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          child: LayoutBuilder(
                            builder: (context, box) => _card(box.maxHeight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _card(double maxHeight) {
    final header = _header();
    final explanation = _explanation();
    final actions = _actions();
    // Keep navigation visible in landscape; only the explanation scrolls.
    // Extremely short/large-text windows still get a fully scrollable card.
    final pinControls =
        maxHeight >= 140 * MediaQuery.textScalerOf(context).scale(1);
    return pinControls
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Flexible(
                child: SingleChildScrollView(
                  key: ValueKey('fini-tour-content-${widget.step.name}'),
                  child: explanation,
                ),
              ),
              const SizedBox(height: 10),
              actions,
            ],
          )
        : SingleChildScrollView(
            key: ValueKey('fini-tour-content-${widget.step.name}'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                explanation,
                const SizedBox(height: 10),
                actions,
              ],
            ),
          );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Text(
          _t(
            'ФИНИ · ${widget.step.index + 1} из 5',
            'ФИНИ · ${widget.step.index + 1} / 5',
            'FINI · ${widget.step.index + 1} of 5',
          ),
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
      TextButton(
        key: const Key('fini-tour-skip'),
        autofocus: true,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: widget.onDismiss,
        child: Text(_t('Пропустить', 'Өткізу', 'Skip')),
      ),
    ],
  );

  Widget _explanation() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: FiniCompanion(
              key: ValueKey('fini-tour-mascot-${widget.step.name}'),
              size: 68,
              height: 84,
              reducedMotion: widget.reducedMotion,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                widget.step.title(widget.language),
                key: const Key('fini-tour-title'),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.step.body(widget.language),
        key: const Key('fini-tour-body'),
        style: const TextStyle(fontSize: 15, height: 1.35),
      ),
    ],
  );

  Widget _actions() => Row(
    children: [
      if (widget.onBack != null) ...[
        TextButton(
          key: const Key('fini-tour-back'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: widget.onBack,
          child: Text(_t('Назад', 'Артқа', 'Back')),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: FilledButton(
          key: const Key('fini-tour-next'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
          onPressed: widget.onNext,
          child: Text(
            widget.step == InterfaceTourStep.settings
                ? _t('К приключениям!', 'Ойнайық!', 'Let’s explore!')
                : _t('Дальше', 'Келесі', 'Next'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ],
  );
}

Rect _cardRegion(Rect bounds, Rect? target) {
  if (target == null || target.isEmpty) {
    final width = math.min(420.0, bounds.width);
    return Rect.fromLTWH(
      bounds.center.dx - width / 2,
      bounds.top,
      width,
      bounds.height,
    );
  }
  // On a wide screen, a side bubble leaves the live page visible. On a phone,
  // choose the larger space above/below the target and let long text scroll.
  final left = target.left - bounds.left - 18;
  final right = bounds.right - target.right - 18;
  if (bounds.width >= 600 && math.max(left, right) >= 290) {
    final useRight = right >= left;
    final width = math.min(420.0, useRight ? right : left);
    return Rect.fromLTWH(
      useRight ? target.right + 18 : target.left - 18 - width,
      bounds.top,
      width,
      bounds.height,
    );
  }
  final above = target.top - bounds.top - 18;
  final below = bounds.bottom - target.bottom - 18;
  final useBelow = below >= above;
  final height = math
      .max(96.0, useBelow ? below : above)
      .clamp(0.0, bounds.height);
  final width = math.min(420.0, bounds.width);
  return Rect.fromLTWH(
    bounds.center.dx - width / 2,
    useBelow ? bounds.bottom - height : bounds.top,
    width,
    height,
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.target, required this.cardRegion});
  final Rect? target;
  final Rect cardRegion;

  @override
  void paint(Canvas canvas, Size size) {
    final focus = target;
    final mask = Path()..addRect(Offset.zero & size);
    if (focus != null && !focus.isEmpty) {
      mask.addRRect(RRect.fromRectAndRadius(focus, const Radius.circular(18)));
      mask.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(
      mask,
      Paint()..color = AppColors.ink.withValues(alpha: .48),
    );
    if (focus == null || focus.isEmpty) return;
    final ring = RRect.fromRectAndRadius(focus, const Radius.circular(18));
    canvas.drawRRect(
      ring,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // A directional link makes Fini's explanation point to the actual control,
    // rather than leaving a floating decorative character beside the copy.
    final Offset from;
    final Offset to;
    if (cardRegion.left >= focus.right) {
      from = Offset(
        cardRegion.left,
        focus.center.dy.clamp(cardRegion.top + 18, cardRegion.bottom - 18),
      );
      to = Offset(focus.right + 3, focus.center.dy);
    } else if (cardRegion.right <= focus.left) {
      from = Offset(
        cardRegion.right,
        focus.center.dy.clamp(cardRegion.top + 18, cardRegion.bottom - 18),
      );
      to = Offset(focus.left - 3, focus.center.dy);
    } else {
      from = Offset(
        focus.center.dx.clamp(cardRegion.left + 18, cardRegion.right - 18),
        focus.center.dy > cardRegion.center.dy
            ? cardRegion.bottom
            : cardRegion.top,
      );
      to = Offset(
        from.dx.clamp(focus.left + 6, focus.right - 6),
        from.dy < focus.center.dy ? focus.top - 3 : focus.bottom + 3,
      );
    }
    if ((to - from).distance < 14) return;
    final paint = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final bend = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx + 12, bend.dy, to.dx, to.dy),
      paint,
    );
    final angle = math.atan2(to.dy - bend.dy, to.dx - bend.dx);
    for (final side in [-1, 1]) {
      canvas.drawLine(
        to,
        to -
            Offset(math.cos(angle + side * .55), math.sin(angle + side * .55)) *
                9,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      target != oldDelegate.target || cardRegion != oldDelegate.cardRegion;
}
