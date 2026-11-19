import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'activity_config.dart';
import 'content/choice_layouts.dart';
import 'engines/choice_engine.dart';

/// Image-based matching, ordering, and visual-pattern activities.
class ChoiceActivity extends StatefulWidget {
  const ChoiceActivity({super.key, required this.config});
  final ActivityConfig config;

  @override
  State<ChoiceActivity> createState() => _ChoiceActivityState();
}

class _ChoiceActivityState extends State<ChoiceActivity> {
  late ChoiceEngine _engine;
  bool _missed = false;
  bool _completionSent = false;
  String? _wrongOption;

  String _t(String ru, String kk, String en) =>
      textFor(widget.config.language, ru, kk, en);
  PictureChallenge get _challenge => _engine.challenge;
  PictureStage get _stage => _engine.stage;
  Duration get _duration => widget.config.reducedMotion
      ? Duration.zero
      : const Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(covariant ChoiceActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.level.id != widget.config.level.id ||
        oldWidget.config.level.scene != widget.config.level.scene ||
        oldWidget.config.level.illustrationAsset !=
            widget.config.level.illustrationAsset ||
        oldWidget.config.childAge != widget.config.childAge) {
      _restore();
    }
  }

  void _restore() {
    _engine = ChoiceEngine(
      choiceChallenge(
        widget.config.level,
        widget.config.ageBand,
        childAge: widget.config.childAge,
      ),
      initialData: widget.config.initialData,
    );
    _missed = false;
    _wrongOption = null;
    _completionSent = false;
  }

  void _choose(String id) {
    if (_engine.complete || _completionSent) return;
    if (!_engine.choose(id)) {
      setState(() {
        _missed = true;
        _wrongOption = id;
      });
      return;
    }
    setState(() {
      _missed = false;
      _wrongOption = null;
    });
    widget.config.onFeedback();
    widget.config.onChanged(_engine.toJson());
    if (_engine.complete) {
      _finish();
    }
  }

  void _finish() {
    if (!_engine.complete || _completionSent) return;
    _completionSent = true;
    widget.config.onCompleted(_engine.toJson());
  }

  String get _message {
    if (_engine.complete) {
      return _t('Всё получилось!', 'Бәрі орындалды!', 'You did it!');
    }
    if (_missed) {
      return _t(
        'Почти! Сравни детали ещё раз.',
        'Жақын қалды! Бөлшектерді қайта салыстыр.',
        'Nearly! Compare the details again.',
      );
    }
    return switch (_stage.rule) {
      ChoiceRule.missingPiece => _t(
        'Какой кусочек закроет окошко?',
        'Терезені қай бөлшек жабады?',
        'Which piece fits the highlighted window?',
      ),
      ChoiceRule.oddPiece =>
        _stage.referenceTurns == 0
            ? _t(
                'Найди кусочек, который отличается от образца.',
                'Үлгіден өзгеше бөлшекті тап.',
                'Find the piece that differs from its sample.',
              )
            : _t(
                'Образцы повернулись. Какой кусочек отличается?',
                'Үлгілер бұрылды. Қай бөлшек өзгеше?',
                'The samples turned. Which piece differs?',
              ),
      ChoiceRule.repeatingPattern =>
        widget.config.ageBand == AgeBand.advanced
            ? _t(
                'Каждая пара поворачивается. Что дальше?',
                'Әр жұп бұрылады. Әрі қарай не?',
                'Each pair turns. What comes next?',
              )
            : _t(
                'Посмотри, как повторяется узор. Что дальше?',
                'Өрнектің қайталануына қара. Әрі қарай не?',
                'Watch the repeating pattern. What comes next?',
              ),
      ChoiceRule.growthOrder => _t(
        'От семечка к цветку. Заполни окошко по порядку.',
        'Тұқымнан гүлге дейін. Терезені ретімен толтыр.',
        'From seed to flower. Fill the window in order.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 620 ||
          (box.maxWidth >= 480 &&
              box.maxWidth > box.maxHeight &&
              box.maxHeight < 450);
      if (wide) {
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  height: math.max(220.0, box.maxHeight - 8),
                  child: Center(
                    child: _board(
                      math.max(
                        220.0,
                        math.min(box.maxHeight - 8, box.maxWidth - 242),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 234,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 8),
                    _options(),
                    _restoreFinish(),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      final controlsHeight = _engine.complete
          ? 118.0
          : (_stage.options.length <= 2 ? 150.0 : 248.0);
      final side = math.min(
        box.maxWidth - 20,
        math.max(220.0, box.maxHeight - controlsHeight),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 8),
            _board(side),
            const SizedBox(height: 10),
            _options(),
            _restoreFinish(),
          ],
        ),
      );
    },
  );

  Widget _header() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: _duration,
              child: Text(
                _message,
                key: ValueKey(_message),
                maxLines: 3,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${_engine.stageIndex}/${_challenge.stages.length}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      if (_stage.rule == ChoiceRule.missingPiece && !_engine.complete)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _t(
              'Коснись кусочка или перетащи его в окошко.',
              'Бөлшекті түрт немесе терезеге сүйре.',
              'Tap a piece, or drag it into the window.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
    ],
  );

  Widget _board(double side) => SizedBox.square(
    dimension: side,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: RepaintBoundary(
          key: const Key('choice-board'),
          child: switch (_stage.rule) {
            ChoiceRule.missingPiece => _missingBoard(),
            ChoiceRule.oddPiece => _oddBoard(),
            ChoiceRule.repeatingPattern ||
            ChoiceRule.growthOrder => _sequenceBoard(),
          },
        ),
      ),
    ),
  );

  Widget _image() => Image.asset(
    _challenge.asset,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );

  Widget _missingBoard() => LayoutBuilder(
    builder: (context, box) => Stack(
      fit: StackFit.expand,
      children: [
        _image(),
        if (!_engine.complete)
          for (var i = _engine.stageIndex; i < _challenge.holes.length; i++)
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                _challenge.holes[i].crop.left * box.maxWidth,
                _challenge.holes[i].crop.top * box.maxHeight,
                _challenge.holes[i].crop.width * box.maxWidth,
                _challenge.holes[i].crop.height * box.maxHeight,
              ),
              child: _hole(i),
            ),
      ],
    ),
  );

  Widget _hole(int index) {
    final active = index == _stage.target;
    return DragTarget<String>(
      key: ValueKey('choice-hole-$index'),
      onWillAcceptWithDetails: (_) => active && !_engine.complete,
      onAcceptWithDetails: (details) => _choose(details.data),
      builder: (context, candidates, rejected) => Semantics(
        label: _t(
          'Окошко ${index + 1}',
          '${index + 1}-терезе',
          'Window ${index + 1}',
        ),
        child: Container(
          decoration: BoxDecoration(
            color: active ? AppColors.paper : AppColors.line,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.green : AppColors.muted,
              width: active ? 3 : 1.5,
            ),
          ),
          child: widget.config.showHint && active
              ? Opacity(
                  opacity: .3,
                  child: PictureCrop(
                    asset: _challenge.asset,
                    piece: _challenge.holes[index],
                  ),
                )
              : Center(
                  child: Icon(
                    active
                        ? Icons.extension_rounded
                        : Icons.lock_outline_rounded,
                    color: active ? AppColors.green : AppColors.muted,
                    size: 28,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _oddBoard() => Column(
    children: [
      Expanded(
        child: Padding(padding: const EdgeInsets.all(8), child: _image()),
      ),
      Container(
        color: AppColors.paper,
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_stage.referenceTurns != 0)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.rotate_right_rounded, color: AppColors.green),
              ),
            for (var i = 0; i < _stage.references.length; i++)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _sample(
                    _stage.references[i].transform(
                      turns: _stage.referenceTurns,
                    ),
                    i,
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _sample(PicturePiece piece, int reference) => Container(
    height: 68,
    constraints: const BoxConstraints(maxWidth: 86),
    decoration: BoxDecoration(
      border: Border.all(color: _cueColor(reference), width: 3),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: PictureCrop(asset: _challenge.asset, piece: piece),
        ),
        Positioned(left: 2, top: 2, child: _cue(reference)),
      ],
    ),
  );

  Widget _sequenceBoard() => Column(
    children: [
      Expanded(
        child: Padding(padding: const EdgeInsets.all(5), child: _image()),
      ),
      Container(
        color: AppColors.paper,
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, box) {
            // Every slot, including the question, remains visible on a small phone.
            final turningPairs =
                _stage.rule == ChoiceRule.repeatingPattern &&
                widget.config.ageBand == AgeBand.advanced;
            final columns = turningPairs || _stage.sequence.length <= 4 ? 2 : 3;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var row = 0;
                  row < (_stage.sequence.length / columns).ceil();
                  row++
                )
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var col = 0; col < columns; col++)
                          if (row * columns + col < _stage.sequence.length) ...[
                            if (col > 0)
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.muted,
                              ),
                            _sequenceToken(
                              row * columns + col,
                              math.min(
                                76.0,
                                (box.maxWidth - (columns - 1) * 16) / columns,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _sequenceToken(int i, double width) {
    final piece = _engine.complete && i == _stage.activeIndex
        ? _stage.answerOption.piece
        : _stage.sequence[i];
    final active = i == _stage.activeIndex;
    return Container(
      key: ValueKey('sequence-slot-$i'),
      width: width,
      height: 58,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: active ? AppColors.lime : Colors.white,
        border: Border.all(
          color: active ? AppColors.green : AppColors.line,
          width: active ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: piece != null
          ? PictureCrop(asset: _challenge.asset, piece: piece)
          : widget.config.showHint && active
          ? Opacity(
              opacity: .3,
              child: PictureCrop(
                asset: _challenge.asset,
                piece: _stage.answerOption.piece,
              ),
            )
          : Center(
              child: Icon(
                active ? Icons.question_mark_rounded : Icons.more_horiz,
                color: AppColors.green,
              ),
            ),
    );
  }

  Widget _options() {
    if (_engine.complete) return const SizedBox.shrink();
    final count = _stage.options.length;
    return GridView.count(
      key: ValueKey('choice-options-${_stage.id}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: count == 6 ? 3 : 2,
      childAspectRatio: count == 6 ? 1 : 1.65,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [for (var i = 0; i < count; i++) _option(_stage.options[i], i)],
    );
  }

  Widget _option(PictureOption option, int index) {
    final wrong = _wrongOption == option.id;
    final hinted = widget.config.showHint && option.id == _stage.answer;
    final card = Semantics(
      button: true,
      label: _t(
        'Кусочек ${index + 1}',
        '${index + 1}-бөлшек',
        'Piece ${index + 1}',
      ),
      onTap: () => _choose(option.id),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('choice-option-${option.id}'),
            onTap: () => _choose(option.id),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: _duration,
              constraints: const BoxConstraints(minHeight: 64, minWidth: 64),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: wrong
                    ? AppColors.peach.withValues(alpha: .3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hinted
                      ? AppColors.green
                      : wrong
                      ? AppColors.peach
                      : AppColors.line,
                  width: hinted || wrong ? 3 : 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: PictureCrop(
                        asset: _challenge.asset,
                        piece: option.piece,
                      ),
                    ),
                  ),
                  if (_stage.rule == ChoiceRule.oddPiece)
                    Positioned(left: 0, top: 0, child: _cue(option.reference)),
                  if (wrong)
                    const Positioned(
                      right: 1,
                      bottom: 1,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
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
    if (_stage.rule != ChoiceRule.missingPiece) return card;
    return Draggable<String>(
      data: option.id,
      feedback: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: 90,
          child: PictureCrop(asset: _challenge.asset, piece: option.piece),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      child: card,
    );
  }

  Widget _restoreFinish() => !_engine.complete
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            key: const Key('choice-finish'),
            onPressed: _completionSent ? null : _finish,
            icon: const Icon(Icons.check_rounded),
            label: Text(_t('Готово!', 'Дайын!', 'All done!')),
          ),
        );

  Color _cueColor(int index) => [
    AppColors.green,
    const Color(0xFF9274BA),
    const Color(0xFFB46D32),
  ][index % 3];
  Widget _cue(int index) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Icon(
      [Icons.circle, Icons.change_history, Icons.square][index % 3],
      size: 18,
      color: _cueColor(index),
    ),
  );
}

/// Clips the unchanged image, retaining its aspect ratio before any transform.
class PictureCrop extends StatelessWidget {
  const PictureCrop({super.key, required this.asset, required this.piece});
  final String asset;
  final PicturePiece piece;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: piece.turns.isOdd
          ? piece.crop.height / piece.crop.width
          : piece.crop.width / piece.crop.height,
      child: RotatedBox(
        quarterTurns: piece.turns,
        child: Transform.flip(
          flipX: piece.mirrored,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / piece.crop.width;
              final height = box.maxHeight / piece.crop.height;
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: -piece.crop.left * width,
                      top: -piece.crop.top * height,
                      width: width,
                      height: height,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
