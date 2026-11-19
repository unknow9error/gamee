import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/application/game_controller.dart';
import 'package:tiny_trails/core/theme.dart';
import 'package:tiny_trails/data/catalog.dart';
import 'package:tiny_trails/data/legacy_catalog.dart';
import 'package:tiny_trails/data/progress_store.dart';
import 'package:tiny_trails/domain/models.dart';
import 'package:tiny_trails/features/home/app_shell.dart';
import 'package:tiny_trails/features/home/artwork_preview.dart';
import 'package:tiny_trails/features/home/home_screen.dart';
import 'package:tiny_trails/features/home/studio_screen.dart';
import 'package:tiny_trails/features/home/world_screen.dart';
import 'package:tiny_trails/features/play/drawing_activity.dart';
import 'package:tiny_trails/features/play/play_screen.dart';
import 'package:tiny_trails/features/settings/settings_screen.dart';
import 'package:tiny_trails/shared/art/scene_illustration.dart';
import 'package:tiny_trails/shared/widgets/lesson_illustration.dart';

const _captureHome = bool.fromEnvironment('CAPTURE_HOME');
const _captureKey = ValueKey('home-test-capture');

class _FailingStore extends MemoryProgressStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Synthetic write failure');
    await super.write(key, value);
  }
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GameController> _controller({ProgressStore? store}) async {
  final controller = GameController.forTest(
    store: store,
    now: () => DateTime(2026, 11, 17, 12),
  );
  await controller.setReducedMotion(true);
  await controller.setSound(false);
  await controller.setVoice(false);
  await controller.setHaptics(false);
  return controller;
}

Widget _host(Widget child, {double textScale = 1}) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

