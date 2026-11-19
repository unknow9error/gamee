import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../data/artwork_codec.dart';
import '../data/legacy_archive.dart';
import '../data/legacy_catalog.dart' as legacy;
import '../data/progress_store.dart';
import '../domain/artwork_limits.dart';
import '../domain/calendar.dart';
import '../domain/models.dart';

class GameController extends ChangeNotifier {
  GameController._(this._store, this._now, {Stopwatch? sessionClock})
    : _sessionClock = sessionClock ?? Stopwatch() {
    // A backup must describe a previously committed state, including the
    // initial empty state, never the first still-uncommitted completion.
    _lastGoodSnapshot = _snapshot();
    _sessionClock.start();
  }

  factory GameController.forTest({
    ProgressStore? store,
    DateTime Function()? now,
    Stopwatch? sessionClock,
  }) => GameController._(
    store ?? MemoryProgressStore(),
    now ?? DateTime.now,
    sessionClock: sessionClock,
  );

  factory GameController.inMemory() => GameController.forTest();

  static const storageKey = 'tiny_trails.state.v2';
  static const backupKey = 'tiny_trails.state.backup.v2';
  static const legacyStorageKey = 'tiny_trails.state.v1';
  static const legacyBackupKey = 'tiny_trails.state.backup.v1';
  static const _schemaVersion = 2;
  static const currentInterfaceTourVersion = 1;
  static const maxArtworks = 100;
  static const _maxSnapshotLength = 16 * 1024 * 1024;

  final ProgressStore _store;
  final DateTime Function() _now;
  final Stopwatch _sessionClock;
  Future<void> _writeQueue = Future<void>.value();
  Future<void> _completionQueue = Future<void>.value();
  _PendingWrite? _pendingWrite;
  bool _writing = false;
  String? _lastGoodSnapshot;
  bool _unsupportedVersion = false;
  bool _storageReadBlocked = false;
  Future<void>? _storageRecovery;
  final Set<String> _changedSettings = {};
  final Set<String> _changedDraftIds = {};
  final Set<String> _changedTutorialKeys = {};
  bool _tutorialsCleared = false;
  bool _disposed = false;
  int _revision = 0;
  int _persistedRevision = 0;
  int _resetGeneration = 0;
  int? _backupResetRevision;

  String _language = 'ru';
  bool _sound = true;
  bool _voice = true;
  bool _haptics = true;
  bool _reducedMotion = false;
  bool _onboardingComplete = false;
  int _interfaceTourVersion = 0;
  int _childAge = 6;
  bool _guidanceEnabled = true;
  bool _musicEnabled = false;
  bool _breakReminders = true;
  LegacyArchive? _legacyArchive;
  bool _legacyArchiveCleared = false;
  final Map<String, Set<String>> _activityCalendar = {};
  int _sessionCompletions = 0;
  int _artworkSequence = 0;
  int _completionsAtBreakDismissal = 0;
  Duration _breakSnoozedUntil = Duration.zero;
  _PersistenceIssue? _persistenceIssue;
  final Map<String, LevelProgress> _progress = {};
  final Map<String, Map<String, dynamic>> _drafts = {};
  final List<Artwork> _artworks = [];
  final Set<String> _seenTutorials = {};

