import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/app_audio_scope.dart';
import '../../core/feedback_service.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../domain/models.dart';
import '../../shared/widgets/activity_tutorial.dart';
import '../../shared/widgets/celebration.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/trail_icon.dart';
import '../home/studio_screen.dart';
import 'activity_config.dart';
import 'choice_activity.dart';
import 'color_activity.dart';
import 'connect_dots_activity.dart';
import 'drawing_activity.dart';
import 'hidden_activity.dart';
import 'matching_activity.dart';
import 'maze_activity.dart';
import 'rope_activity.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.controller, required this.level});

  final GameController controller;
  final LevelDefinition level;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  final _narrationOwner = Object();
  FeedbackService? _feedback;
  AppNarration? _narration;
  bool _ownsAudio = false;
  late final LevelDefinition _activityLevel;
  Map<String, dynamic>? _draft;
  Map<String, dynamic>? _pendingCompletion;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _hint = false;
  bool _completing = false;
  bool _completionCommitted = false;
  bool _checkingVoice = false;
  bool _leaving = false;
  bool _albumOpen = false;
  bool _retrying = false;
  bool _allowPop = false;
  bool _tutorialOpen = false;
  bool _rewardNavigationStarted = false;
  bool _artworkLimit = false;
  int _activityEpoch = 0;
  String? _saveError;

  GameController get _controller => widget.controller;
  bool get _creative => switch (widget.level.kind) {
    ActivityKind.numberColor ||
    ActivityKind.freeColor ||
    ActivityKind.guidedDraw => true,
    _ => false,
  };
  bool get _still =>
      _controller.reducedMotion || MediaQuery.disableAnimationsOf(context);
  bool get _canNarrate =>
      mounted &&
      !_leaving &&
      !_tutorialOpen &&
      !_completing &&
      !_completionCommitted &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  String _t(String ru, String kk, String en) =>
      textFor(_controller.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = _controller.draftFor(widget.level.id);
    _activityLevel = _validatedActivityLevel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_introduceActivity());
    });
  }

  LevelDefinition _validatedActivityLevel() {
    final level = widget.level;
    if (level.activityData['creativeReplay'] != true ||
        (_creative && _controller.progress.containsKey(level.id))) {
      return level;
    }
    final data = Map<String, dynamic>.of(level.activityData)
      ..remove('creativeReplay');
    return LevelDefinition(
      id: level.id,
      worldId: level.worldId,
      kind: level.kind,
      scene: level.scene,
      variant: level.variant,
      difficulty: level.difficulty,
      title: level.title,
      instruction: level.instruction,
      order: level.order,
      illustrationAsset: level.illustrationAsset,
      voiceKey: level.voiceKey,
      activityData: data,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sharedFeedback = AppAudioScope.maybeOf(context);
    final sharedNarration = AppAudioScope.maybeNarrationOf(context);
    if (sharedFeedback != null && sharedNarration != null) {
      if (_ownsAudio) _feedback?.dispose();
      _feedback = sharedFeedback;
      _narration = sharedNarration;
      _ownsAudio = false;
    } else if (_feedback == null) {
      // Standalone previews and isolated screen tests have the same behavior
      // without owning or replacing the app's global music player.
      _feedback = FeedbackService();
      _narration = AppNarration(_feedback!);
      _ownsAudio = true;
    }
  }

  Future<void> _introduceActivity() async {
    if (_controller.guidanceEnabled &&
        !_controller.hasSeenTutorial(widget.level.kind)) {
      await _showTutorial();
    } else {
      await _speakInstruction();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_save());
      unawaited(_narration?.stop(_narrationOwner) ?? Future<void>.value());
    }
    if (_ownsAudio) {
      unawaited(_feedback!.setPaused(state != AppLifecycleState.resumed));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    // Controller notifications cannot run while a route is being unmounted.
    // A replacement screen can already own narration by this point.
    if (!_completionCommitted) {
      unawaited(
        Future<void>.microtask(() async {
          await _save();
        }),
      );
    }
    unawaited(_narration?.stop(_narrationOwner) ?? Future<void>.value());
    if (_ownsAudio) _feedback?.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    _saveTimer?.cancel();
    final data = _draft;
    if (data == null || !_dirty || _completing || _completionCommitted) {
      return true;
    }
    try {
      await _controller.saveDraft(widget.level.id, data);
      if (_controller.persistenceError != null) {
        throw CompletionPersistenceException(_controller.persistenceError!);
      }
      if (identical(data, _draft)) _dirty = false;
      if (mounted && _pendingCompletion == null) {
        setState(() => _saveError = null);
      }
      return true;
    } on Exception {
      if (mounted) {
        setState(() {
          _saveError =
              _controller.persistenceError ??
              _t(
                'Не удалось сохранить работу. Попробуй ещё раз.',
                'Жұмысты сақтау мүмкін болмады. Қайта байқап көр.',
                'Could not save your work. Please try again.',
              );
        });
      }
      return false;
    }
  }

  void _changed(Map<String, dynamic> data) {
    _draft = data;
    if (!_dirty) setState(() => _dirty = true);
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_save()),
    );
  }

  Future<void> _leave() async {
    if (_completing || _leaving) return;
    setState(() => _leaving = true);
    final saved = await _save();
    if (!mounted) return;
    if (!saved) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _t(
              'Работа ещё не сохранена',
              'Жұмыс әлі сақталмады',
              'Your work is not saved yet',
            ),
          ),
          content: Text(
            _t(
              'Можно остаться и попробовать снова. При выходе последние изменения могут потеряться.',
              'Қалып, қайта сақтап көруге болады. Шықсаң, соңғы өзгерістер жоғалуы мүмкін.',
              'You can stay and try again. Leaving may lose your latest changes.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('Остаться', 'Қалу', 'Stay')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Выйти', 'Шығу', 'Leave')),
            ),
          ],
        ),
      );
      if (leave != true) {
        if (mounted) setState(() => _leaving = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showTutorial() async {
    if (!mounted || _tutorialOpen || _completing || _leaving) return;
    _tutorialOpen = true;
    unawaited(_narration?.stop(_narrationOwner) ?? Future<void>.value());
    final ageBand = _controller.ageBand;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      sheetAnimationStyle: _still ? AnimationStyle.noAnimation : null,
      builder: (sheetContext) => ActivityTutorial(
        kind: widget.level.kind,
        level: widget.level,
        language: _controller.language,
        ageBand: ageBand,
        reducedMotion: _still,
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );
    _tutorialOpen = false;
    if (!mounted) return;
    if (ageBand == _controller.ageBand) {
      await _controller.markTutorialSeen(widget.level.kind);
    }
    if (mounted) await _speakInstruction();
  }

  Future<void> _speakInstruction({bool reportUnavailable = false}) async {
    if (_checkingVoice || !_canNarrate) return;
    if (!_controller.voice) {
      if (reportUnavailable) {
        _message(
          _t(
            'Голос можно включить в настройках.',
            'Дауысты баптаулардан қосуға болады.',
            'You can turn voice on in Settings.',
          ),
        );
      }
      return;
    }
    _checkingVoice = true;
    final language = _controller.language;
    final key = widget.level.voiceKey;
    final available = await _feedback!.isSpeechAvailable(
      language,
      narrationKey: key,
    );
    _checkingVoice = false;
    if (!_canNarrate ||
        language != _controller.language ||
        !_controller.voice) {
      return;
    }
    if (!available) {
      if (reportUnavailable) {
        _message(
          _t(
            'Озвучка сейчас недоступна. Нажми «Как играть», чтобы посмотреть показ.',
            'Дыбыстау қазір қолжетімсіз. Көрсету үшін «Қалай ойнау керек» түймесін бас.',
            'Voice is unavailable right now. Open How to play to watch a demonstration.',
          ),
        );
      }
      return;
    }
    await _narration!.speak(
      _narrationOwner,
      widget.level.instruction.resolve(language),
      language,
      enabled: _controller.voice,
      narrationKey: key,
    );
  }

  void _speakDetail(String text) {
    if (!_controller.voice || !_canNarrate) return;
    unawaited(
      _narration!.speak(
        _narrationOwner,
        text,
        _controller.language,
        enabled: true,
      ),
    );
  }

  void _toggleHint() {
    if (_leaving || _completing) return;
    setState(() => _hint = !_hint);
    if (_hint) unawaited(_speakInstruction());
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _completed(Map<String, dynamic> data) async {
    if (_completing || _completionCommitted) return;
    setState(() {
      _completing = true;
      _saveError = null;
      _artworkLimit = false;
    });
    _pendingCompletion = data;
    _draft = data;
    _dirty = true;
    _saveTimer?.cancel();
    late CompletionReward reward;
    try {
      // Puzzle evidence is a resumable draft, not a painting in the album.
      await _controller.saveDraft(widget.level.id, data);
      reward = await _controller.completeLevel(
        widget.level,
        artwork: _creative ? data : null,
      );
    } on ArtworkLimitException catch (error) {
      if (mounted) {
        setState(() {
          _completing = false;
          _artworkLimit = true;
          _saveError = error.message;
        });
      }
      return;
    } on Exception {
      if (mounted) {
        setState(() {
          _completing = false;
          _saveError =
              _controller.persistenceError ??
              _t(
                'Результат пока не сохранён. Твоя работа здесь — попробуй ещё раз.',
                'Нәтиже әлі сақталмады. Жұмысың осында — қайта байқап көр.',
                'Your result hasn’t been saved yet. Your work is still here. Please try again.',
              );
        });
      }
      return;
    }
    _completionCommitted = true;
    _dirty = false;
    _draft = null;
    _pendingCompletion = null;
    if (!mounted) return;
    unawaited(
      _feedback!.success(
        sound: _controller.sound,
        haptics: _controller.haptics,
      ),
    );
    unawaited(
      _narration!.speak(
        _narrationOwner,
        _t(
          'Здорово получилось! Ещё одно открытие.',
          'Керемет шықты! Тағы бір жаңалық.',
          'Wonderful work! One more discovery.',
        ),
        _controller.language,
        enabled: _controller.voice,
        narrationKey: 'cue_success',
      ),
    );
    await showCelebration(
      context,
      level: widget.level,
      reward: reward,
      language: _controller.language,
      ageBand: _controller.ageBand,
      reducedMotion: _still,
      onNext: () => unawaited(_afterReward(continuePlaying: true)),
      onHome: () => unawaited(_afterReward(continuePlaying: false)),
    );
  }

  Future<void> _afterReward({required bool continuePlaying}) async {
    if (_rewardNavigationStarted || !mounted) return;
    _rewardNavigationStarted = true;
    var keepPlaying = continuePlaying;
    if (keepPlaying && _controller.shouldSuggestBreak) {
      keepPlaying = await _suggestBreak();
    }
    if (!mounted) return;
    if (keepPlaying) {
      _nextLevel();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _suggestBreak() async {
    final keepPlaying = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      animationStyle: _still ? AnimationStyle.noAnimation : null,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.paper,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: _t('Закрыть', 'Жабу', 'Close'),
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Image.asset(
                    'assets/images/fini.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'Маленькая пауза?',
                    'Кішкене үзіліс пе?',
                    'A little break?',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    'Можно потянуться, посмотреть вдаль или порисовать на бумаге. Всё уже сохранено.',
                    'Керіліп, алысқа қарап немесе қағазға сурет салуға болады. Бәрі сақталды.',
                    'Stretch, look into the distance, or draw on paper. Your work is already saved.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('break-home'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const TrailIcon(
                      TrailIconKind.rest,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: Text(_t('Отдохнуть', 'Демалу', 'Take a break')),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const Key('break-keep-playing'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _t(
                        'Ещё одно задание',
                        'Тағы бір тапсырма',
                        'One more activity',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _controller.dismissBreakSuggestion();
    return keepPlaying ?? true;
  }

  void _nextLevel() {
    final currentIndex = levels.indexWhere(
      (level) => level.id == widget.level.id,
    );
    final next = levels
        .skip(currentIndex + 1)
        .where(
          (level) =>
              !_controller.progress.containsKey(level.id) &&
              _controller.isUnlocked(level),
        )
        .firstOrNull;
    if (next == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(_route(PlayScreen(controller: _controller, level: next)));
  }

  Route<void> _route(Widget child) => _still
      ? PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        )
      : MaterialPageRoute<void>(builder: (_) => child);

  Future<void> _manageAlbum() async {
    if (_albumOpen || _leaving || _completing) return;
    _albumOpen = true;
    try {
      await _save();
      if (!mounted) return;
      await Navigator.of(context).push(
        _route(
          Scaffold(
            appBar: AppBar(
              title: Text(
                _t('Альбом художника', 'Суретші альбомы', 'My art album'),
              ),
            ),
            body: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => StudioScreen(
                controller: _controller,
                onPlay: (level) => Navigator.of(context).push(
                  _route(PlayScreen(controller: _controller, level: level)),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _albumOpen = false;
    }
  }

  Future<void> _retrySave() async {
    if (_retrying || _leaving || _completing) return;
    setState(() => _retrying = true);
    try {
      final pending = _pendingCompletion;
      if (pending != null) {
        await _completed(pending);
        return;
      }
      await _controller.retryPersistence();
      if (!mounted) return;
      if (_draft == null) {
        final recovered = _controller.draftFor(widget.level.id);
        setState(() {
          _saveError = null;
          if (recovered != null) {
            _draft = recovered;
            _activityEpoch++;
          }
        });
      } else {
        _dirty = true;
        await _save();
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _saveError =
              _controller.persistenceError ??
              _t(
                'Сохранение пока недоступно. Попробуй ещё раз.',
                'Сақтау әзірше қолжетімсіз. Қайта байқап көр.',
                'Saving is still unavailable. Please try again.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget _failureNotice(String message) => Material(
    color: AppColors.yellow.withValues(alpha: .4),
    child: Padding(
      key: const Key('play-save-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              if (_artworkLimit)
                TextButton.icon(
                  key: const Key('manage-artworks'),
                  onPressed: _leaving ? null : _manageAlbum,
                  icon: const TrailIcon(TrailIconKind.album, size: 25),
                  label: Text(
                    _t('Открыть альбом', 'Альбомды ашу', 'Open my album'),
                  ),
                ),
              TextButton(
                key: const Key('retry-completion'),
                onPressed: _retrying || _leaving
                    ? null
                    : () => unawaited(_retrySave()),
                child: Text(_t('Повторить', 'Қайталау', 'Retry')),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _activity(ActivityConfig config) => switch (widget.level.kind) {
    ActivityKind.numberColor ||
    ActivityKind.freeColor => ColorActivity(config: config),
    ActivityKind.maze => MazeActivity(config: config),
    ActivityKind.guidedDraw => DrawingActivity(config: config),
    ActivityKind.hiddenAnimals => HiddenActivity(config: config),
    ActivityKind.oddFragment ||
    ActivityKind.patternSequence ||
    ActivityKind.missingPuzzle => ChoiceActivity(config: config),
    ActivityKind.matchPairs => MatchingActivity(config: config),
    ActivityKind.connectDots => ConnectDotsActivity(config: config),
    ActivityKind.ropeTrace => RopeActivity(config: config),
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final level = widget.level;
      final landscape = MediaQuery.sizeOf(context).aspectRatio > 1.35;
      final ordinal =
          levels.indexWhere((candidate) => candidate.id == level.id) + 1;
      final config = ActivityConfig(
        level: _activityLevel,
        language: _controller.language,
        childAge: _controller.childAge,
        initialData: _draft,
        onChanged: _changed,
        onCompleted: (data) => unawaited(_completed(data)),
        onFeedback: () => unawaited(
          _feedback!.tap(
            sound: _controller.sound,
            haptics: _controller.haptics,
          ),
        ),
        onSpeak: _speakDetail,
        reducedMotion: _still,
        showHint: _hint,
      );
      final error = _saveError ?? _controller.persistenceError;
      return PopScope(
        canPop:
            _allowPop ||
            _completionCommitted ||
            (!_completing && !_dirty && _pendingCompletion == null),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_completing) unawaited(_leave());
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 48,
            titleSpacing: 0,
            leading: IconButton(
              tooltip: _t('Сохранить и выйти', 'Сақтап шығу', 'Save and leave'),
              icon: const Icon(Icons.close_rounded),
              onPressed: _completing || _leaving ? null : _leave,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityName(level.kind, _controller.language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ordinal > 0)
                  Text(
                    '${_t('УРОВЕНЬ', 'ДЕҢГЕЙ', 'LEVEL')} $ordinal / ${levels.length}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.muted,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _t(
                  'Послушать задание',
                  'Тапсырманы тыңдау',
                  'Listen to the task',
                ),
                onPressed: () => _speakInstruction(reportUnavailable: true),
                icon: const TrailIcon(TrailIconKind.speaker, size: 25),
              ),
              IconButton(
                tooltip: _t('Подсказка', 'Көмек', 'Hint'),
                onPressed: _leaving || _completing ? null : _toggleHint,
                icon: TrailIcon(
                  TrailIconKind.hint,
                  selected: _hint,
                  size: 25,
                  color: _leaving || _completing
                      ? AppColors.muted.withValues(alpha: .4)
                      : null,
                ),
              ),
              IconButton(
                tooltip: _t('Как играть', 'Қалай ойнау керек', 'How to play'),
                onPressed: _leaving || _completing ? null : _showTutorial,
                icon: TrailIcon(
                  TrailIconKind.fox,
                  size: 26,
                  color: _leaving || _completing
                      ? AppColors.muted.withValues(alpha: .4)
                      : null,
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (!landscape)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 1, 14, 7),
                    child: Row(
                      children: [
                        Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: activityColor(level.kind),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: TrailIcon(
                              trailActivityKind(level.kind),
                              size: 23,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            level.instruction.resolve(_controller.language),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (error != null) _failureNotice(error),
                Expanded(
                  child: AbsorbPointer(
                    absorbing:
                        _completing || _leaving || _pendingCompletion != null,
                    child: KeyedSubtree(
                      key: ValueKey(_activityEpoch),
                      child: _activity(config),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
