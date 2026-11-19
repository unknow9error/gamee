import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/data/legacy_catalog.dart';
import 'package:tiny_trails/domain/calendar.dart';
import 'package:tiny_trails/domain/models.dart';

class FailingStore extends MemoryProgressStore {
  bool fail = true;
  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<void> write(String key, String value) async {
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) maxConcurrentWrites = activeWrites;
    try {
      await Future<void>.delayed(Duration.zero);
      if (fail) throw StateError('Synthetic write failure');
      await super.write(key, value);
    } finally {
      activeWrites--;
    }
  }
}

class GatedStore extends MemoryProgressStore {
  final gate = Completer<void>();
  int writes = 0;

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writes == 1) await gate.future;
    await super.write(key, value);
  }
}

class ReadFailureStore extends MemoryProgressStore {
  bool failPrimaryRead = false;
  int primaryReads = 0;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (key == GameController.storageKey) primaryReads++;
    if (failPrimaryRead && key == GameController.storageKey) {
      throw StateError('Synthetic platform read failure');
    }
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    return super.write(key, value);
  }
}

class ArchiveEraseFailureStore extends MemoryProgressStore {
  bool failArchiveErase = false;
  @override
  Future<void> write(String key, String value) async {
    if (failArchiveErase && key == GameController.legacyStorageKey) {
      throw StateError('Synthetic archive erase failure');
    }
    return super.write(key, value);
  }
}

class FakeSessionClock implements Stopwatch {
  Duration time = Duration.zero;
  bool running = false;
  void advance(Duration value) {
    if (running) time += value;
  }

  @override
  Duration get elapsed => time;
  @override
  int get elapsedMicroseconds => time.inMicroseconds;
  @override
  int get elapsedMilliseconds => time.inMilliseconds;
  @override
  int get elapsedTicks => time.inMicroseconds;
  @override
  int get frequency => 1000000;
  @override
  bool get isRunning => running;
  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }

  @override
  void reset() {
    time = Duration.zero;
  }
}

String oldSnapshot() => jsonEncode({
  'version': 1,
  'settings': {
    'language': 'kk',
    'sound': false,
    'voice': true,
    'haptics': false,
    'reducedMotion': true,
    'onboardingComplete': true,
  },
  'progress': {
    for (final level in legacyLevels)
      level.id: {
        'stars': 3,
        'completedAt': '2026-11-15T10:30:00.000',
        'attempts': 2,
      },
  },
  'drafts': {
    legacyLevels.last.id: {
      'strokes': [
        {
          'points': List.generate(9000, (i) => [i / 9000, .5]),
          'color': 4278190080,
          'width': 12,
        },
      ],
    },
  },
  'artworks': [
    {
      'levelId': legacyLevels.last.id,
      'createdAt': '2026-11-15T10:30:00.000',
      'data': {
        'strokes': [
          {
            'points': List.generate(9000, (i) => [i / 9000, .5]),
            'color': 4278190080,
            'width': 12,
          },
        ],
      },
    },
  ],
});