Future<void> _settle(
  WidgetTester tester, {
  bool waitForAnimations = true,
}) async {
  for (var pass = 0; pass < 2; pass++) {
    await tester.pump();
    final images = find.byType(Image, skipOffstage: false).evaluate().toList();
    await tester.runAsync(() async {
      await Future.wait([
        for (final element in images)
          precacheImage((element.widget as Image).image, element),
      ]);
    });
  }
  if (waitForAnimations) {
    await tester.pumpAndSettle();
  } else {
    // The destination may own ongoing game guidance; finish the route transition.
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureHome) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await _settle(tester);
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('output/qa/home-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _close(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
  await controller.flush();
  controller.dispose();
}

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
  setUp(() => rootBundle.evict('assets/audio/narration/manifest.json'));
  for (final language in ['ru', 'kk', 'en']) {
    testWidgets(
      'curated home fits a small phone in $language and opens age settings',
      (tester) async {
        _viewport(tester, const Size(320, 568));
        final c = await _controller();
        await c.setLanguage(language);
        await c.setChildAge(4);
        LevelDefinition? played;
        await tester.pumpWidget(
          _host(
            HomeScreen(controller: c, onPlay: (level) => played = level),
            textScale: 1.2,
          ),
        );
        await _settle(tester);
        expect(find.byKey(const Key('home-catalog-count')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('home-catalog-count'))).data,
          contains('20'),
        );
        for (final world in worlds) {
          expect(
            find.byKey(ValueKey('world-card-${world.id}')),
            findsOneWidget,
          );
        }
        expect(find.byType(LessonIllustration), findsNWidgets(6));
        expect(find.byType(SceneIllustration), findsNothing);
        expect(find.byKey(const Key('home-age-settings')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('home-age-settings')),
            matching: find.text(switch (language) {
              'kk' => '4 жас',
              'en' => 'Age 4',
              _ => '4 года',
            }),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('home-age-settings')));
        await _settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
        await _settle(tester);
        await tester.ensureVisible(find.byKey(const Key('continue-adventure')));
        await tester.tap(find.byKey(const Key('continue-adventure')));
        expect(played?.id, 'v2_01');
        expect(tester.takeException(), isNull);
        await _close(tester, c);
      },
    );
  }

  testWidgets('home refreshes daily ideas when returning on another day', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    var now = DateTime(2026, 11, 17, 23, 59);
    final c = GameController.forTest(now: () => now);
    await c.setReducedMotion(true);
    await tester.pumpWidget(_host(HomeScreen(controller: c, onPlay: (_) {})));
    await _settle(tester);
    final oldId = c.dailyQuests.first.id;
    expect(find.byKey(ValueKey('daily-quest-$oldId')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 18, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.byKey(ValueKey('daily-quest-$oldId')), findsNothing);
    expect(
      find.byKey(ValueKey('daily-quest-${c.dailyQuests.first.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _close(tester, c);
  });

  testWidgets(
    'every chapter has four available lessons with global numbering and a working last route',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final c = await _controller();
      for (final kind in activeActivityKinds) {
        await c.markTutorialSeen(kind);
      }
      for (final world in worlds) {
        final chapter = levels
            .where((level) => level.worldId == world.id)
            .toList();
        await tester.pumpWidget(
          _host(WorldScreen(world: world, controller: c)),
        );
        await _settle(tester);
        for (final level in chapter) {
          expect(
            find.byKey(ValueKey('level-card-${level.id}')),
            findsOneWidget,
          );
          expect(
            find.text('${levels.indexOf(level) + 1} / 20'),
            findsOneWidget,
          );
        }
        expect(find.byType(LessonIllustration), findsNWidgets(4));
        expect(find.byType(SceneIllustration), findsNothing);
        await tester.ensureVisible(
          find.byKey(ValueKey('level-card-${chapter.last.id}')),
        );
        await tester.tap(find.byKey(ValueKey('level-card-${chapter.last.id}')));
        await _settle(tester, waitForAnimations: false);
        expect(
          tester.widget<PlayScreen>(find.byType(PlayScreen)).level.id,
          chapter.last.id,
        );
        expect(tester.takeException(), isNull);
        // A new host detaches the route before opening the next chapter.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      }
      await _close(tester, c);
    },
  );

  testWidgets(
    'studio offers four original IDs and only completed lessons enter creative replay',
    (tester) async {
      _viewport(tester, const Size(320, 568));
      final c = await _controller();
      LevelDefinition? played;
      await tester.pumpWidget(
        _host(
          StudioScreen(controller: c, onPlay: (level) => played = level),
          textScale: 1.2,
        ),
      );
      await _settle(tester);
      final creative = levels
          .where(
            (level) =>
                level.kind == ActivityKind.numberColor ||
                level.kind == ActivityKind.guidedDraw,
          )
          .toList();
      expect(creative, hasLength(4));
      for (final level in creative) {
        expect(
          find.byKey(ValueKey('studio-create-${level.id}')),
          findsOneWidget,
        );
      }
      final target = creative.first;
      await tester.ensureVisible(
        find.byKey(ValueKey('studio-create-${target.id}')),
      );
      await tester.tap(find.byKey(ValueKey('studio-create-${target.id}')));
      expect(played?.id, target.id);
      expect(played?.activityData['creativeReplay'], isNot(true));
      await c.completeLevel(target);
      await _settle(tester);
      await tester.tap(find.byKey(ValueKey('studio-create-${target.id}')));
      expect(played?.id, target.id);
      expect(played?.kind, target.kind);
      expect(played?.illustrationAsset, target.illustrationAsset);
      expect(played?.activityData['creativeReplay'], isTrue);
      expect(
        played?.activityData['colorSpecAsset'],
        target.activityData['colorSpecAsset'],
      );
      expect(c.completedCount, 1);
      expect(tester.takeException(), isNull);
      await _close(tester, c);
    },
  );

  testWidgets(
    'album keeps multiple versions and failed deletion stays visible until a successful retry',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final store = _FailingStore();
      final c = await _controller(store: store);
      final level = levels.firstWhere(
        (level) => level.kind == ActivityKind.guidedDraw,
      );
      for (var version = 0; version < 2; version++) {
        await c.completeLevel(
          level,
          artwork: {
            'type': 'guidedDraw',
            'childAge': 6,
            'strokes': <dynamic>[],
            'version': version,
          },
        );
      }
      final ids = c.artworks.map((art) => art.id).toList();
      await tester.pumpWidget(
        _host(StudioScreen(controller: c, onPlay: (_) {})),
      );
      await _settle(tester);
      for (final id in ids) {
        expect(find.byKey(ValueKey('artwork-$id')), findsOneWidget);
      }
      expect(find.byType(DrawingArtworkPreview), findsNWidgets(2));
      await tester.tap(find.byKey(ValueKey('artwork-${ids.first}')));
      await _settle(tester);
      store.fail = true;
      await tester.tap(find.byKey(const Key('delete-artwork')));
      await _settle(tester);
      expect(c.artworks, hasLength(2));
      await tester.tap(find.text('Удалить').last);
      await _settle(tester);
      expect(find.byKey(const Key('artwork-delete-error')), findsOneWidget);
      expect(c.artworks.map((art) => art.id), ids);
      store.fail = false;
      await tester.tap(find.byKey(const Key('delete-artwork')));
      await _settle(tester);
      await tester.tap(find.text('Удалить').last);
      await _settle(tester);
      expect(c.artworks.single.id, ids.last);
      expect(find.byKey(ValueKey('artwork-${ids.last}')), findsOneWidget);
      expect(find.byKey(ValueKey('artwork-${ids.first}')), findsNothing);
      expect(c.completedCount, 1);
      expect(tester.takeException(), isNull);
      await _close(tester, c);
    },
  );

  testWidgets(
    'earlier artworks and drafts remain visible and read only with their frozen titles',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      const artworkId = 'ocean_numberColor_1';
      const draftId = 'space_guidedDraw_4';
      final source = jsonEncode({
        'version': 1,
        'settings': {
          'language': 'ru',
          'reducedMotion': true,
          'onboardingComplete': true,
        },
        'progress': {
          artworkId: {
            'stars': 3,
            'completedAt': '2026-11-16T12:00:00.000',
            'attempts': 1,
          },
        },
        'drafts': {
          draftId: {
            'strokes': [
              {
                'color': 'damaged field',
                'width': false,
                'points': [
                  [.1, .2],
                  [.3, .4],
                ],
              },
            ],
          },
        },
        'artworks': [
          {
            'levelId': artworkId,
            'createdAt': '2026-11-16T12:00:00.000',
            'data': {'fills': <String, int>{}},
          },
        ],
      });
      final store = MemoryProgressStore({
        GameController.legacyStorageKey: source,
      });
      final c = await GameController.load(store: store);
      LevelDefinition? played;
      await tester.pumpWidget(
        _host(StudioScreen(controller: c, onPlay: (level) => played = level)),
      );
      await _settle(tester);
      expect(c.completedCount, 0);
      expect(c.totalStars, 0);
      expect(find.text(legacyLevelIndex[artworkId]!.title.ru), findsOneWidget);
      expect(find.text(legacyLevelIndex[draftId]!.title.ru), findsOneWidget);
      final archived = find.byKey(
        ValueKey('artwork-archive-0-${c.legacyArtworks.single.id}'),
      );
      await tester.ensureVisible(archived);
      await tester.tap(archived);
      await _settle(tester);
      expect(find.text('Архив · только для просмотра'), findsOneWidget);
      expect(find.byKey(const Key('delete-artwork')), findsNothing);
      expect(find.text('Нарисовать ещё'), findsNothing);
      expect(played, isNull);
      expect(store.values[GameController.legacyStorageKey], source);
      expect(tester.takeException(), isNull);
      await _close(tester, c);
    },
  );

  testWidgets(
    'legacy maze drafts show a saved-route summary without fictional art',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      const draftId = 'ocean_maze_1';
      final data = {
        'route': [0, 1, 2],
        'oldCheckpoint': 'kept',
      };
      final source = jsonEncode({
        'version': 1,
        'settings': {
          'language': 'ru',
          'reducedMotion': true,
          'onboardingComplete': true,
        },
        'progress': <String, dynamic>{},
        'drafts': {draftId: data},
        'artworks': <dynamic>[],
      });
      final store = MemoryProgressStore({
        GameController.legacyStorageKey: source,
      });
      final c = await GameController.load(store: store);
      LevelDefinition? played;
      await tester.pumpWidget(
        _host(StudioScreen(controller: c, onPlay: (level) => played = level)),
      );
      await _settle(tester);
      final draft = find.byKey(
        const ValueKey('artwork-archive-draft-ocean_maze_1'),
      );
      expect(find.byKey(const Key('legacy-maze-summary')), findsOneWidget);
      expect(find.byType(ArtworkPreview), findsNothing);
      expect(find.text('Точек маршрута: 3'), findsOneWidget);
      expect(find.text(legacyLevelIndex[draftId]!.title.ru), findsOneWidget);
      await tester.ensureVisible(draft);
      await tester.tap(draft);
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byKey(const Key('legacy-maze-summary')),
        ),
        findsOneWidget,
      );
      expect(find.byType(ArtworkPreview), findsNothing);
      expect(find.text('Архив · только для просмотра'), findsOneWidget);
      expect(find.byKey(const Key('delete-artwork')), findsNothing);
      expect(find.text('Нарисовать ещё'), findsNothing);
      expect(played, isNull);
      expect(c.legacyDrafts[draftId], data);
      expect(c.completedCount, 0);
      expect(store.values[GameController.legacyStorageKey], source);
      expect(tester.takeException(), isNull);
      await _close(tester, c);
    },
  );

  testWidgets(
    'shell saving failure has a working retry and album destination',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final store = _FailingStore();
      final c = await _controller(store: store);
      store.fail = true;
      await c.setChildAge(5);
      await tester.pumpWidget(_host(AppShell(controller: c)));
      await _settle(tester);
      expect(find.byKey(const Key('persistence-banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry-persistence')));
      await _settle(tester);
      expect(find.byKey(const Key('persistence-banner')), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.fail = false;
      await tester.tap(find.byKey(const Key('retry-persistence')));
      await _settle(tester);
      expect(find.byKey(const Key('persistence-banner')), findsNothing);
      await tester.tap(find.text('Мастерская').last);
      await _settle(tester);
      expect(find.text('Твоя мастерская'), findsOneWidget);
      await _close(tester, c);
    },
  );

  testWidgets(
    'new drawing preview uses its authored master and saved ink renderer',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final level = levels.firstWhere(
        (level) => level.kind == ActivityKind.guidedDraw,
      );
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox.square(
              dimension: 300,
              child: ArtworkPreview(
                level: level,
                data: {
                  'childAge': 9,
                  'strokes': [
                    {
                      'points': [
                        [.2, .2],
                        [.4, .4],
                      ],
                      'color': 0xFF467A5B,
                      'width': 3.5,
                    },
                  ],
                  'stamps': [
                    {
                      'point': [.5, .5],
                      'color': 0xFFF7CF63,
                      'shape': 0,
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(DrawingArtworkPreview), findsOneWidget);
      expect(find.byType(SceneIllustration), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      final asset = provider is ResizeImage
          ? provider.imageProvider as AssetImage
          : provider as AssetImage;
      expect(asset.assetName, level.illustrationAsset);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('optional capture of the curated home, world and studio', (
    tester,
  ) async {
    if (!_captureHome) return;
    _viewport(tester, const Size(390, 844));
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(900, 1000),
    ]) {
      final c = await _controller();
      tester.view.physicalSize = size;
      await tester.pumpWidget(_host(AppShell(controller: c)));
      await _settle(tester);
      await _capture(tester, '${size.width.round()}-adventures');
      await c.completeLevel(
        levels.firstWhere((level) => level.kind == ActivityKind.guidedDraw),
        artwork: {
          'type': 'guidedDraw',
          'childAge': 6,
          'strokes': [
            {
              'points': [
                [.2, .3],
                [.4, .3],
                [.4, .6],
              ],
              'color': 0xFF467A5B,
              'width': 3.5,
            },
          ],
          'stamps': [
            {
              'point': [.7, .7],
              'color': 0xFFF7CF63,
              'shape': 0,
            },
          ],
        },
      );
      await _settle(tester);
      await tester.tap(find.text('Мастерская').last);
      await _settle(tester);
      await _capture(tester, '${size.width.round()}-studio');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(WorldScreen(world: worlds.first, controller: c)),
      );
      await _settle(tester);
      await _capture(tester, '${size.width.round()}-chapter');
      expect(tester.takeException(), isNull);
      await _close(tester, c);
    }
  });
}