  String get language => _language;
  bool get sound => _sound;
  bool get voice => _voice;
  bool get haptics => _haptics;
  bool get reducedMotion => _reducedMotion;
  bool get onboardingComplete => _onboardingComplete;
  bool get needsInterfaceTour =>
      _onboardingComplete &&
      _interfaceTourVersion < currentInterfaceTourVersion;
  int get childAge => _childAge;
  AgeBand get ageBand => AgeBand.fromAge(_childAge);
  bool get guidanceEnabled => _guidanceEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get breakReminders => _breakReminders;
  bool get hasLegacyArchive => _legacyArchive?.hasData ?? false;
  int get legacyCompletedCount => _legacyArchive?.completedCount ?? 0;
  int get legacyDamagedEntries => _legacyArchive?.damagedEntries ?? 0;
  Map<String, LevelProgress> get legacyProgress =>
      _legacyArchive?.progress ?? const {};
  Map<String, Map<String, dynamic>> get legacyDrafts => Map.unmodifiable({
    for (final entry
        in (_legacyArchive?.drafts ?? <String, Map<String, dynamic>>{}).entries)
      entry.key: _copyData(entry.value),
  });
  List<Artwork> get legacyArtworks => List.unmodifiable([
    for (final artwork in _legacyArchive?.artworks ?? <Artwork>[])
      Artwork(
        levelId: artwork.levelId,
        createdAt: artwork.createdAt,
        data: _copyData(artwork.data),
        versionId: artwork.id,
      ),
  ]);
  Map<String, LevelDefinition> get allLevelIndex =>
      Map.unmodifiable({...legacy.legacyLevelIndex, ...levelIndex});
  Map<String, WorldDefinition> get legacyWorldIndex => legacy.legacyWorldIndex;
  List<StickerDefinition> get earnedStickers => stickers
      .where((sticker) => _progress.containsKey(sticker.levelId))
      .toList(growable: false);
  Map<String, Set<String>> get activityCalendar => Map.unmodifiable({
    for (final entry in _activityCalendar.entries)
      entry.key: Set<String>.unmodifiable(entry.value),
  });
  Set<DateTime> get playedDates => Set.unmodifiable(
    _activityCalendar.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => parseCalendarDayKey(entry.key)),
  );
  List<DailyQuestDefinition> get dailyQuests => dailyQuestsFor(_now());
  int dailyQuestProgress(DailyQuestDefinition quest) =>
      (_activityCalendar[quest.dayKey] ?? const <String>{})
          .where((id) => levelIndex[id]?.kind == quest.kind)
          .length
          .clamp(0, quest.target);
  List<PlayDay> get currentWeek {
    final today = calendarDay(_now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    return List.unmodifiable(
      List.generate(7, (index) {
        final date = DateTime(monday.year, monday.month, monday.day + index);
        return PlayDay(
          date: date,
          completedActivities:
              _activityCalendar[calendarDayKey(date)]?.length ?? 0,
          isToday: calendarDayKey(date) == calendarDayKey(today),
        );
      }),
    );
  }

  int get weeklyPlayDays => currentWeek.where((day) => day.played).length;
  int get currentStreak {
    var day = calendarDay(_now());
    if ((_activityCalendar[calendarDayKey(day)] ?? const <String>{}).isEmpty) {
      day = previousCalendarDay(day);
    }
    var count = 0;
    while ((_activityCalendar[calendarDayKey(day)] ?? const <String>{})
        .isNotEmpty) {
      count++;
      day = previousCalendarDay(day);
    }
    return count;
  }

  int get bestStreak {
    final days = playedDates.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      run =
          previous != null &&
              calendarDayKey(previousCalendarDay(day)) ==
                  calendarDayKey(previous)
          ? run + 1
          : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  Duration get foregroundSessionDuration => _sessionClock.elapsed;
  int get sessionCompletedCount => _sessionCompletions;
  bool get shouldSuggestBreak =>
      _breakReminders &&
      _sessionClock.elapsed >= _breakSnoozedUntil &&
      (_sessionClock.elapsed >= const Duration(minutes: 15) ||
          _sessionCompletions - _completionsAtBreakDismissal >= 5);
  String? get persistenceError => switch (_persistenceIssue) {
    null => null,
    _PersistenceIssue.newerVersion => const LocalizedText(
      'Это сохранение создано в новой версии приложения.',
      'Бұл сақтау қолданбаның жаңа нұсқасында жасалған.',
      'This save was created by a newer app version.',
    ).resolve(_language),
    _PersistenceIssue.recoveredBackup => const LocalizedText(
      'Прогресс восстановлен из резервной копии.',
      'Прогресс сақтық көшірмеден қалпына келтірілді.',
      'Progress was restored from the backup.',
    ).resolve(_language),
    _PersistenceIssue.loadFailed => const LocalizedText(
      'Не удалось прочитать сохранение на этом устройстве.',
      'Бұл құрылғыдағы сақталған деректер оқылмады.',
      'Saved progress could not be read on this device.',
    ).resolve(_language),
    _PersistenceIssue.partialRecovery => const LocalizedText(
      'Сохранение восстановлено. Некоторые повреждённые записи пропущены.',
      'Сақталған деректер қалпына келтірілді. Зақымданған жазбалар өткізілді.',
      'Progress was recovered. Some damaged entries were skipped.',
    ).resolve(_language),
    _PersistenceIssue.saveFailed => const LocalizedText(
      'Не удалось сохранить прогресс. Проверьте свободное место на устройстве.',
      'Прогресс сақталмады. Құрылғыдағы бос орынды тексеріңіз.',
      'Progress could not be saved. Check the available space on this device.',
    ).resolve(_language),
    _PersistenceIssue.fullStorage => const LocalizedText(
      'Хранилище рисунков заполнено. Новые изменения пока доступны только в этом сеансе.',
      'Суреттер қоймасы толды. Жаңа өзгерістер әзірше осы сеанста ғана сақталады.',
      'Artwork storage is full. New changes are kept in this session only.',
    ).resolve(_language),
    _PersistenceIssue.artworkLimit => const LocalizedText(
      'Альбом заполнен. Удали ненужную работу, чтобы сохранить новую.',
      'Альбом толды. Жаңа жұмысты сақтау үшін қажетсіз суретті өшір.',
      'Your album is full. Delete a drawing you no longer need to save a new one.',
    ).resolve(_language),
  };
  Map<String, LevelProgress> get progress => Map.unmodifiable(_progress);
  Map<String, Map<String, dynamic>> get drafts => Map.unmodifiable({
    for (final entry in _drafts.entries) entry.key: _copyData(entry.value),
  });
  List<Artwork> get artworks => List.unmodifiable(
    _artworks.map(
      (artwork) => Artwork(
        levelId: artwork.levelId,
        createdAt: artwork.createdAt,
        data: _copyData(artwork.data),
        versionId: artwork.id,
      ),
    ),
  );
  int get totalStars =>
      _progress.values.fold(0, (total, item) => total + item.stars);
  int get completedCount => _progress.length;
  List<AchievementDefinition> get earnedAchievements => achievements
      .where(
        (achievement) => achievementProgress(achievement) >= achievement.target,
      )
      .toList(growable: false);
  LevelDefinition get nextLevel => levels.firstWhere(
    (level) => !_progress.containsKey(level.id) && isUnlocked(level),
    orElse: () => levels.first,
  );

  /// Reading never prints payloads, platform exceptions or personal data.
  static Future<GameController> load({
    ProgressStore? store,
    DateTime Function()? now,
    Stopwatch? sessionClock,
  }) async {
    final controller = GameController._(
      store ?? PreferencesProgressStore(),
      now ?? DateTime.now,
      sessionClock: sessionClock,
    );
    var loadedV2 = false;
    try {
      final primary = await controller._readStateKey(storageKey);
      if (primary == null) {
        final backup = await controller._readStateKey(backupKey);
        if (backup != null) {
          controller._restore(backup);
          loadedV2 = true;
          controller._storageReadBlocked = false;
          controller._persistenceIssue = _PersistenceIssue.recoveredBackup;
        }
      } else {
        controller._restore(primary);
        loadedV2 = true;
        controller._storageReadBlocked = false;
      }
    } on _UnsupportedVersion {
      // Keep the unknown version intact instead of silently destroying it.
      controller._unsupportedVersion = true;
      controller._persistenceIssue = _PersistenceIssue.newerVersion;
    } catch (_) {
      try {
        final backup = await controller._readStateKey(backupKey);
        if (backup != null) {
          controller._restore(backup);
          loadedV2 = true;
          controller._persistenceIssue = _PersistenceIssue.recoveredBackup;
        } else {
          controller._persistenceIssue = _PersistenceIssue.loadFailed;
        }
      } on _UnsupportedVersion {
        controller._unsupportedVersion = true;
        controller._persistenceIssue = _PersistenceIssue.newerVersion;
      } catch (_) {
        controller._persistenceIssue = _PersistenceIssue.loadFailed;
      }
    }
    await controller._loadLegacyArchive(
      useSettings: !loadedV2 && !controller._unsupportedVersion,
    );
    if (controller._storageReadBlocked && !controller._unsupportedVersion) {
      controller._persistenceIssue = _PersistenceIssue.loadFailed;
    }
    // The v2 backup is independent of the immutable v1 archive keys.
    controller._lastGoodSnapshot = controller._snapshot();
    return controller;
  }

  Future<void> _loadLegacyArchive({required bool useSettings}) async {
    if (_legacyArchiveCleared) return;
    var legacyReadFailed = false;
    try {
      final primary = await _store.read(legacyStorageKey);
      if (primary != null) _legacyArchive = LegacyArchive.fromEncoded(primary);
    } catch (_) {
      // Fall through to the old backup without touching either original.
      legacyReadFailed = true;
    }
    if (_legacyArchive == null) {
      try {
        final backup = await _store.read(legacyBackupKey);
        if (backup != null) _legacyArchive = LegacyArchive.fromEncoded(backup);
      } catch (_) {
        _persistenceIssue ??= _PersistenceIssue.loadFailed;
      }
    }
    if (_legacyArchive == null && legacyReadFailed) {
      _persistenceIssue ??= _PersistenceIssue.loadFailed;
    }
    if (useSettings && _legacyArchive != null) {
      final settings = _legacyArchive!.settings;
      _language = const {'ru', 'kk', 'en'}.contains(settings['language'])
          ? settings['language'] as String
          : 'ru';
      _sound = settings['sound'] is bool ? settings['sound'] as bool : true;
      _voice = settings['voice'] is bool ? settings['voice'] as bool : true;
      _haptics = settings['haptics'] is bool
          ? settings['haptics'] as bool
          : true;
      _reducedMotion = settings['reducedMotion'] is bool
          ? settings['reducedMotion'] as bool
          : false;
      // New age-aware onboarding is shown once; the old value stays archived.
      _onboardingComplete = false;
    }
  }

  Future<String?> _readStateKey(String key) async {
    try {
      return await _store.read(key);
    } catch (_) {
      _storageReadBlocked = true;
      rethrow;
    }
  }

  Future<void> setLanguage(String value) {
    if (!const {'ru', 'kk', 'en'}.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported language');
    }
    _language = value;
    _changedSettings.add('language');
    return _changed();
  }

  Future<void> setSound(bool value) {
    _sound = value;
    _changedSettings.add('sound');
    return _changed();
  }

  Future<void> setVoice(bool value) {
    _voice = value;
    _changedSettings.add('voice');
    return _changed();
  }

  Future<void> setHaptics(bool value) {
    _haptics = value;
    _changedSettings.add('haptics');
    return _changed();
  }

  Future<void> setReducedMotion(bool value) {
    _reducedMotion = value;
    _changedSettings.add('reducedMotion');
    return _changed();
  }

  Future<void> setChildAge(int value) {
    final nextBand = AgeBand.fromAge(value);
    if (nextBand != ageBand) {
      _seenTutorials.clear();
      _changedTutorialKeys.clear();
      _tutorialsCleared = true;
    }
    _childAge = value;
    _changedSettings.add('childAge');
    return _changed();
  }

  Future<void> setGuidanceEnabled(bool value) {
    _guidanceEnabled = value;
    _changedSettings.add('guidanceEnabled');
    return _changed();
  }

  Future<void> setMusicEnabled(bool value) {
    _musicEnabled = value;
    _changedSettings.add('musicEnabled');
    return _changed();
  }

  Future<void> setBreakReminders(bool value) {
    _breakReminders = value;
    _changedSettings.add('breakReminders');
    return _changed();
  }

  void resumeSession() {
    _sessionClock.start();
    _notify();
  }

  void pauseSession() {
    _sessionClock.stop();
    _notify();
  }

  void dismissBreakSuggestion({Duration snooze = const Duration(minutes: 10)}) {
    if (snooze.isNegative) throw ArgumentError.value(snooze, 'snooze');
    _breakSnoozedUntil = _sessionClock.elapsed + snooze;
    _completionsAtBreakDismissal = _sessionCompletions;
    _notify();
  }

  Future<void> finishOnboarding() {
    _onboardingComplete = true;
    _changedSettings.add('onboardingComplete');
    return _changed();
  }

  /// Skipping is a deliberate choice too. A new guide version can be offered
  /// after an update without replaying the age-specific activity tutorials.
  Future<void> markInterfaceTourSeen() {
    if (_interfaceTourVersion >= currentInterfaceTourVersion) {
      return Future<void>.value();
    }
    _interfaceTourVersion = currentInterfaceTourVersion;
    _changedSettings.add('interfaceTourVersion');
    return _changed();
  }

  bool hasSeenTutorial(ActivityKind kind) =>
      _seenTutorials.contains('${ageBand.name}:${kind.name}');

  Future<void> markTutorialSeen(ActivityKind kind) {
    final key = '${ageBand.name}:${kind.name}';
    _seenTutorials.add(key);
    _changedTutorialKeys.add(key);
    return _changed();
  }

  Map<String, dynamic>? draftFor(String levelId) {
    final draft = _drafts[levelId];
    return draft == null ? null : _copyData(draft);
  }

  Future<void> saveDraft(String levelId, Map<String, dynamic> data) {
    _requireLevel(levelId);
    final encoded = _validatedArtwork(data);
    _drafts[levelId] = encoded;
    _changedDraftIds.add(levelId);
    return _changed();
  }

  Future<CompletionReward> completeLevel(
    LevelDefinition level, {
    int stars = 3,
    Map<String, dynamic>? artwork,
  }) {
    final requestedGeneration = _resetGeneration;
    final requestedAt = _now();
    final operation = _completionQueue.then(
      (_) => _completeLevelTransaction(
        level,
        stars: stars,
        artwork: artwork,
        requestedGeneration: requestedGeneration,
        requestedAt: requestedAt,
      ),
    );
    // One failed completion must not poison the next explicit retry.
    _completionQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<CompletionReward> _completeLevelTransaction(
    LevelDefinition level, {
    required int stars,
    required Map<String, dynamic>? artwork,
    required int requestedGeneration,
    required DateTime requestedAt,
  }) async {
    await _recoverBlockedStorage();
    if (requestedGeneration != _resetGeneration) {
      throw CompletionPersistenceException(
        const LocalizedText(
          'Прогресс был сброшен. Открой задание ещё раз.',
          'Прогресс тазартылды. Тапсырманы қайта аш.',
          'Progress was reset. Open the activity again.',
        ).resolve(_language),
      );
    }
    final canonical = _requireLevel(level.id);
    if (!isUnlocked(canonical)) throw StateError('Level is locked');
    // Validate before changing anything: a malformed drawing cannot partly
    // award a level or erase a valid draft.
    final safeArtwork = artwork == null ? null : _validatedArtwork(artwork);
    final previous = _progress[level.id];
    final previousDraft = _drafts[level.id];
    if (safeArtwork != null && _artworks.length >= maxArtworks) {
      _drafts[level.id] = safeArtwork;
      _changedDraftIds.add(level.id);
      await _changed();
      _persistenceIssue = _PersistenceIssue.artworkLimit;
      _notify();
      throw ArtworkLimitException(persistenceError!);
    }
    Artwork? newArtwork;
    final generation = _resetGeneration;
    final earnedBefore = earnedAchievements.map((item) => item.id).toSet();
    final now = requestedAt;
    final dayKey = calendarDayKey(now);
    final previousDay = _activityCalendar[dayKey] == null
        ? null
        : Set<String>.from(_activityCalendar[dayKey]!);
    final todayQuests = dailyQuestsFor(now);
    final earnedQuestsBefore = todayQuests
        .where((quest) => dailyQuestProgress(quest) >= quest.target)
        .map((quest) => quest.id)
        .toSet();
    final awardedStars = stars.clamp(1, 3);
    final bestStars = previous == null
        ? awardedStars
        : (awardedStars > previous.stars ? awardedStars : previous.stars);
    _progress[level.id] = LevelProgress(
      stars: bestStars,
      completedAt: previous?.completedAt ?? now,
      attempts: (previous?.attempts ?? 0) + 1,
    );
    _drafts.remove(level.id);
    _activityCalendar.putIfAbsent(dayKey, () => <String>{}).add(level.id);
    if (safeArtwork != null) {
      newArtwork = Artwork(
        levelId: level.id,
        createdAt: now,
        data: safeArtwork,
        versionId: _newArtworkId(level.id, now),
      );
      _artworks.insert(0, newArtwork);
    }
    final newlyEarned = earnedAchievements
        .where((item) => !earnedBefore.contains(item.id))
        .toList(growable: false);
    final completionRevision = _revision + 1;
    await _changed();
    if (generation != _resetGeneration) {
      throw CompletionPersistenceException(
        const LocalizedText(
          'Прогресс был сброшен. Открой задание ещё раз.',
          'Прогресс тазартылды. Тапсырманы қайта аш.',
          'Progress was reset. Open the activity again.',
        ).resolve(_language),
      );
    }
    if (_persistedRevision < completionRevision) {
      // Only this transaction is rolled back; concurrent settings and drafts
      // for other levels remain intact. Keep the finished work for a retry.
      if (previous == null) {
        _progress.remove(level.id);
      } else {
        _progress[level.id] = previous;
      }
      if (newArtwork != null) {
        _artworks.removeWhere((item) => item.id == newArtwork!.id);
      }
      if (safeArtwork != null) {
        _drafts.putIfAbsent(level.id, () => safeArtwork);
      } else if (previousDraft != null) {
        _drafts.putIfAbsent(level.id, () => previousDraft);
      }
      if (previousDay == null) {
        _activityCalendar.remove(dayKey);
      } else {
        _activityCalendar[dayKey] = previousDay;
      }
      final issue = _persistenceIssue ?? _PersistenceIssue.saveFailed;
      // A rollback snapshot contains the retained draft, never an award.
      await _changed();
      _persistenceIssue ??= issue;
      _notify();
      throw CompletionPersistenceException(persistenceError!);
    }
    _sessionCompletions++;
    _notify();
    return CompletionReward(
      stars: bestStars,
      newAchievements: newlyEarned,
      firstCompletion: previous == null,
      newSticker: previous == null
          ? stickers.firstWhere((sticker) => sticker.levelId == level.id)
          : null,
      completedDailyQuests: todayQuests
          .where(
            (quest) =>
                !earnedQuestsBefore.contains(quest.id) &&
                dailyQuestProgress(quest) >= quest.target,
          )
          .toList(growable: false),
    );
  }

  bool isUnlocked(LevelDefinition level) {
    // Children may choose any authored activity. Enum order and age changes
    // never silently lock content or make a daily quest unreachable.
    return levelIndex.containsKey(level.id);
  }

  Future<void> deleteArtwork(String artworkId) {
    final generation = _resetGeneration;
    final operation = _completionQueue.then(
      (_) => _deleteArtworkTransaction(artworkId, generation),
    );
    _completionQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _deleteArtworkTransaction(
    String artworkId,
    int generation,
  ) async {
    await _recoverBlockedStorage();
    if (generation != _resetGeneration) return;
    if (_legacyArchive?.artworks.any((artwork) => artwork.id == artworkId) ??
        false) {
      throw ArtworkReadOnlyException(
        const LocalizedText(
          'Работы из прежней версии хранятся в архиве только для просмотра.',
          'Алдыңғы нұсқаның жұмыстары тек көруге арналған мұрағатта сақталады.',
          'Drawings from the previous version are kept in a read-only archive.',
        ).resolve(_language),
      );
    }
    final index = _artworks.indexWhere((artwork) => artwork.id == artworkId);
    if (index < 0) return;
    final removed = _artworks.removeAt(index);
    final revision = _revision + 1;
    await _changed();
    if (generation != _resetGeneration) return;
    if (_persistedRevision < revision) {
      _artworks.insert(index.clamp(0, _artworks.length), removed);
      final issue = _persistenceIssue ?? _PersistenceIssue.saveFailed;
      await _changed();
      _persistenceIssue ??= issue;
      _notify();
      throw CompletionPersistenceException(persistenceError!);
    }
  }

  int completedForKind(ActivityKind kind) =>
      _progress.keys.where((id) => levelIndex[id]?.kind == kind).length;

  int achievementProgress(AchievementDefinition achievement) =>
      achievement.kind == null
      ? completedCount
      : completedForKind(achievement.kind!);

  int missionProgress(MissionDefinition mission) =>
      mission is DailyQuestDefinition
      ? dailyQuestProgress(mission)
      : completedForKind(mission.kind).clamp(0, mission.target);

  /// An explicitly confirmed reset affects learning data, never preferences.
  Future<void> resetProgress() async {
    _resetGeneration++;
    _progress.clear();
    _drafts.clear();
    _artworks.clear();
    _seenTutorials.clear();
    _changedDraftIds.clear();
    _changedTutorialKeys.clear();
    _activityCalendar.clear();
    _legacyArchive = null;
    _legacyArchiveCleared = true;
    _sessionCompletions = 0;
    _artworkSequence = 0;
    _completionsAtBreakDismissal = 0;
    _sessionClock.reset();
    _breakSnoozedUntil = Duration.zero;
    _unsupportedVersion = false;
    _storageReadBlocked = false;
    final revision = _revision + 1;
    await _changed(resetBackup: true);
    if (_persistedRevision < revision) {
      _persistenceIssue ??= _PersistenceIssue.saveFailed;
      throw CompletionPersistenceException(persistenceError!);
    }
    if (_persistedRevision >= revision) {
      try {
        // A valid empty v1 tombstone clears the archive without adding a
        // destructive storage primitive to the repository interface.
        final emptyArchive = jsonEncode({
          'version': 1,
          'settings': {},
          'progress': {},
          'drafts': {},
          'artworks': [],
        });
        await _store.write(legacyStorageKey, emptyArchive);
        await _store.write(legacyBackupKey, emptyArchive);
      } catch (_) {
        _persistenceIssue = _PersistenceIssue.saveFailed;
        _notify();
        throw CompletionPersistenceException(persistenceError!);
      }
    }
  }

  /// Lets lifecycle handlers and tests wait for all preceding writes.
  Future<void> flush() async {
    await _completionQueue;
    await _writeQueue;
  }

  /// Retries the current draft/settings state, without inventing completion.
  Future<void> retryPersistence() async {
    await _recoverBlockedStorage();
    final revision = _revision + 1;
    await _changed();
    if (_persistedRevision < revision) {
      throw CompletionPersistenceException(
        persistenceError ??
            const LocalizedText(
              'Не удалось сохранить прогресс.',
              'Прогресс сақталмады.',
              'Progress could not be saved.',
            ).resolve(_language),
      );
    }
  }

  /// A platform read failure must never turn an unread save into a writable
  /// empty game. A retry fully reloads first, then merges only local drafts
  /// and explicitly changed preferences into the recovered state.
  Future<void> _recoverBlockedStorage() {
    if (!_storageReadBlocked) return Future<void>.value();
    if (_storageRecovery != null) return _storageRecovery!;
    late Future<void> recovery;
    recovery = _reloadBlockedStorage().whenComplete(() {
      if (identical(_storageRecovery, recovery)) _storageRecovery = null;
    });
    _storageRecovery = recovery;
    return recovery;
  }

  Future<void> _reloadBlockedStorage() async {
    final generation = _resetGeneration;
    final recovered = await GameController.load(store: _store, now: _now);
    if (generation != _resetGeneration) {
      recovered.dispose();
      return;
    }
    if (recovered._storageReadBlocked || recovered._unsupportedVersion) {
      _persistenceIssue =
          recovered._persistenceIssue ?? _PersistenceIssue.loadFailed;
      _unsupportedVersion = recovered._unsupportedVersion;
      recovered.dispose();
      _notify();
      throw CompletionPersistenceException(persistenceError!);
    }
    if (!_changedSettings.contains('language')) {
      _language = recovered.language;
    }
    if (!_changedSettings.contains('sound')) {
      _sound = recovered.sound;
    }
    if (!_changedSettings.contains('voice')) {
      _voice = recovered.voice;
    }
    if (!_changedSettings.contains('haptics')) {
      _haptics = recovered.haptics;
    }
    if (!_changedSettings.contains('reducedMotion')) {
      _reducedMotion = recovered.reducedMotion;
    }
    if (!_changedSettings.contains('childAge')) {
      _childAge = recovered.childAge;
    }
    if (!_changedSettings.contains('guidanceEnabled')) {
      _guidanceEnabled = recovered.guidanceEnabled;
    }
    if (!_changedSettings.contains('musicEnabled')) {
      _musicEnabled = recovered.musicEnabled;
    }
    if (!_changedSettings.contains('breakReminders')) {
      _breakReminders = recovered.breakReminders;
    }
    if (!_changedSettings.contains('onboardingComplete')) {
      _onboardingComplete = recovered.onboardingComplete;
    }
    if (!_changedSettings.contains('interfaceTourVersion')) {
      _interfaceTourVersion = recovered._interfaceTourVersion;
    }
    final localDrafts = {
      for (final entry in _drafts.entries)
        if (_changedDraftIds.contains(entry.key)) entry.key: entry.value,
    };
    final localTutorials = _seenTutorials
        .where(_changedTutorialKeys.contains)
        .toSet();
    _progress
      ..clear()
      ..addAll(recovered._progress);
    _drafts
      ..clear()
      ..addAll(recovered._drafts)
      ..addAll(localDrafts);
    _artworks
      ..clear()
      ..addAll(recovered._artworks);
    if (_artworkSequence < recovered._artworkSequence) {
      _artworkSequence = recovered._artworkSequence;
    }
    _activityCalendar
      ..clear()
      ..addAll(recovered._activityCalendar);
    _seenTutorials
      ..clear()
      ..addAll(_tutorialsCleared ? const <String>{} : recovered._seenTutorials)
      ..addAll(localTutorials);
    _legacyArchive = recovered._legacyArchive;
    _legacyArchiveCleared = recovered._legacyArchiveCleared;
    _lastGoodSnapshot = recovered._lastGoodSnapshot;
    _persistenceIssue = recovered._persistenceIssue;
    _storageReadBlocked = false;
    recovered.dispose();
    _notify();
  }

  LevelDefinition _requireLevel(String id) =>
      levelIndex[id] ??
      (throw ArgumentError.value(id, 'levelId', 'Unknown level'));

  String _newArtworkId(String levelId, DateTime createdAt) {
    String candidate;
    do {
      candidate =
          'art_${levelId}_${createdAt.microsecondsSinceEpoch}_${_artworkSequence++}';
    } while (_artworks.any((artwork) => artwork.id == candidate));
    return candidate;
  }

  Future<void> _changed({bool resetBackup = false}) {
    final revision = ++_revision;
    if (resetBackup) _backupResetRevision = revision;
    if (_unsupportedVersion || _storageReadBlocked) {
      _notify();
      return Future.value();
    }
    final snapshot = _snapshot();
    if (snapshot.length > _maxSnapshotLength) {
      _persistenceIssue = _PersistenceIssue.fullStorage;
      _notify();
      return _writeQueue;
    }
    // Keep only the newest waiting snapshot, rather than retaining a full
    // gallery for every brush stroke while the platform finishes a write.
    _pendingWrite = _PendingWrite(
      snapshot,
      revision,
      resetBackup || (_pendingWrite?.resetBackup ?? false),
    );
    if (!_writing) {
      _writing = true;
      _writeQueue = _drainWrites();
    }
    _notify();
    return _writeQueue;
  }

  Future<void> _drainWrites() async {
    while (_pendingWrite != null) {
      final write = _pendingWrite!;
      _pendingWrite = null;
      try {
        final shouldResetBackup =
            write.resetBackup ||
            (_backupResetRevision != null &&
                write.revision >= _backupResetRevision!);
        await _store.write(
          backupKey,
          shouldResetBackup
              ? write.snapshot
              : (_lastGoodSnapshot ?? write.snapshot),
        );
        await _store.write(storageKey, write.snapshot);
        _lastGoodSnapshot = write.snapshot;
        _persistedRevision = write.revision;
        if (_backupResetRevision != null &&
            write.revision >= _backupResetRevision!) {
          _backupResetRevision = null;
        }
        if (write.revision == _revision && _persistenceIssue != null) {
          _persistenceIssue = null;
          _notify();
        }
      } catch (_) {
        if (write.revision == _revision) {
          _persistenceIssue = _PersistenceIssue.saveFailed;
          _notify();
        }
      }
    }
    _writing = false;
  }

  String _snapshot() => jsonEncode({
    'version': _schemaVersion,
    'settings': {
      'language': _language,
      'sound': _sound,
      'voice': _voice,
      'haptics': _haptics,
      'reducedMotion': _reducedMotion,
      'onboardingComplete': _onboardingComplete,
      'interfaceTourVersion': _interfaceTourVersion,
      'childAge': _childAge,
      'guidanceEnabled': _guidanceEnabled,
      'musicEnabled': _musicEnabled,
      'breakReminders': _breakReminders,
    },
    'progress': {
      for (final entry in _progress.entries) entry.key: entry.value.toJson(),
    },
    'drafts': _drafts,
    'artworks': _artworks.map((item) => item.toJson()).toList(),
    'seenTutorials': _seenTutorials.toList(),
    'activityCalendar': {
      for (final entry in _activityCalendar.entries)
        entry.key: entry.value.toList(),
    },
    'legacyArchiveCleared': _legacyArchiveCleared,
    'artworkSequence': _artworkSequence,
  });

  void _restore(String encoded) {
    if (encoded.length > _maxSnapshotLength) {
      throw const FormatException('Snapshot exceeds limit');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid snapshot');
    }
    final version = decoded['version'];
    if (version is num && version.isFinite && version > _schemaVersion) {
      throw _UnsupportedVersion();
    }
    if (version is! int || version != _schemaVersion) {
      throw const FormatException('Invalid snapshot version');
    }
    final settings = decoded['settings'];
    if (settings is! Map<String, dynamic>) {
      throw const FormatException('Missing settings');
    }
    final restoredProgress = <String, LevelProgress>{};
    final restoredDrafts = <String, Map<String, dynamic>>{};
    final restoredArtworks = <Artwork>[];
    final restoredCalendar = <String, Set<String>>{};
    var recovered = false;
    final storedProgress = decoded['progress'];
    if (storedProgress is Map<String, dynamic>) {
      for (final entry in storedProgress.entries.take(levels.length)) {
        if (!levelIndex.containsKey(entry.key)) continue;
        try {
          final value = Map<String, dynamic>.from(entry.value as Map);
          final stars = value['stars'];
          final attempts = value['attempts'] ?? 1;
          if (stars is! int ||
              stars < 1 ||
              stars > 3 ||
              attempts is! int ||
              attempts < 1 ||
              attempts > 1000000) {
            throw const FormatException('Invalid progress');
          }
          restoredProgress[entry.key] = LevelProgress.fromJson(value);
        } catch (_) {
          recovered = true;
        }
      }
    } else if (storedProgress != null) {
      recovered = true;
    }
    final storedDrafts = decoded['drafts'];
    if (storedDrafts is Map<String, dynamic>) {
      for (final entry in storedDrafts.entries.take(levels.length)) {
        if (!levelIndex.containsKey(entry.key)) continue;
        try {
          restoredDrafts[entry.key] = _validatedArtwork(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {
          recovered = true;
        }
      }
    } else if (storedDrafts != null) {
      recovered = true;
    }
    final storedArtworks = decoded['artworks'];
    if (storedArtworks is List) {
      final seenIds = <String>{};
      if (storedArtworks.length > 1000) {
        throw const FormatException('Artwork history exceeds limit');
      }
      for (final value in storedArtworks) {
        try {
          final item = Artwork.fromJson(
            Map<String, dynamic>.from(value as Map),
          );
          if (!levelIndex.containsKey(item.levelId) || !seenIds.add(item.id)) {
            continue;
          }
          restoredArtworks.add(
            Artwork(
              levelId: item.levelId,
              createdAt: item.createdAt,
              data: _validatedArtwork(item.data),
              versionId: item.id,
            ),
          );
        } catch (_) {
          recovered = true;
        }
      }
    } else if (storedArtworks != null) {
      recovered = true;
    }
    final storedCalendar = decoded['activityCalendar'];
    if (storedCalendar is Map<String, dynamic>) {
      if (storedCalendar.length > 36600) {
        throw const FormatException('Calendar exceeds limit');
      }
      for (final entry in storedCalendar.entries) {
        try {
          parseCalendarDayKey(entry.key);
          if (entry.value is! List) {
            throw const FormatException('Invalid calendar entry');
          }
          final ids = (entry.value as List)
              .whereType<String>()
              .where(levelIndex.containsKey)
              .toSet();
          if (ids.length != (entry.value as List).length) recovered = true;
          if (ids.isNotEmpty) restoredCalendar[entry.key] = ids;
        } catch (_) {
          recovered = true;
        }
      }
    } else if (storedCalendar != null) {
      recovered = true;
    }
    // Commit only after parsing the outer document. Broken entries are isolated.
    _language = const {'ru', 'kk', 'en'}.contains(settings['language'])
        ? settings['language'] as String
        : 'ru';
    _sound = settings['sound'] is bool ? settings['sound'] as bool : true;
    _voice = settings['voice'] is bool ? settings['voice'] as bool : true;
    _haptics = settings['haptics'] is bool ? settings['haptics'] as bool : true;
    _reducedMotion = settings['reducedMotion'] is bool
        ? settings['reducedMotion'] as bool
        : false;
    _onboardingComplete = settings['onboardingComplete'] is bool
        ? settings['onboardingComplete'] as bool
        : false;
    _interfaceTourVersion =
        settings['interfaceTourVersion'] is int &&
            (settings['interfaceTourVersion'] as int) >= 0
        ? settings['interfaceTourVersion'] as int
        : 0;
    _childAge =
        settings['childAge'] is int &&
            (settings['childAge'] as int) >= 3 &&
            (settings['childAge'] as int) <= 11
        ? settings['childAge'] as int
        : 6;
    _guidanceEnabled = settings['guidanceEnabled'] is bool
        ? settings['guidanceEnabled'] as bool
        : true;
    _musicEnabled = settings['musicEnabled'] is bool
        ? settings['musicEnabled'] as bool
        : false;
    _breakReminders = settings['breakReminders'] is bool
        ? settings['breakReminders'] as bool
        : true;
    _legacyArchiveCleared = decoded['legacyArchiveCleared'] == true;
    _artworkSequence =
        decoded['artworkSequence'] is int &&
            (decoded['artworkSequence'] as int) >= 0
        ? decoded['artworkSequence'] as int
        : restoredArtworks.length;
    _progress
      ..clear()
      ..addAll(restoredProgress);
    _drafts
      ..clear()
      ..addAll(restoredDrafts);
    _artworks
      ..clear()
      ..addAll(restoredArtworks);
    _activityCalendar
      ..clear()
      ..addAll(restoredCalendar);
    final seenTutorials = decoded['seenTutorials'];
    _seenTutorials.clear();
    if (seenTutorials is List) {
      _seenTutorials.addAll([
        for (final band in AgeBand.values)
          for (final kind in ActivityKind.values)
            if (seenTutorials.contains('${band.name}:${kind.name}'))
              '${band.name}:${kind.name}',
      ]);
    }
    if (recovered) _persistenceIssue = _PersistenceIssue.partialRecovery;
  }

  static Map<String, dynamic> _copyData(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);

  static Map<String, dynamic> _validatedArtwork(Map<String, dynamic> data) {
    var nodes = 0;
    var nodeLimit = 2000000;
    void validate(Object? value, int depth) {
      if (++nodes > nodeLimit || depth > 12) {
        throw const FormatException('Artwork is too complex');
      }
      if (value == null || value is bool || value is String) return;
      if (value is num && value.isFinite) return;
      if (value is List) {
        for (final item in value) {
          validate(item, depth + 1);
        }
        return;
      }
      if (value is Map && value.keys.every((key) => key is String)) {
        for (final item in value.values) {
          validate(item, depth + 1);
        }
        return;
      }
      throw const FormatException('Artwork must contain finite JSON values');
    }

    validate(data, 0);
    final compact = compactBrushArtwork(data);
    nodes = 0;
    nodeLimit = ArtworkLimits.maxArtworkNodes;
    validate(compact, 0);
    final encoded = jsonEncode(compact);
    if (utf8.encode(encoded).length > ArtworkLimits.maxArtworkBytes) {
      throw const FormatException('Artwork exceeds storage limit');
    }
    return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionClock.stop();
    super.dispose();
  }
}

class _UnsupportedVersion implements Exception {}

/// Completion was not committed. The game keeps the work and can retry the
/// same call; no stars, artwork replacement or achievement is retained.
class CompletionPersistenceException implements Exception {
  const CompletionPersistenceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ArtworkLimitException implements Exception {
  const ArtworkLimitException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ArtworkReadOnlyException implements Exception {
  const ArtworkReadOnlyException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum _PersistenceIssue {
  newerVersion,
  recoveredBackup,
  loadFailed,
  partialRecovery,
  saveFailed,
  fullStorage,
  artworkLimit,
}

class _PendingWrite {
  const _PendingWrite(this.snapshot, this.revision, this.resetBackup);
  final String snapshot;
  final int revision;
  final bool resetBackup;
}