void main() {
  test(
    'settings, tutorial, progress, draft and artwork survive a restart',
    () async {
      final store = MemoryProgressStore();
      final controller = await GameController.load(store: store);
      await controller.setLanguage('kk');
      await controller.setSound(false);
      await controller.setVoice(false);
      await controller.setHaptics(false);
      await controller.setReducedMotion(true);
      await controller.setChildAge(10);
      await controller.setGuidanceEnabled(false);
      await controller.setMusicEnabled(true);
      await controller.setBreakReminders(false);
      await controller.finishOnboarding();
      await controller.markTutorialSeen(ActivityKind.numberColor);
      await controller.completeLevel(
        levels[0],
        artwork: {
          'fills': {'a': 2},
        },
      );
      await controller.saveDraft(levels[1].id, {
        'fills': {'b': 3},
      });
      final restored = await GameController.load(store: store);
      expect(restored.language, 'kk');
      expect(restored.sound, isFalse);
      expect(restored.voice, isFalse);
      expect(restored.haptics, isFalse);
      expect(restored.reducedMotion, isTrue);
      expect(restored.childAge, 10);
      expect(restored.ageBand, AgeBand.advanced);
      expect(restored.guidanceEnabled, isFalse);
      expect(restored.musicEnabled, isTrue);
      expect(restored.breakReminders, isFalse);
      expect(restored.onboardingComplete, isTrue);
      expect(restored.hasSeenTutorial(ActivityKind.numberColor), isTrue);
      expect(restored.completedCount, 1);
      expect(restored.totalStars, 3);
      expect(restored.artworks.single.data, {
        'fills': {'a': 2},
      });
      expect(restored.draftFor(levels[1].id), {
        'fills': {'b': 3},
      });
      expect(restored.persistenceError, isNull);
    },
  );

  test(
    'a damaged primary snapshot recovers the previous committed snapshot',
    () async {
      final store = MemoryProgressStore();
      final controller = await GameController.load(store: store);
      await controller.completeLevel(levels[0]);
      await controller.completeLevel(levels[1]);
      store.values[GameController.storageKey] = '{broken';
      final restored = await GameController.load(store: store);
      expect(restored.completedCount, 1);
      expect(restored.progress.containsKey(levels[0].id), isTrue);
      expect(restored.persistenceError, isNotNull);
    },
  );

  test('a missing primary can recover a backup too', () async {
    final store = MemoryProgressStore();
    final controller = await GameController.load(store: store);
    await controller.completeLevel(levels[0]);
    await controller.completeLevel(levels[1]);
    store.values.remove(GameController.storageKey);
    final restored = await GameController.load(store: store);
    expect(restored.completedCount, 1);
    expect(restored.persistenceError, isNotNull);
  });

  test(
    'a corrupted individual record does not discard valid progress',
    () async {
      final store = MemoryProgressStore();
      final controller = await GameController.load(store: store);
      await controller.completeLevel(levels[0]);
      final json = jsonDecode(
        store.values[GameController.storageKey]!,
      ) as Map<String, dynamic>;
      (json['progress'] as Map)[levels[1].id] = {
        'stars': 999,
        'completedAt': 'bad',
      };
      store.values[GameController.storageKey] = jsonEncode(json);
      final restored = await GameController.load(store: store);
      expect(restored.completedCount, 1);
      expect(restored.progress.containsKey(levels[0].id), isTrue);
      expect(restored.persistenceError, isNotNull);
    },
  );

  test('unknown schema is preserved until an explicit reset', () async {
    const futureSnapshot = '{"version":99,"settings":{}}';
    final store = MemoryProgressStore({
      GameController.storageKey: futureSnapshot,
    });
    final controller = await GameController.load(store: store);
    expect(controller.persistenceError, isNotNull);
    await controller.setLanguage('en');
    expect(store.values[GameController.storageKey], futureSnapshot);
    await controller.resetProgress();
    expect(jsonDecode(store.values[GameController.storageKey]!)['version'], 2);
    expect(controller.language, 'en');
  });

  test(
    'reset clears learning data and tutorials but preserves preferences',
    () async {
      final store = MemoryProgressStore();
      final controller = await GameController.load(store: store);
      await controller.setLanguage('en');
      await controller.setSound(false);
      await controller.finishOnboarding();
      await controller.markTutorialSeen(ActivityKind.freeColor);
      await controller.completeLevel(levels[0], artwork: {'fills': {}});
      await controller.saveDraft(levels[1].id, {'fills': {}});
      await controller.resetProgress();
      final restored = await GameController.load(store: store);
      expect(restored.progress, isEmpty);
      expect(restored.drafts, isEmpty);
      expect(restored.artworks, isEmpty);
      expect(restored.earnedAchievements, isEmpty);
      expect(restored.hasSeenTutorial(ActivityKind.freeColor), isFalse);
      expect(restored.onboardingComplete, isTrue);
      expect(restored.language, 'en');
      expect(restored.sound, isFalse);
    },
  );

  test('writes stay ordered and errors are visible, then clear after a successful retry', () async {
    final store = FailingStore();
    final controller = await GameController.load(store: store);
    await expectLater(
      controller.completeLevel(
        levels[0],
        artwork: {
          'fills': {'a': 4},
        },
      ),
      throwsA(isA<CompletionPersistenceException>()),
    );
    expect(controller.persistenceError, isNotNull);
    expect(controller.completedCount, 0);
    expect(controller.earnedAchievements, isEmpty);
    expect(controller.draftFor(levels[0].id), {
      'fills': {'a': 4},
    });
    store.fail = false;
    await Future.wait([
      controller.setLanguage('kk'),
      controller.setSound(false),
      controller.setVoice(false),
    ]);
    expect(store.maxConcurrentWrites, 1);
    expect(controller.persistenceError, isNull);
    final reward = await controller.completeLevel(
      levels[0],
      artwork: controller.draftFor(levels[0].id),
    );
    expect(reward.stars, 3);
    expect(reward.firstCompletion, isTrue);
    expect(
      reward.newAchievements.map((item) => item.id),
      contains('first_step'),
    );
    final restored = await GameController.load(store: store);
    expect(restored.completedCount, 1);
    expect(restored.language, 'kk');
    expect(restored.sound, isFalse);
    expect(restored.voice, isFalse);
  });

  test('rapid changes coalesce to one waiting snapshot and flush keeps the latest state', () async {
    final store = GatedStore();
    final controller = await GameController.load(store: store);
    final writes = <Future<void>>[];
    for (var i = 0; i < 100; i++) {
      writes.add(controller.saveDraft(levels.first.id, {'point': i}));
    }
    expect(store.writes, 1);
    store.gate.complete();
    await Future.wait(writes);
    await controller.flush();
    expect(store.writes, 4);
    final restored = await GameController.load(store: store);
    expect(restored.draftFor(levels.first.id), {'point': 99});
  });

  test(
    'confirmed reset removes old learning data from the backup as well',
    () async {
      final store = MemoryProgressStore();
      final controller = await GameController.load(store: store);
      await controller.completeLevel(
        levels.first,
        artwork: {
          'fills': {'body': 1},
        },
      );
      await controller.resetProgress();
      store.values[GameController.storageKey] = 'broken';
      final restored = await GameController.load(store: store);
      expect(restored.progress, isEmpty);
      expect(restored.artworks, isEmpty);
    },
  );

  test('missing and malformed versions recover completed progress from a valid backup', () async {
    final seedStore = MemoryProgressStore();
    final controller = await GameController.load(store: seedStore);
    await controller.completeLevel(levels.first);
    await controller.setLanguage('en');
    for (final version in [null, 'bad', -1, 1.0]) {
      final store = MemoryProgressStore(seedStore.values);
      store.values[GameController.storageKey] = jsonEncode({
        'version': ?version,
        'settings': {},
      });
      final restored = await GameController.load(store: store);
      expect(restored.completedCount, 1, reason: 'version=$version');
      expect(restored.persistenceError, contains('резервной копии'));
    }
  });

  test('failed replay restores the previous award and painting, then retries without duplicate rewards', () async {
    final store = FailingStore()..fail = false;
    final controller = await GameController.load(store: store);
    await controller.completeLevel(
      levels.first,
      artwork: {
        'fills': {'body': 1},
      },
    );
    store.fail = true;
    await expectLater(
      controller.completeLevel(
        levels.first,
        stars: 1,
        artwork: {
          'fills': {'body': 2},
        },
      ),
      throwsA(isA<CompletionPersistenceException>()),
    );
    expect(controller.progress[levels.first.id]!.attempts, 1);
    expect(controller.totalStars, 3);
    expect(controller.artworks.single.data['fills']['body'], 1);
    expect(controller.draftFor(levels.first.id)!['fills']['body'], 2);
    final restartedAfterFailure = await GameController.load(store: store);
    expect(restartedAfterFailure.totalStars, 3);
    expect(restartedAfterFailure.artworks.single.data['fills']['body'], 1);
    store.fail = false;
    final reward = await controller.completeLevel(
      levels.first,
      artwork: controller.draftFor(levels.first.id),
    );
    expect(reward.firstCompletion, isFalse);
    expect(reward.newAchievements, isEmpty);
    expect(controller.progress[levels.first.id]!.attempts, 2);
    expect(controller.artworks, hasLength(2));
    expect(controller.artworks.first.data['fills']['body'], 2);
  });

  test('completion remains committed when settings change during its pending write', () async {
    final store = GatedStore();
    final controller = await GameController.load(store: store);
    final completion = controller.completeLevel(levels.first);
    await Future<void>.delayed(Duration.zero);
    final language = controller.setLanguage('en');
    final sound = controller.setSound(false);
    store.gate.complete();
    final reward = await completion;
    await Future.wait([language, sound]);
    expect(reward.firstCompletion, isTrue);
    final restored = await GameController.load(store: store);
    expect(restored.completedCount, 1);
    expect(restored.language, 'en');
    expect(restored.sound, isFalse);
  });

  test(
    'reset while completion is being written cannot resurrect a reward',
    () async {
      final store = GatedStore();
      final controller = await GameController.load(store: store);
      final completion = controller.completeLevel(levels.first);
      final assertion = expectLater(
        completion,
        throwsA(isA<CompletionPersistenceException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final reset = controller.resetProgress();
      store.gate.complete();
      await reset;
      await assertion;
      expect(controller.completedCount, 0);
      final restored = await GameController.load(store: store);
      expect(restored.completedCount, 0);
    },
  );

  test('v1 migration preserves all120 records and drawings without mixing active rewards', () async {
    final original = oldSnapshot();
    final store = MemoryProgressStore({
      GameController.legacyStorageKey: original,
      GameController.legacyBackupKey: original,
    });
    final c = await GameController.load(store: store);
    expect(c.legacyCompletedCount, 120);
    expect(c.legacyProgress.length, 120);
    expect(c.completedCount, 0);
    expect(c.totalStars, 0);
    expect(c.earnedStickers, isEmpty);
    expect(
      c.legacyArtworks.single.data['strokes'][0]['points'],
      hasLength(9000),
    );
    expect(
      c.legacyDrafts[legacyLevels.last.id]!['strokes'][0]['points'],
      hasLength(9000),
    );
    expect(c.allLevelIndex.length, 140);
    expect(c.legacyWorldIndex.containsKey('farm'), isTrue);
    expect(c.language, 'kk');
    expect(c.sound, isFalse);
    expect(c.onboardingComplete, isFalse);
    await c.completeLevel(levels.first);
    expect(c.completedCount, 1);
    expect(c.legacyCompletedCount, 120);
    expect(store.values[GameController.legacyStorageKey], original);
    expect(store.values[GameController.legacyBackupKey], original);
    final restarted = await GameController.load(store: store);
    expect(restarted.completedCount, 1);
    expect(restarted.legacyCompletedCount, 120);
    expect(
      restarted.legacyArtworks.single.data['strokes'][0]['points'],
      hasLength(9000),
    );
  });

  test(
    'failed first v2 completion keeps both original v1 keys unchanged',
    () async {
      final original = oldSnapshot();
      final store = FailingStore();
      store.values.addAll({
        GameController.legacyStorageKey: original,
        GameController.legacyBackupKey: original,
      });
      final c = await GameController.load(store: store);
      await expectLater(
        c.completeLevel(levels.first),
        throwsA(isA<CompletionPersistenceException>()),
      );
      expect(c.completedCount, 0);
      expect(c.activityCalendar, isEmpty);
      expect(c.sessionCompletedCount, 0);
      expect(store.values[GameController.legacyStorageKey], original);
      expect(store.values[GameController.legacyBackupKey], original);
      final restarted = await GameController.load(store: store);
      expect(restarted.completedCount, 0);
      expect(restarted.legacyCompletedCount, 120);
    },
  );

  test('damaged v1 primary recovers the untouched old backup', () async {
    final store = MemoryProgressStore({
      GameController.legacyStorageKey: 'broken',
      GameController.legacyBackupKey: oldSnapshot(),
    });
    final c = await GameController.load(store: store);
    expect(c.legacyCompletedCount, 120);
    await c.completeLevel(levels.first);
    expect(store.values[GameController.legacyStorageKey], 'broken');
    expect(store.values[GameController.legacyBackupKey], oldSnapshot());
  });

  test('confirmed reset clears archived and active data while preserving parent choices', () async {
    final store = MemoryProgressStore({
      GameController.legacyStorageKey: oldSnapshot(),
      GameController.legacyBackupKey: oldSnapshot(),
    });
    final c = await GameController.load(store: store);
    await c.setChildAge(11);
    await c.setMusicEnabled(true);
    await c.setGuidanceEnabled(false);
    await c.setBreakReminders(false);
    await c.completeLevel(levels.first);
    await c.resetProgress();
    final restarted = await GameController.load(store: store);
    expect(restarted.hasLegacyArchive, isFalse);
    expect(restarted.legacyProgress, isEmpty);
    expect(restarted.legacyArtworks, isEmpty);
    expect(restarted.legacyDrafts, isEmpty);
    expect(restarted.completedCount, 0);
    expect(restarted.activityCalendar, isEmpty);
    expect(restarted.childAge, 11);
    expect(restarted.musicEnabled, isTrue);
    expect(restarted.guidanceEnabled, isFalse);
    expect(restarted.breakReminders, isFalse);
    expect(
      (jsonDecode(store.values[GameController.legacyStorageKey]!)
          as Map)['progress'],
      isEmpty,
    );
    store.values[GameController.storageKey] = 'broken';
    final backupRestore = await GameController.load(store: store);
    expect(backupRestore.hasLegacyArchive, isFalse);
    expect(backupRestore.completedCount, 0);
  });

  test(
    'tutorials adapt to age band without erasing earlier progress',
    () async {
      final store = MemoryProgressStore();
      final c = await GameController.load(store: store);
      await c.markTutorialSeen(ActivityKind.matchPairs);
      await c.completeLevel(levels[3]);
      await c.setChildAge(3);
      expect(c.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
      await c.markTutorialSeen(ActivityKind.matchPairs);
      await c.setChildAge(11);
      expect(c.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
      await c.setChildAge(6);
      expect(c.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
      final restarted = await GameController.load(store: store);
      expect(restarted.completedCount, 1);
      expect(restarted.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
    },
  );

  test('daily quests are deterministic and successful replays remain useful after all20 levels', () async {
    var today = DateTime(2026, 11, 16, 12);
    final store = MemoryProgressStore();
    final c = await GameController.load(store: store, now: () => today);
    for (final level in levels) {
      await c.completeLevel(level);
    }
    expect(c.earnedStickers, hasLength(20));
    expect(c.dailyQuests, hasLength(3));
    expect(c.dailyQuests.map((q) => q.kind).toSet(), hasLength(3));
    final ids = c.dailyQuests.map((q) => q.id).toList();
    final restarted = await GameController.load(store: store, now: () => today);
    expect(restarted.dailyQuests.map((q) => q.id).toList(), ids);
    final firstCompleted = c.progress[levels.first.id]!.completedAt;
    today = DateTime(2026, 11, 17, 12);
    final quest = c.dailyQuests.first;
    expect(c.dailyQuestProgress(quest), 0);
    final level = levels.firstWhere((l) => l.kind == quest.kind);
    final reward = await c.completeLevel(level);
    expect(reward.newSticker, isNull);
    expect(reward.firstCompletion, isFalse);
    expect(reward.completedDailyQuests.map((q) => q.id), contains(quest.id));
    expect(c.dailyQuestProgress(quest), 1);
    final replay = await c.completeLevel(level);
    expect(replay.completedDailyQuests, isEmpty);
    expect(c.activityCalendar[calendarDayKey(today)], hasLength(1));
    expect(c.earnedStickers, hasLength(20));
    expect(c.progress[levels.first.id]!.completedAt, firstCompleted);
  });

  test(
    'play calendar preserves accumulated days and best streak after a break',
    () async {
      var today = DateTime(2026, 11, 14, 12);
      final c = GameController.forTest(now: () => today);
      for (var day = 14; day <= 16; day++) {
        today = DateTime(2026, 11, day, 12);
        await c.completeLevel(levels.first);
        await c.completeLevel(levels.first);
      }
      today = DateTime(2026, 11, 17, 12);
      expect(c.currentStreak, 3);
      expect(c.bestStreak, 3);
      expect(c.playedDates, hasLength(3));
      expect(c.weeklyPlayDays, 1);
      expect(c.currentWeek.first.date, DateTime(2026, 11, 16));
      expect(c.currentWeek, hasLength(7));
      today = DateTime(2026, 11, 18, 12);
      expect(c.currentStreak, 0);
      expect(c.bestStreak, 3);
      expect(c.playedDates, hasLength(3));
      expect(c.earnedStickers, hasLength(1));
    },
  );

  test(
    'completion fixes its calendar day before a write crosses midnight',
    () async {
      var today = DateTime(2026, 11, 16, 23, 59, 59);
      final store = GatedStore();
      final c = await GameController.load(store: store, now: () => today);
      final quest = c.dailyQuests.first;
      final level = levels.firstWhere((l) => l.kind == quest.kind);
      final pending = c.completeLevel(level);
      await Future<void>.delayed(Duration.zero);
      today = DateTime(2026, 11, 17, 0, 0, 2);
      store.gate.complete();
      final reward = await pending;
      expect(c.activityCalendar.keys, contains('2026-11-16'));
      expect(c.activityCalendar.keys, isNot(contains('2026-11-17')));
      expect(
        reward.completedDailyQuests.map((q) => q.dayKey),
        contains('2026-11-16'),
      );
    },
  );

  test(
    'failed completion rolls back calendar, quests, stickers and session count',
    () async {
      final store = FailingStore();
      final c = await GameController.load(
        store: store,
        now: () => DateTime(2026, 11, 16, 12),
      );
      final quest = c.dailyQuests.first;
      final level = levels.firstWhere((l) => l.kind == quest.kind);
      await expectLater(
        c.completeLevel(level),
        throwsA(isA<CompletionPersistenceException>()),
      );
      expect(c.activityCalendar, isEmpty);
      expect(c.dailyQuestProgress(quest), 0);
      expect(c.earnedStickers, isEmpty);
      expect(c.sessionCompletedCount, 0);
      store.fail = false;
      final reward = await c.completeLevel(level);
      expect(reward.newSticker, isNotNull);
      expect(reward.completedDailyQuests, hasLength(1));
      expect(c.sessionCompletedCount, 1);
    },
  );

  test(
    'session break suggestions use foreground time and never lock an activity',
    () async {
      final clock = FakeSessionClock();
      final c = GameController.forTest(sessionClock: clock);
      clock.advance(const Duration(minutes: 10));
      expect(c.shouldSuggestBreak, isFalse);
      c.pauseSession();
      clock.advance(const Duration(hours: 1));
      expect(c.foregroundSessionDuration, const Duration(minutes: 10));
      c.resumeSession();
      clock.advance(const Duration(minutes: 6));
      expect(c.shouldSuggestBreak, isTrue);
      expect(levels.every(c.isUnlocked), isTrue);
      c.dismissBreakSuggestion();
      clock.advance(const Duration(minutes: 9));
      expect(c.shouldSuggestBreak, isFalse);
      clock.advance(const Duration(minutes: 2));
      expect(c.shouldSuggestBreak, isTrue);
      await c.setBreakReminders(false);
      expect(c.shouldSuggestBreak, isFalse);
      expect(levels.every(c.isUnlocked), isTrue);
    },
  );

  test(
    'five committed practice activities can suggest a break without a timer',
    () async {
      final clock = FakeSessionClock();
      final c = GameController.forTest(sessionClock: clock);
      for (var i = 0; i < 4; i++) {
        await c.completeLevel(levels.first);
      }
      expect(c.shouldSuggestBreak, isFalse);
      await c.completeLevel(levels.first);
      expect(c.shouldSuggestBreak, isTrue);
      expect(c.completedCount, 1);
      expect(c.activityCalendar.values.single, hasLength(1));
      c.dismissBreakSuggestion();
      expect(c.shouldSuggestBreak, isFalse);
    },
  );

  test('unread primary cannot be overwritten by backup or defaults, and retry reloads before writing', () async {
    final store = ReadFailureStore();
    final first = await GameController.load(store: store);
    await first.completeLevel(
      levels[0],
      artwork: {
        'fills': {'a': 1},
      },
    );
    await first.completeLevel(
      levels[1],
      artwork: {
        'fills': {'b': 2},
      },
    );
    final primaryBefore = store.values[GameController.storageKey];
    final backupBefore = store.values[GameController.backupKey];
    store.failPrimaryRead = true;
    final c = await GameController.load(store: store);
    expect(
      c.completedCount,
      1,
      reason: 'The older backup may be displayed while primary is unreadable',
    );
    final writesBefore = store.writes;
    await c.setLanguage('en');
    await c.saveDraft(levels[2].id, {'work': 'keep my new work'});
    await expectLater(
      c.completeLevel(levels[2]),
      throwsA(isA<CompletionPersistenceException>()),
    );
    expect(store.writes, writesBefore);
    expect(store.values[GameController.storageKey], primaryBefore);
    expect(store.values[GameController.backupKey], backupBefore);
    store.failPrimaryRead = false;
    final reward = await c.completeLevel(
      levels[2],
      artwork: c.draftFor(levels[2].id),
    );
    expect(reward.firstCompletion, isTrue);
    final restarted = await GameController.load(store: store);
    expect(restarted.completedCount, 3);
    expect(
      restarted.artworks.any(
        (art) => art.levelId == levels[1].id && art.data['fills']['b'] == 2,
      ),
      isTrue,
    );
    expect(restarted.language, 'en');
    expect(restarted.artworks.first.data, {'work': 'keep my new work'});
  });

  test('failed reset reports failure, preserves on-disk v1 and v2, and explicit retry clears both', () async {
    final store = FailingStore()..fail = false;
    final original = oldSnapshot();
    store.values[GameController.legacyStorageKey] = original;
    store.values[GameController.legacyBackupKey] = original;
    final c = await GameController.load(store: store);
    await c.completeLevel(levels.first);
    store.fail = true;
    await expectLater(
      c.resetProgress(),
      throwsA(isA<CompletionPersistenceException>()),
    );
    expect(c.persistenceError, isNotNull);
    expect(store.values[GameController.legacyStorageKey], original);
    final restarted = await GameController.load(store: store);
    expect(restarted.completedCount, 1);
    expect(restarted.legacyCompletedCount, 120);
    store.fail = false;
    await c.resetProgress();
    final clean = await GameController.load(store: store);
    expect(clean.completedCount, 0);
    expect(clean.hasLegacyArchive, isFalse);
  });

  test('archive erase failure is visible and reset tombstone prevents old history from returning', () async {
    final store = ArchiveEraseFailureStore();
    store.values[GameController.legacyStorageKey] = oldSnapshot();
    final c = await GameController.load(store: store);
    await c.completeLevel(levels.first);
    store.failArchiveErase = true;
    await expectLater(
      c.resetProgress(),
      throwsA(isA<CompletionPersistenceException>()),
    );
    expect(c.persistenceError, isNotNull);
    final clean = await GameController.load(store: store);
    expect(clean.completedCount, 0);
    expect(clean.hasLegacyArchive, isFalse);
    store.failArchiveErase = false;
    await c.resetProgress();
    expect(
      jsonDecode(store.values[GameController.legacyStorageKey]!)['progress'],
      isEmpty,
    );
  });

  test('artwork history preserves every creative replay with stable IDs across a restart', () async {
    final store = MemoryProgressStore();
    final time = DateTime(2026, 11, 17, 12);
    final c = await GameController.load(store: store, now: () => time);
    for (var version = 1; version <= 3; version++) {
      await c.completeLevel(levels.first, artwork: {'painting': version});
    }
    expect(c.artworks.map((art) => art.data['painting']).toList(), [3, 2, 1]);
    final ids = c.artworks.map((art) => art.id).toList();
    expect(ids.toSet(), hasLength(3));
    final restarted = await GameController.load(store: store, now: () => time);
    expect(restarted.artworks.map((art) => art.id).toList(), ids);
    await restarted.completeLevel(levels.first, artwork: {'painting': 4});
    expect(restarted.artworks.map((art) => art.id).toSet(), hasLength(4));
    expect(restarted.completedCount, 1);
    expect(restarted.earnedStickers, hasLength(1));
    await restarted.deleteArtwork(ids[1]);
    expect(restarted.artworks.map((art) => art.data['painting']).toList(), [
      4,
      3,
      1,
    ]);
    await restarted.deleteArtwork(ids[1]);
    expect(restarted.artworks, hasLength(3));
    final afterDelete = await GameController.load(store: store);
    expect(afterDelete.artworks.map((art) => art.data['painting']).toList(), [
      4,
      3,
      1,
    ]);
    expect(afterDelete.completedCount, 1);
  });

  test(
    'failed artwork deletion rolls back the exact version and can be retried',
    () async {
      final store = FailingStore()..fail = false;
      final c = await GameController.load(store: store);
      await c.completeLevel(levels.first, artwork: {'painting': 1});
      await c.completeLevel(levels.first, artwork: {'painting': 2});
      final ids = c.artworks.map((art) => art.id).toList();
      store.fail = true;
      await expectLater(
        c.deleteArtwork(ids.first),
        throwsA(isA<CompletionPersistenceException>()),
      );
      expect(c.artworks.map((art) => art.id).toList(), ids);
      final beforeRetry = await GameController.load(store: store);
      expect(beforeRetry.artworks.map((art) => art.id).toList(), ids);
      store.fail = false;
      await c.deleteArtwork(ids.first);
      expect(c.artworks.single.id, ids.last);
      final restarted = await GameController.load(store: store);
      expect(restarted.artworks.single.id, ids.last);
    },
  );

  test(
    'legacy artwork is read-only and excluded from the active version limit',
    () async {
      final original = oldSnapshot();
      final store = MemoryProgressStore({
        GameController.legacyStorageKey: original,
      });
      final c = await GameController.load(store: store);
      expect(c.artworks, isEmpty);
      await expectLater(
        c.deleteArtwork(c.legacyArtworks.single.id),
        throwsA(isA<ArtworkReadOnlyException>()),
      );
      expect(c.legacyArtworks, hasLength(1));
      expect(store.values[GameController.legacyStorageKey], original);
    },
  );

  test('album capacity never evicts old versions and deleting one allows an explicit retry', () async {
    final store = MemoryProgressStore();
    final c = await GameController.load(store: store);
    for (var i = 0; i < GameController.maxArtworks; i++) {
      await c.completeLevel(levels.first, artwork: {'painting': i});
    }
    final ids = c.artworks.map((art) => art.id).toList();
    await expectLater(
      c.completeLevel(levels.first, artwork: {'painting': 1000}),
      throwsA(isA<ArtworkLimitException>()),
    );
    expect(c.artworks.map((art) => art.id).toList(), ids);
    expect(c.draftFor(levels.first.id), {'painting': 1000});
    expect(c.completedCount, 1);
    await c.deleteArtwork(ids.last);
    await c.completeLevel(levels.first, artwork: c.draftFor(levels.first.id));
    expect(c.artworks, hasLength(GameController.maxArtworks));
    expect(c.artworks.first.data, {'painting': 1000});
    final restarted = await GameController.load(store: store);
    expect(restarted.artworks, hasLength(GameController.maxArtworks));
    expect(restarted.artworks.first.data, {'painting': 1000});
  });

  test('read recovery preserves artwork ID sequence for replay of the same level at a repeated timestamp', () async {
    final store = ReadFailureStore();
    final fixed = DateTime(2026, 11, 17, 12);
    final first = await GameController.load(store: store, now: () => fixed);
    await first.completeLevel(levels.first, artwork: {'painting': 1});
    await first.completeLevel(levels.first, artwork: {'painting': 2});
    store.failPrimaryRead = true;
    final recovered = await GameController.load(store: store, now: () => fixed);
    expect(recovered.artworks, hasLength(1));
    store.failPrimaryRead = false;
    await recovered.completeLevel(levels.first, artwork: {'painting': 3});
    expect(recovered.artworks.map((art) => art.id).toSet(), hasLength(3));
    final restarted = await GameController.load(store: store, now: () => fixed);
    expect(restarted.artworks.map((art) => art.data['painting']).toList(), [
      3,
      2,
      1,
    ]);
    expect(restarted.artworks.map((art) => art.id).toSet(), hasLength(3));
  });

  test('completion and manual retry share one recovery and cannot overwrite a committed artwork version', () async {
    final store = ReadFailureStore();
    final fixed = DateTime(2026, 11, 17, 12);
    final first = await GameController.load(store: store, now: () => fixed);
    await first.completeLevel(levels.first, artwork: {'painting': 1});
    await first.completeLevel(levels.first, artwork: {'painting': 2});
    store.failPrimaryRead = true;
    final c = await GameController.load(store: store, now: () => fixed);
    store.failPrimaryRead = false;
    final readsBefore = store.primaryReads;
    final completion = c.completeLevel(levels.first, artwork: {'painting': 3});
    final retry = c.retryPersistence();
    await retry;
    await completion;
    expect(store.primaryReads, readsBefore + 1);
    expect(c.artworks.map((art) => art.id).toSet(), hasLength(3));
    final restarted = await GameController.load(store: store, now: () => fixed);
    expect(restarted.artworks.map((art) => art.data['painting']).toList(), [
      3,
      2,
      1,
    ]);
  });

  test(
    'changing age within one band preserves seen introductions across restart',
    () async {
      final store = MemoryProgressStore();
      final c = await GameController.load(store: store);
      await c.setChildAge(6);
      await c.markTutorialSeen(ActivityKind.matchPairs);
      await c.markTutorialSeen(ActivityKind.numberColor);
      await c.setChildAge(8);
      expect(c.hasSeenTutorial(ActivityKind.matchPairs), isTrue);
      expect(c.hasSeenTutorial(ActivityKind.numberColor), isTrue);
      final restarted = await GameController.load(store: store);
      expect(restarted.childAge, 8);
      expect(restarted.hasSeenTutorial(ActivityKind.matchPairs), isTrue);
      expect(restarted.hasSeenTutorial(ActivityKind.numberColor), isTrue);
    },
  );

  test('changing age band clears introductions persistently without altering progress or artwork', () async {
    final store = MemoryProgressStore();
    final c = await GameController.load(store: store);
    await c.markTutorialSeen(ActivityKind.matchPairs);
    await c.markTutorialSeen(ActivityKind.numberColor);
    await c.completeLevel(levels.first, artwork: {'painting': 'keep this'});
    final artworkId = c.artworks.single.id;
    await c.setChildAge(9);
    expect(
      activeActivityKinds.every((kind) => !c.hasSeenTutorial(kind)),
      isTrue,
    );
    final restarted = await GameController.load(store: store);
    expect(restarted.ageBand, AgeBand.advanced);
    expect(
      activeActivityKinds.every((kind) => !restarted.hasSeenTutorial(kind)),
      isTrue,
    );
    expect(restarted.completedCount, 1);
    expect(restarted.totalStars, 3);
    expect(restarted.artworks.single.id, artworkId);
    expect(restarted.artworks.single.data, {'painting': 'keep this'});
    await restarted.markTutorialSeen(ActivityKind.matchPairs);
    await restarted.setChildAge(6);
    expect(restarted.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
    final returned = await GameController.load(store: store);
    expect(returned.hasSeenTutorial(ActivityKind.matchPairs), isFalse);
    expect(returned.completedCount, 1);
    expect(returned.artworks.single.id, artworkId);
  });
}
