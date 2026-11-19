import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/domain/calendar.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/progress/progress_screen.dart';
import 'package:tiny_trails/shared/widgets/trail_icon.dart';

import 'support/widget_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> showProgress(
    WidgetTester tester,
    GameController controller, {
    ValueChanged<LevelDefinition>? onPlay,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            body: ProgressScreen(
              controller: controller,
              onPlay: onPlay ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openBadges(WidgetTester tester) async {
    final tab = find.byKey(const ValueKey('collection-tab-badges'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  testWidgets('the collection renders exactly twenty distinct sticker states', (
    tester,
  ) async {
    final controller = GameController.forTest(
      now: () => DateTime(2026, 11, 17),
    );
    addTearDown(controller.dispose);
    await controller.completeLevel(levels.first);
    await showProgress(tester, controller);

    expect(stickers.length, 20);
    for (final sticker in stickers) {
      final card = find.byKey(ValueKey('sticker-${sticker.id}'));
      expect(card, findsOneWidget);
      final earned = sticker.levelId == levels.first.id;
      expect(
        find.descendant(
          of: card,
          matching: find.text(earned ? 'Собрано' : 'Ждёт открытия'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: earned
              ? find.byWidgetPredicate(
                  (widget) =>
                      widget is TrailIcon && widget.kind == TrailIconKind.check,
                )
              : find.byIcon(Icons.lock_outline_rounded),
        ),
        findsOneWidget,
      );
    }
    // Opening an already saved collection never invents a new reward event.
    expect(
      find.byKey(const ValueKey('milestone-celebration-first_step')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('collection-tab-stickers')),
        matching: find.text('1 / 20'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'each today quest opens an unlocked unfinished level of its kind',
    (tester) async {
      var now = DateTime(2026, 11, 16);
      final controller = GameController.forTest(now: () => now);
      addTearDown(controller.dispose);
      final nextDay = DateTime(2026, 11, 17);
      final tomorrowQuests = dailyQuestsFor(nextDay);
      for (final quest in tomorrowQuests) {
        final oldLevel = levels.firstWhere((level) => level.kind == quest.kind);
        await controller.completeLevel(oldLevel);
      }
      now = nextDay;
      LevelDefinition? selected;
      await showProgress(
        tester,
        controller,
        onPlay: (level) => selected = level,
      );

      expect(controller.dailyQuests.length, 3);
      expect(
        controller.dailyQuests.map((quest) => quest.kind).toSet().length,
        3,
      );
      for (final quest in controller.dailyQuests) {
        final action = find.byKey(ValueKey('daily-quest-play-${quest.id}'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        expect(selected, isNotNull);
        expect(selected!.kind, quest.kind);
        expect(controller.isUnlocked(selected!), isTrue);
        expect(controller.progress.containsKey(selected!.id), isFalse);
      }
    },
  );

  testWidgets(
    'a new day can offer a replay after all twenty stickers are earned',
    (tester) async {
      var now = DateTime(2026, 11, 16);
      final controller = GameController.forTest(now: () => now);
      addTearDown(controller.dispose);
      for (final level in levels) {
        await controller.completeLevel(level);
      }
      now = DateTime(2026, 11, 17);
      LevelDefinition? selected;
      await showProgress(
        tester,
        controller,
        onPlay: (level) => selected = level,
      );
      final quest = controller.dailyQuests.first;
      final action = find.byKey(ValueKey('daily-quest-play-${quest.id}'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      expect(selected!.kind, quest.kind);
      expect(controller.isUnlocked(selected!), isTrue);
      expect(controller.dailyQuestProgress(quest), 0);
      await controller.completeLevel(selected!);
      await tester.pumpAndSettle();
      expect(controller.dailyQuestProgress(quest), 1);
      expect(
        find.byKey(ValueKey('daily-quest-play-${quest.id}')),
        findsNothing,
      );
      expect(controller.earnedStickers.length, 20);
    },
  );

  testWidgets(
    'returning to a mounted tab refreshes the local day without awarding anything',
    (tester) async {
      var now = DateTime(2026, 11, 17, 23, 50);
      final controller = GameController.forTest(now: () => now);
      addTearDown(controller.dispose);
      await showProgress(tester, controller);
      final yesterdayQuest = controller.dailyQuests.first;
      expect(
        find.byKey(ValueKey('daily-quest-${yesterdayQuest.id}')),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 11, 18, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('daily-quest-${yesterdayQuest.id}')),
        findsNothing,
      );
      for (final quest in controller.dailyQuests) {
        expect(find.byKey(ValueKey('daily-quest-${quest.id}')), findsOneWidget);
      }
      final today = tester.widget<Semantics>(
        find.byKey(const ValueKey('playday-2026-11-18')),
      );
      expect(today.properties.label, contains('Сегодня'));
      expect(controller.earnedStickers, isEmpty);
      expect(
        find.byKey(const ValueKey('milestone-celebration-first_step')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ten mastery badges update only after both authored levels are finished',
    (tester) async {
      final controller = GameController.forTest(
        now: () => DateTime(2026, 11, 17),
      );
      addTearDown(controller.dispose);
      await showProgress(tester, controller);
      await openBadges(tester);
      final mastery = achievements
          .where((achievement) => achievement.kind != null)
          .toList();
      expect(mastery.length, 10);
      for (final achievement in mastery) {
        expect(
          find.byKey(ValueKey('achievement-${achievement.id}')),
          findsOneWidget,
        );
      }
      final achievement = mastery.first;
      final status = find.byKey(
        ValueKey('achievement-status-${achievement.id}'),
      );
      expect(tester.widget<Text>(status).data, '0 / 2');
      final related = levels
          .where((level) => level.kind == achievement.kind)
          .toList();
      await controller.completeLevel(related.first);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, '1 / 2');
      await controller.completeLevel(related.last);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(status).data, 'Получен');
    },
  );

  testWidgets('the calendar shows seven real dates and a gentle empty today', (
    tester,
  ) async {
    final controller = GameController.forTest(
      now: () => DateTime(2026, 11, 18),
    );
    addTearDown(controller.dispose);
    await showProgress(tester, controller);
    expect(controller.currentWeek.length, 7);
    expect(controller.currentWeek.first.date, DateTime(2026, 11, 16));
    for (final day in controller.currentWeek) {
      expect(
        find.byKey(ValueKey('playday-${calendarDayKey(day.date)}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('calendar-today')), findsOneWidget);
    expect(
      find.text('Начни с любого задания, когда захочется.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('total-play-days')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    final today = tester.widget<Semantics>(
      find.byKey(const ValueKey('playday-2026-11-18')),
    );
    expect(today.properties.label, contains('Сегодня'));
    expect(today.properties.label, contains('Свободный день'));
  });

  testWidgets(
    'calendar marks visits as unique play days without resetting total history',
    (tester) async {
      var now = DateTime(2026, 11, 16);
      final controller = GameController.forTest(now: () => now);
      addTearDown(controller.dispose);
      await controller.completeLevel(levels.first);
      await controller.completeLevel(levels[1]);
      now = DateTime(2026, 11, 18);
      await controller.completeLevel(levels[2]);
      await showProgress(tester, controller);
      expect(controller.playedDates.length, 2);
      expect(find.text('Дней с открытиями на этой неделе: 2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('play-week')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TrailIcon && widget.kind == TrailIconKind.check,
          ),
        ),
        findsNWidgets(2),
      );
      now = DateTime(2026, 11, 25);
      await showProgress(tester, controller);
      expect(
        find.text('Начни с любого задания, когда захочется.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('total-play-days')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'milestone celebration waits for durable completion and does not repeat on replay',
    (tester) async {
      final store = _GatedStore();
      final controller = GameController.forTest(
        store: store,
        now: () => DateTime(2026, 11, 17),
      );
      addTearDown(controller.dispose);
      await showProgress(tester, controller);
      final completion = controller.completeLevel(levels.first);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('milestone-celebration-first_step')),
        findsNothing,
      );
      store.release();
      await completion;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('milestone-celebration-first_step')),
        findsOneWidget,
      );
      final dismiss = find.byTooltip('Закрыть');
      await tester.ensureVisible(dismiss);
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      await controller.completeLevel(levels.first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('milestone-celebration-first_step')),
        findsNothing,
      );
    },
  );

  testWidgets('a failed completion never celebrates a sticker or milestone', (
    tester,
  ) async {
    final store = _GatedStore(failWrites: true);
    final controller = GameController.forTest(
      store: store,
      now: () => DateTime(2026, 11, 17),
    );
    addTearDown(controller.dispose);
    await showProgress(tester, controller);
    final completion = controller.completeLevel(levels.first);
    final rejected = expectLater(
      completion,
      throwsA(isA<CompletionPersistenceException>()),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('milestone-celebration-first_step')),
      findsNothing,
    );
    store.release();
    await rejected;
    await tester.pumpAndSettle();
    expect(controller.earnedStickers, isEmpty);
    expect(
      find.byKey(const ValueKey('milestone-celebration-first_step')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Nunito localized collection fits small phone, landscape and tablet at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = GameController.forTest(
        now: () => DateTime(2026, 11, 17),
      );
      addTearDown(controller.dispose);
      for (final language in ['ru', 'kk', 'en']) {
        await controller.setLanguage(language);
        for (final size in [
          const Size(320, 568),
          const Size(568, 320),
          const Size(1024, 768),
        ]) {
          tester.view.physicalSize = size;
          await showProgress(tester, controller, textScale: 1.3);
          expect(
            tester.takeException(),
            isNull,
            reason: '$language $size header and quests',
          );
          final lastSticker = find.byKey(
            ValueKey('sticker-${stickers.last.id}'),
          );
          await tester.ensureVisible(lastSticker);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$language $size sticker album',
          );
          await openBadges(tester);
          final lastBadge = achievements.lastWhere(
            (achievement) => achievement.kind != null,
          );
          await tester.ensureVisible(
            find.byKey(ValueKey('achievement-${lastBadge.id}')),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$language $size mastery collection',
          );
        }
      }
    },
  );

  testWidgets('capture real-font quests and the twenty-sticker bitmap album', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameController.forTest(
      now: () => DateTime(2026, 11, 17),
    );
    addTearDown(controller.dispose);
    for (final level in levels.take(5)) {
      await controller.completeLevel(level);
    }
    await showProgress(tester, controller);
    final images = [
      for (final sticker in stickers)
        ResizeImage(AssetImage(sticker.illustrationAsset!), width: 480),
    ];
    await captureWidgetFixture(
      tester,
      'output/qa/v2-widget-progress-phone.png',
      images: images,
    );
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('collection-tab-stickers'))),
      alignment: 0,
    );
    await captureWidgetFixture(
      tester,
      'output/qa/v2-widget-stickers-tablet.png',
      images: images,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('count labels inflect real collection totals in all locales', (
    tester,
  ) async {
    const expectedDays = {
      1: 'день вместе',
      2: 'дня вместе',
      5: 'дней вместе',
      11: 'дней вместе',
      21: 'день вместе',
      22: 'дня вместе',
    };
    for (final count in expectedDays.keys) {
      var now = DateTime(2026, 11, 1);
      final controller = GameController.forTest(now: () => now);
      for (var day = 0; day < count; day++) {
        now = DateTime(2026, 11, day + 1);
        await controller.completeLevel(levels[day % levels.length]);
      }
      await showProgress(tester, controller);
      expect(controller.playedDates.length, count);
      expect(find.text(expectedDays[count]!), findsOneWidget);
      expect(
        find.text(
          count == 1
              ? 'наклейка'
              : count == 2
              ? 'наклейки'
              : 'наклеек',
        ),
        findsOneWidget,
      );
      expect(find.text(count == 11 ? 'значок' : 'значков'), findsOneWidget);
      if (count == 1 || count == 11) {
        await controller.setLanguage('en');
        await tester.pumpAndSettle();
        expect(find.text(count == 1 ? 'sticker' : 'stickers'), findsOneWidget);
        expect(find.text(count == 11 ? 'badge' : 'badges'), findsOneWidget);
        expect(
          find.text(count == 1 ? 'day together' : 'days together'),
          findsOneWidget,
        );
      }
      if (count == 2) {
        await controller.setLanguage('kk');
        await tester.pumpAndSettle();
        expect(find.text('жапсырма'), findsOneWidget);
        expect(find.text('белгі'), findsOneWidget);
        expect(find.text('күн бірге'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });
}

class _GatedStore extends MemoryProgressStore {
  _GatedStore({this.failWrites = false});
  final bool failWrites;
  final Completer<void> _gate = Completer<void>();
  void release() => _gate.complete();
  @override
  Future<void> write(String key, String value) async {
    await _gate.future;
    if (failWrites) throw StateError('Synthetic storage failure');
    await super.write(key, value);
  }
}
