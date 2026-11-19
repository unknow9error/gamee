import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import 'activity_config.dart';
import 'content/matching_layouts.dart';
import 'engines/matching_engine.dart';

/// Real illustrated counterparts, tapped in any order. Older children play
/// the same objects face down; no speed or precise dragging is required.
class MatchingActivity extends StatefulWidget {
  const MatchingActivity({super.key, required this.config});
  final ActivityConfig config;

  @override
  State<MatchingActivity> createState() => _MatchingActivityState();
}

class _MatchingActivityState extends State<MatchingActivity> {
  late MatchingEngine _engine;
  Timer? _mismatchTimer;
  Timer? _hintTimer;
  Timer? _burstTimer;
  Set<String> _hintCards = {};
  String? _lastPair;
  bool _completionSent = false;

  String _t(String ru, String kk, String en) =>
      textFor(widget.config.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(covariant MatchingActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pair count also changes between ages 3 and 4 within preschool.
    if (oldWidget.config.level.id != widget.config.level.id ||
        oldWidget.config.level.scene != widget.config.level.scene) {
      _restore();
    } else if (oldWidget.config.childAge != widget.config.childAge) {
      _restore(_engine.toJson());
    } else if (oldWidget.config.showHint != widget.config.showHint) {
      if (widget.config.showHint) {
        _showHint();
      } else {
        _hintTimer?.cancel();
        _hintCards = {};
      }
    }
  }

  void _restore([Map<String, dynamic>? currentData]) {
    final alreadyCompleted = currentData != null && _completionSent;
    _mismatchTimer?.cancel();
    _hintTimer?.cancel();
    _burstTimer?.cancel();
    _engine = MatchingEngine(
      layout: matchingLayoutFor(widget.config.level, widget.config.childAge),
      initialData: currentData ?? widget.config.initialData,
    );
    _hintCards = {};
    _lastPair = null;
    _completionSent = alreadyCompleted && _engine.complete;
    if (widget.config.showHint) _showHint();
  }

  void _showHint() {
    _hintTimer?.cancel();
    _hintCards = _engine.hintCardIds().toSet();
    _hintTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _hintCards = {});
    });
  }

  @override
  void dispose() {
    _mismatchTimer?.cancel();
    _hintTimer?.cancel();
    _burstTimer?.cancel();
    super.dispose();
  }

  void _tap(MatchingCard card) {
    if (_completionSent) return;
    final result = _engine.tap(card.id);
    if (result == MatchingTapResult.ignored) return;
    if (result == MatchingTapResult.matched ||
        result == MatchingTapResult.completed) {
      _lastPair = widget.config.reducedMotion ? null : card.pairId;
      _hintCards.removeWhere(
        (id) => _engine.layout.cardById(id)?.pairId == card.pairId,
      );
      _burstTimer?.cancel();
      if (!widget.config.reducedMotion) {
        _burstTimer = Timer(const Duration(milliseconds: 550), () {
          if (!mounted) return;
          setState(() => _lastPair = null);
        });
      }
      widget.config.onFeedback();
    }
    setState(() {});
    widget.config.onChanged(_engine.toJson());
    if (result == MatchingTapResult.mismatch) {
      // Keep the two illustrations visible long enough to compare even when
      // visual motion is disabled. This delay never imposes a time limit.
      _mismatchTimer = Timer(
        Duration(milliseconds: _engine.layout.memoryMode ? 850 : 450),
        () {
          if (!mounted) return;
          setState(_engine.clearMismatch);
          widget.config.onChanged(_engine.toJson());
        },
      );
    }
  }

  void _complete() {
    if (!_engine.complete || _completionSent) return;
    setState(() => _completionSent = true);
    widget.config.onCompleted(_engine.toJson());
  }

  String get _message {
    if (_engine.complete) {
      return _t(
        'Все пары вместе!',
        'Барлық жұп табылды!',
        'Every pair is together!',
      );
    }
    if (_engine.waitingForMismatch) {
      return _t('Рассмотри ещё раз', 'Тағы бір қара', 'Take another look');
    }
    if (_engine.selectedCardId != null) {
      return _t('Где такая же?', 'Дәл осындайы қайда?', 'Where is its match?');
    }
    if (_engine.layout.memoryMode) {
      return _t(
        'Открой две карточки',
        'Екі карточканы аш',
        'Turn over two cards',
      );
    }
    return _t(
      'Коснись двух похожих картинок',
      'Екі ұқсас суретті түрт',
      'Tap two matching pictures',
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 500 &&
          constraints.maxWidth > constraints.maxHeight * 1.2;
      // A short viewport gets a scrollable 220dp board instead of microscopic
      // cards. Normal portrait, landscape and tablet layouts need no scrolling.
      final extraTextHeight =
          math.max(0.0, MediaQuery.textScalerOf(context).scale(16) - 16) * 6;
      final minimumHeight = wide ? 220.0 : 344.0 + extraTextHeight;
      final contentHeight = math.max(
        minimumHeight,
        constraints.maxHeight.isFinite ? constraints.maxHeight : minimumHeight,
      );
      final body = SizedBox(
        height: contentHeight,
        child: wide
            ? Row(
                children: [
                  Expanded(child: _board()),
                  SizedBox(
                    width: 164,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      child: LayoutBuilder(
                        builder: (context, panel) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: panel.maxHeight,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _status(stacked: true),
                                const SizedBox(height: 16),
                                _finishButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: _status(),
                  ),
                  Expanded(child: _board()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: _finishButton(),
                  ),
                ],
              ),
      );
      return constraints.maxHeight < minimumHeight
          ? SingleChildScrollView(child: body)
          : body;
    },
  );

  Widget _status({bool stacked = false}) {
    final count = Semantics(
      label: _t(
        'Найдено ${_engine.solvedPairIds.length} из ${_engine.layout.pairIds.length} пар',
        '${_engine.layout.pairIds.length} жұптың ${_engine.solvedPairIds.length} жұбы табылды',
        '${_engine.solvedPairIds.length} of ${_engine.layout.pairIds.length} pairs found',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.join_inner_rounded,
                size: 20,
                color: AppColors.green,
              ),
              const SizedBox(width: 6),
              Text(
                '${_engine.solvedPairIds.length} / ${_engine.layout.pairIds.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final message = Semantics(
      liveRegion: true,
      child: Text(
        _message,
        maxLines: stacked ? 4 : 2,
        overflow: TextOverflow.ellipsis,
        textAlign: stacked ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.ink),
      ),
    );
    return stacked
        ? Column(children: [count, const SizedBox(height: 12), message])
        : Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 8),
              count,
            ],
          );
  }

  Widget _finishButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: const Key('matching-finish'),
      onPressed: _engine.complete && !_completionSent ? _complete : null,
      icon: Icon(
        _engine.complete ? Icons.celebration_rounded : Icons.join_inner_rounded,
      ),
      label: Text(
        _engine.complete
            ? _t('Готово!', 'Дайын!', 'All done!')
            : _t('Найди все пары', 'Барлық жұпты тап', 'Find every pair'),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
    ),
  );

  Widget _board() => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(820.0, constraints.maxWidth);
      final height = math.min(820.0, constraints.maxHeight);
      final landscape = width > height * 1.2;
      final count = _engine.layout.cards.length;
      final columns = count == 4
          ? 2
          : landscape
          ? (count == 6 ? 3 : 4)
          : count == 12
          ? 3
          : 2;
      final rows = (count / columns).ceil();
      const gap = 8.0;
      const padding = 10.0;
      final cellWidth = (width - padding * 2 - gap * (columns - 1)) / columns;
      final cellHeight = (height - padding * 2 - gap * (rows - 1)) / rows;
      return Center(
        child: SizedBox(
          key: const Key('matching-canvas'),
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      _engine.layout.assetPath,
                      fit: BoxFit.cover,
                      color: AppColors.paper.withValues(alpha: .83),
                      colorBlendMode: BlendMode.srcOver,
                    ),
                  ),
                ),
                GridView.count(
                  padding: const EdgeInsets.all(padding),
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  childAspectRatio: cellWidth / cellHeight,
                  children: [
                    for (var i = 0; i < count; i++)
                      _card(_engine.layout.cards[i], i),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _card(MatchingCard card, int index) {
    final solved = _engine.isSolved(card);
    final selected = _engine.selectedCardId == card.id;
    final wrong = _engine.mismatchCardIds.contains(card.id);
    final hint = _hintCards.contains(card.id);
    final revealed = _engine.isRevealed(card) || hint;
    final canTap = !solved && !_completionSent && !_engine.waitingForMismatch;
    final label = revealed
        ? card.name.resolve(widget.config.language)
        : _t(
            'Закрытая карточка ${index + 1}',
            'Жабық карточка ${index + 1}',
            'Face-down card ${index + 1}',
          );
    final stateLabel = solved
        ? _t('Пара найдена', 'Жұбы табылды', 'Pair found')
        : selected
        ? _t('Выбрано', 'Таңдалды', 'Selected')
        : '';
    final duration = widget.config.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      label: stateLabel.isEmpty ? label : '$label, $stateLabel',
      button: true,
      enabled: canTap,
      selected: selected,
      onTap: canTap ? () => _tap(card) : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('matching-card-${card.id}'),
            onTap: canTap ? () => _tap(card) : null,
            borderRadius: BorderRadius.circular(17),
            child: AnimatedContainer(
              duration: duration,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: solved
                    ? AppColors.lime
                    : wrong
                    ? AppColors.peach.withValues(alpha: .65)
                    : revealed
                    ? AppColors.paper
                    : AppColors.blue,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  width: selected || hint || solved ? 3 : 1.5,
                  color: selected || solved
                      ? AppColors.green
                      : hint
                      ? AppColors.yellow
                      : AppColors.line,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: Tween<double>(
                                begin: .88,
                                end: 1,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: revealed
                            ? _ArtworkCrop(
                                key: ValueKey('face-${card.id}'),
                                assetPath: _engine.layout.assetPath,
                                crop: card.crop,
                              )
                            : Center(
                                key: ValueKey('back-${card.id}'),
                                child: Icon(
                                  Icons.local_florist_rounded,
                                  size: 34,
                                  color: AppColors.green.withValues(alpha: .65),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (solved)
                    Align(
                      alignment: Alignment.topRight,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'pair-${card.id}-${_lastPair == card.pairId}',
                        ),
                        tween: Tween(
                          begin:
                              _lastPair == card.pairId &&
                                  !widget.config.reducedMotion
                              ? .35
                              : 1,
                          end: 1,
                        ),
                        duration: widget.config.reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (wrong)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: AppColors.ink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lossless runtime crop: every face is drawn directly from the shipped scene.
class _ArtworkCrop extends StatelessWidget {
  const _ArtworkCrop({super.key, required this.assetPath, required this.crop});
  final String assetPath;
  final MatchingCrop crop;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: crop.width,
      height: crop.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned(
              left: -crop.left,
              top: -crop.top,
              width: MatchingCrop.sourceSize,
              height: MatchingCrop.sourceSize,
              child: Image.asset(
                assetPath,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
