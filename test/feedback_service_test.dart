import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_trails/core/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speech = MethodChannel('tiny_trails/speech');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(speech, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(speech, null);
  });
  test('availability queries the selected installed voice', () async {
    final feedback = FeedbackService();
    expect(await feedback.isSpeechAvailable('kk'), isTrue);
    expect(calls.single.method, 'isAvailable');
    expect(calls.single.arguments, {'language': 'kk'});
    messenger.setMockMethodCallHandler(speech, (call) async => false);
    expect(await feedback.isSpeechAvailable('ru'), isFalse);
    feedback.dispose();
  });
  test(
    'unavailable or invalid speech stays a safe capability result',
    () async {
      final feedback = FeedbackService();
      expect(await feedback.isSpeechAvailable('fr'), isFalse);
      expect(calls, isEmpty);
      messenger.setMockMethodCallHandler(speech, (call) async {
        throw PlatformException(code: 'engine_unavailable');
      });
      expect(await feedback.isSpeechAvailable('ru'), isFalse);
      messenger.setMockMethodCallHandler(speech, null);
      expect(await feedback.isSpeechAvailable('en'), isFalse);
      feedback.dispose();
      expect(await feedback.isSpeechAvailable('en'), isFalse);
    },
  );
  test('speech text respects both native platform length limits', () async {
    final feedback = FeedbackService();
    await feedback.speak('a' * 1400, 'en', enabled: true);
    expect((calls.last.arguments as Map)['text'].length, 1000);
    feedback.dispose();
  });
  test(
    'voice hints replace previous speech and disabled voice stops it',
    () async {
      final feedback = FeedbackService();
      await feedback.speak('  Нарисуй круг  ', 'kk', enabled: true);
      expect(calls.map((e) => e.method), ['stop', 'speak']);
      expect(calls.last.arguments, {'text': 'Нарисуй круг', 'language': 'kk'});
      await feedback.speak('Should stay silent', 'en', enabled: false);
      expect(calls.last.method, 'stop');
      expect(calls.where((e) => e.method == 'speak').length, 1);
      feedback.dispose();
    },
  );
  test(
    'a later request cancels a stale hint waiting for native stop',
    () async {
      final stop = Completer<void>();
      var stopCount = 0;
      messenger.setMockMethodCallHandler(speech, (call) async {
        calls.add(call);
        if (call.method == 'stop' && ++stopCount == 1) await stop.future;
        return true;
      });
      final feedback = FeedbackService();
      final old = feedback.speak('old', 'ru', enabled: true);
      await Future<void>.delayed(Duration.zero);
      await feedback.speak('new', 'en', enabled: true);
      stop.complete();
      await old;
      final spoken = calls.where((e) => e.method == 'speak').toList();
      expect(spoken.length, 1);
      expect((spoken.single.arguments as Map)['text'], 'new');
      feedback.dispose();
    },
  );
  test(
    'missing speech plugin and disabled sound/haptics do not break game',
    () async {
      messenger.setMockMethodCallHandler(speech, null);
      final feedback = FeedbackService();
      await feedback.speak('hint', 'ru', enabled: true);
      await feedback.tap(sound: false, haptics: false);
      await feedback.success(sound: false, haptics: false);
      feedback.dispose();
      feedback.dispose();
      await feedback.speak('disposed', 'ru', enabled: true);
    },
  );
  test(
    'bundled narration availability requires generated, existing bytes',
    () async {
      final assets = _FakeAssets.narration();
      final feedback = FeedbackService(assetBundle: assets);
      expect(
        await feedback.isSpeechAvailable('kk', narrationKey: 'v2_01'),
        isTrue,
      );
      expect(
        await feedback.isSpeechAvailable('kk', narrationKey: 'v2_01'),
        isTrue,
      );
      expect(calls, isEmpty);
      expect(assets.loads['assets/audio/narration/manifest.json'], 1);
      expect(assets.loads['assets/audio/narration/v2_01_kk.mp3'], 1);
      feedback.dispose();
    },
  );
  for (final condition in ['not_generated', 'missing', 'empty', 'malformed']) {
    test(
      '$condition narration falls back to the real native capability',
      () async {
        final assets = _FakeAssets.narration(condition: condition);
        messenger.setMockMethodCallHandler(speech, (call) async {
          calls.add(call);
          return false;
        });
        final feedback = FeedbackService(assetBundle: assets);
        expect(
          await feedback.isSpeechAvailable('kk', narrationKey: 'v2_01'),
          isFalse,
        );
        expect(calls.single.method, 'isAvailable');
        if (condition == 'not_generated') {
          expect(assets.loads['assets/audio/narration/v2_01_kk.mp3'], isNull);
        }
        feedback.dispose();
      },
    );
  }
  test('a real bundled locale plays instead of native TTS', () async {
    final players = <_FakePlayer>[];
    final feedback = FeedbackService(
      assetBundle: _FakeAssets.narration(),
      playerFactory: () {
        final player = _FakePlayer();
        players.add(player);
        return player;
      },
    );
    await feedback.speak('Hint', 'kk', enabled: true, narrationKey: 'v2_01');
    expect(players, hasLength(1));
    expect(players.single.bytes, isNotNull);
    expect(players.single.resumeCount, 1);
    expect(calls.map((call) => call.method), ['stop']);
    await feedback.speak('', 'kk', enabled: false, narrationKey: 'v2_01');
    expect(players.single.stopCount, 1);
    expect(players.single.resumeCount, 1);
    feedback.dispose();
  });
  for (final format in const {
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
  }.entries) {
    test(
      '${format.key} bundle retains its format through availability cache and playback',
      () async {
        final player = _FakePlayer()..expectedMimeType = format.value;
        final assets = _FakeAssets.narration(extension: format.key);
        final feedback = FeedbackService(
          assetBundle: assets,
          playerFactory: () => player,
        );
        expect(
          await feedback.isSpeechAvailable('kk', narrationKey: 'v2_01'),
          isTrue,
        );
        await feedback.speak(
          'A typed bundled hint',
          'kk',
          enabled: true,
          narrationKey: 'v2_01',
        );
        await feedback.speak(
          'The cached bundled hint',
          'kk',
          enabled: true,
          narrationKey: 'v2_01',
        );
        expect(player.mimeType, format.value);
        expect(player.resumeCount, 2);
        expect(
          assets.loads['assets/audio/narration/v2_01_kk.${format.key}'],
          1,
        );
        expect(calls.where((call) => call.method == 'speak'), isEmpty);
        feedback.dispose();
      },
    );
  }
  test(
    'a bundled decoder failure falls back to the written native text',
    () async {
      final feedback = FeedbackService(
        assetBundle: _FakeAssets.narration(),
        playerFactory: () => _FakePlayer()..failBytes = true,
      );
      await feedback.speak(
        'Use the outline',
        'kk',
        enabled: true,
        narrationKey: 'v2_01',
      );
      expect(calls.last.method, 'speak');
      expect((calls.last.arguments as Map)['text'], 'Use the outline');
      feedback.dispose();
    },
  );
  test(
    'music loops and retains its position through preferences and lifecycle',
    () async {
      final players = <_FakePlayer>[];
      final feedback = FeedbackService(
        playerFactory: () {
          final player = _FakePlayer();
          players.add(player);
          return player;
        },
      );
      await feedback.setMusicEnabled(false);
      expect(players, isEmpty);
      await feedback.setMusicEnabled(true);
      final music = players.single;
      expect(music.looping, isTrue);
      expect(music.assets, ['audio/menu_loop.wav']);
      expect(music.resumeCount, 1);
      await feedback.setMusicEnabled(true);
      expect(music.resumeCount, 1);
      await feedback.setPaused(true);
      expect(music.pauseCount, 1);
      await feedback.setPaused(false);
      expect(music.resumeCount, 2);
      expect(music.assets, hasLength(1));
      await feedback.setPaused(true);
      await feedback.setMusicEnabled(false);
      await feedback.setPaused(false);
      expect(music.resumeCount, 2);
      feedback.dispose();
    },
  );
  test(
    'enabling music while paused does not create or start a player',
    () async {
      final players = <_FakePlayer>[];
      final feedback = FeedbackService(
        playerFactory: () {
          final player = _FakePlayer();
          players.add(player);
          return player;
        },
      );
      await feedback.setPaused(true);
      await feedback.setMusicEnabled(true);
      expect(players, isEmpty);
      await feedback.setPaused(false);
      expect(players.single.resumeCount, 1);
      feedback.dispose();
    },
  );
  test(
    'bundled speech ducks music until the actual completion event',
    () async {
      final players = <_FakePlayer>[];
      final feedback = FeedbackService(
        assetBundle: _FakeAssets.narration(),
        playerFactory: () {
          final player = _FakePlayer();
          players.add(player);
          return player;
        },
      );
      await feedback.setMusicEnabled(true);
      final music = players.single;
      expect(music.volume, .10);
      await feedback.speak('Hint', 'kk', enabled: true, narrationKey: 'v2_01');
      expect(music.volume, .025);
      players.last.complete();
      await Future<void>.delayed(Duration.zero);
      expect(music.volume, .10);
      feedback.dispose();
    },
  );
  test('disabling music during source setup prevents a late start', () async {
    final gate = Completer<void>();
    final player = _FakePlayer()..assetGate = gate;
    final feedback = FeedbackService(playerFactory: () => player);
    final enabling = feedback.setMusicEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(player.assets, hasLength(1));
    final disabling = feedback.setMusicEnabled(false);
    gate.complete();
    await Future.wait([enabling, disabling]);
    expect(player.resumeCount, 0);
    feedback.dispose();
  });
  test(
    'dispose cancels effects still loading and releases once without playback',
    () async {
      final gate = Completer<void>();
      final player = _FakePlayer()..assetGate = gate;
      final feedback = FeedbackService(playerFactory: () => player);
      final playing = feedback.tap(sound: true, haptics: false);
      await Future<void>.delayed(Duration.zero);
      expect(player.assets, hasLength(1));
      feedback.dispose();
      feedback.dispose();
      gate.complete();
      await playing;
      await Future<void>.delayed(Duration.zero);
      expect(player.resumeCount, 0);
      expect(player.disposeCount, 1);
      await feedback.setMusicEnabled(true);
      await feedback.setPaused(false);
      await feedback.success(sound: true, haptics: true);
      expect(player.resumeCount, 0);
    },
  );
}

class _FakeAssets extends CachingAssetBundle {
  _FakeAssets(this.files);
  factory _FakeAssets.narration({String? condition, String extension = 'mp3'}) {
    final manifest = {
      'version': 1,
      'entries': [
        {
          'key': 'v2_01',
          'language': 'kk',
          'asset': 'audio/narration/v2_01_kk.$extension',
          'generated': condition != 'not_generated',
        },
      ],
    };
    return _FakeAssets({
      'assets/audio/narration/manifest.json': Uint8List.fromList(
        utf8.encode(
          condition == 'malformed' ? '{broken' : jsonEncode(manifest),
        ),
      ),
      if (condition != 'missing')
        'assets/audio/narration/v2_01_kk.$extension': Uint8List.fromList(
          condition == 'empty'
              ? []
              : switch (extension) {
                  'wav' => [82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69],
                  'm4a' => [0, 0, 0, 24, 102, 116, 121, 112, 77, 52, 65, 32],
                  _ => [73, 68, 51, 4, 0, 0, 0, 0, 0, 0],
                },
        ),
    });
  }
  final Map<String, Uint8List> files;
  final loads = <String, int>{};
  @override
  Future<ByteData> load(String key) async {
    loads[key] = (loads[key] ?? 0) + 1;
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Missing synthetic test asset');
    return ByteData.sublistView(bytes);
  }
}

class _FakePlayer implements FeedbackPlayer {
  final _completion = StreamController<void>.broadcast(sync: true);
  final assets = <String>[];
  Uint8List? bytes;
  String? mimeType;
  String? expectedMimeType;
  bool looping = false;
  bool failBytes = false;
  double volume = 1;
  int resumeCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  Completer<void>? assetGate;
  @override
  Stream<void> get onComplete => _completion.stream;
  void complete() => _completion.add(null);
  @override
  Future<void> setAsset(String asset) async {
    assets.add(asset);
    await assetGate?.future;
  }

  @override
  Future<void> setBytes(Uint8List value, {required String mimeType}) async {
    if (failBytes ||
        (expectedMimeType != null && expectedMimeType != mimeType)) {
      throw PlatformException(code: 'synthetic_decode_failure');
    }
    bytes = value;
    this.mimeType = mimeType;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> setLooping(bool value) async {
    looping = value;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _completion.close();
  }
}
