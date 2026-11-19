import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The small playback boundary keeps feedback independent from device plugins.
/// Sources are always bundled assets or their bytes, never remote URLs.
abstract interface class FeedbackPlayer {
  Stream<void> get onComplete;
  Future<void> setAsset(String asset);
  Future<void> setBytes(Uint8List bytes, {required String mimeType});
  Future<void> setVolume(double volume);
  Future<void> setLooping(bool looping);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// Optional local audio and haptics. Missing devices, assets, and installed
/// voices must never interrupt an activity or its progress transaction.
class FeedbackService {
  FeedbackService({
    AssetBundle? assetBundle,
    FeedbackPlayer Function()? playerFactory,
  }) : _assets = assetBundle ?? rootBundle {
    final factory = playerFactory ?? _DeviceFeedbackPlayer.new;
    _tap = _PlayerSlot(factory);
    _success = _PlayerSlot(factory);
    _narration = _PlayerSlot(factory);
    _music = _PlayerSlot(factory);
  }

  static const _speechChannel = MethodChannel('tiny_trails/speech');
  static const _tapInterval = Duration(milliseconds: 110);
  static const _languages = {'ru', 'kk', 'en'};
  static const _manifestPath = 'assets/audio/narration/manifest.json';
  static const _normalMusicVolume = .10;
  static const _narrationMusicVolume = .025;

  final AssetBundle _assets;
  late final _PlayerSlot _tap;
  late final _PlayerSlot _success;
  late final _PlayerSlot _narration;
  late final _PlayerSlot _music;
  Future<Map<String, String>>? _manifest;
  final _narrationAssets = <String, Future<_NarrationAsset?>>{};
  StreamSubscription<void>? _narrationCompletion;
  DateTime? _lastTap;
  bool _disposed = false;
  bool _paused = false;
  bool _musicEnabled = false;
  bool _musicLoaded = false;
  bool _musicRunning = false;
  bool _bundledSpeaking = false;
  int _speechRevision = 0;

  bool get _audible => !_disposed && !_paused;

  /// A bundled voice is available only when its generated manifest entry points
  /// to bytes that actually load. Otherwise ask the installed offline TTS engine.
  Future<bool> isSpeechAvailable(
    String language, {
    String? narrationKey,
  }) async {
    if (_disposed || !_languages.contains(language)) return false;
    if (await _loadNarration(narrationKey, language) != null && !_disposed) {
      return true;
    }
    if (_disposed) return false;
    try {
      return await _speechChannel
              .invokeMethod<bool>('isAvailable', {'language': language})
              .timeout(const Duration(seconds: 5)) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> success({required bool sound, required bool haptics}) async {
    if (!_audible) return;
    await Future.wait<void>([
      if (sound) _playEffect(_success, 'audio/success.wav', .48),
      if (haptics) _haptic(HapticFeedback.mediumImpact),
    ]);
  }

  Future<void> tap({required bool sound, required bool haptics}) async {
    if (!_audible) return;
    final now = DateTime.now();
    final previous = _lastTap;
    if (previous != null && now.difference(previous) < _tapInterval) return;
    _lastTap = now;
    await Future.wait<void>([
      if (sound) _playEffect(_tap, 'audio/tap.wav', .32),
      if (haptics) _haptic(HapticFeedback.selectionClick),
    ]);
  }

  /// Replaces the previous hint. Recorded narration takes precedence when the
  /// requested locale file exists; missing or failed files fall back to TTS.
  /// Disabling voice stops an already playing hint without starting a new one.
  Future<void> speak(
    String text,
    String language, {
    required bool enabled,
    String? narrationKey,
  }) async {
    if (_disposed) return;
    final revision = ++_speechRevision;
    _bundledSpeaking = false;
    await Future.wait<void>([
      _stopSpeech(),
      _stopSlot(_narration),
      _syncMusic(),
    ]);
    bool current() => _audible && revision == _speechRevision;
    if (!enabled || !current()) return;
    final supportedLanguage = _languages.contains(language) ? language : 'ru';
    final narration = await _loadNarration(narrationKey, supportedLanguage);
    if (!current()) return;
    if (narration != null) {
      final played = await _narration.run((player, open) async {
        bool valid() => open() && current();
        if (!valid()) return false;
        _narrationCompletion ??= player.onComplete.listen((_) {
          if (_disposed) return;
          _bundledSpeaking = false;
          unawaited(_syncMusic());
        });
        await player.setLooping(false);
        if (!valid()) return false;
        await player.setVolume(.85);
        if (!valid()) return false;
        await player.setBytes(narration.bytes, mimeType: narration.mimeType);
        if (!valid()) return false;
        _bundledSpeaking = true;
        await _syncMusic();
        if (!valid()) return false;
        await player.resume();
        return true;
      });
      if (played || !current()) return;
      // A valid asset can still fail to decode on a particular device.
      _bundledSpeaking = false;
      await _syncMusic();
    }
    if (!current()) return;
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return;
    try {
      // Native TTS does not expose a completion stream. Keep music at the gentle
      // base volume rather than guessing speech duration with a timer.
      await _speechChannel.invokeMethod<bool>('speak', {
        'text': cleanedText.substring(0, cleanedText.length.clamp(0, 1000)),
        'language': supportedLanguage,
      });
    } on MissingPluginException {
      // Written instructions remain usable in previews without native speech.
    } on PlatformException {
      // An installed voice can be unavailable without affecting gameplay.
    }
  }

  /// Remembers the user's preference across app lifecycle pauses. Repeated
  /// calls preserve the current position rather than restarting the loop.
  Future<void> setMusicEnabled(bool enabled) async {
    if (_disposed) return;
    _musicEnabled = enabled;
    await _syncMusic();
  }

  /// Pauses all audio when the app becomes inactive. Only the enabled music
  /// resumes on return; an old spoken instruction is never replayed by surprise.
  Future<void> setPaused(bool paused) async {
    if (_disposed || _paused == paused) return;
    _paused = paused;
    if (!paused) {
      await _syncMusic();
      return;
    }
    ++_speechRevision;
    _bundledSpeaking = false;
    await Future.wait<void>([
      _stopSpeech(),
      _stopSlot(_narration),
      _stopSlot(_tap),
      _stopSlot(_success),
      _syncMusic(),
    ]);
  }

  Future<void> _syncMusic() async {
    await _music.run((player, open) async {
      bool shouldPlay() => open() && _audible && _musicEnabled;
      if (!shouldPlay()) {
        await player.pause();
        _musicRunning = false;
        return true;
      }
      if (!_musicLoaded) {
        await player.setLooping(true);
        if (!shouldPlay()) return false;
        await player.setAsset('audio/menu_loop.wav');
        _musicLoaded = true;
        if (!shouldPlay()) return false;
      }
      await player.setVolume(
        _bundledSpeaking ? _narrationMusicVolume : _normalMusicVolume,
      );
      if (!shouldPlay()) return false;
      if (!_musicRunning) {
        await player.resume();
        _musicRunning = true;
      }
      return true;
    }, create: _audible && _musicEnabled);
  }

  Future<void> _playEffect(
    _PlayerSlot slot,
    String asset,
    double volume,
  ) async {
    await slot.run((player, open) async {
      bool valid() => open() && _audible;
      if (!valid()) return false;
      await player.setVolume(volume);
      if (!valid()) return false;
      await player.setAsset(asset);
      if (!valid()) return false;
      await player.resume();
      return true;
    });
  }

  Future<Map<String, String>> _readManifest() async {
    try {
      final decoded = jsonDecode(await _assets.loadString(_manifestPath));
      final entries = decoded is Map ? decoded['entries'] : decoded;
      if (entries is! List) return const {};
      final result = <String, String>{};
      for (final raw in entries) {
        if (raw is! Map || raw['generated'] != true) continue;
        final key = raw['key'];
        final language = raw['language'];
        final asset = raw['asset'];
        if (key is! String ||
            key.isEmpty ||
            key.length > 120 ||
            !_languages.contains(language) ||
            asset is! String ||
            !RegExp(r'^audio/narration/[a-zA-Z0-9_-]+\.(mp3|wav|m4a)$')
                .hasMatch(asset)) {
          continue;
        }
        result['$key:$language'] = asset;
      }
      return result;
    } on FlutterError {
      return const {};
    } on Exception {
      return const {};
    }
  }

  Future<_NarrationAsset?> _loadNarration(String? key, String language) async {
    if (_disposed || key == null || key.isEmpty) return null;
    final manifest = await (_manifest ??= _readManifest());
    if (_disposed) return null;
    final asset = manifest['$key:$language'];
    if (asset == null) return null;
    return _narrationAssets.putIfAbsent(asset, () async {
      try {
        final data = await _assets.load('assets/$asset');
        if (_disposed || data.lengthInBytes == 0) return null;
        final mimeType = switch (asset.substring(asset.lastIndexOf('.') + 1)) {
          'mp3' => 'audio/mpeg',
          'wav' => 'audio/wav',
          'm4a' => 'audio/mp4',
          _ => null,
        };
        if (mimeType == null) return null;
        return _NarrationAsset(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          mimeType,
        );
      } on FlutterError {
        return null;
      } on Exception {
        return null;
      }
    });
  }

  Future<void> _stopSlot(_PlayerSlot slot) async {
    await slot.run((player, open) async {
      await player.stop();
      return true;
    }, create: false);
  }

  Future<void> _haptic(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // Some tablets and local previews do not provide haptic feedback.
    } on PlatformException {
      // Device-level haptics may be disabled or unavailable.
    }
  }

  /// Marks every queued operation cancelled synchronously. Existing playback
  /// pauses immediately, then its resources are released after in-flight setup.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_speechRevision;
    unawaited(_narrationCompletion?.cancel() ?? Future<void>.value());
    _narrationCompletion = null;
    _tap.close();
    _success.close();
    _narration.close();
    _music.close();
    _narrationAssets.clear();
    unawaited(_stopSpeech());
  }

  Future<void> _stopSpeech() async {
    try {
      await _speechChannel
          .invokeMethod<bool>('stop')
          .timeout(const Duration(seconds: 5));
    } on MissingPluginException {
      // No native speech channel in previews.
    } on PlatformException {
      // The system speech service may already have shut down.
    } on TimeoutException {
      // An unresponsive speech service must not block navigation.
    }
  }
}

/// BytesSource may be written to an extensionless cache file by the audio
/// plugin. Keep the validated bundle format with its bytes so AVPlayer can
/// identify MP3/WAV/M4A without relying on that temporary filename.
class _NarrationAsset {
  const _NarrationAsset(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Serializes setup and teardown for one player. Cancellation is checked after
/// source loading, so a late completion cannot start sound after navigation.
class _PlayerSlot {
  _PlayerSlot(this._factory);
  final FeedbackPlayer Function() _factory;
  FeedbackPlayer? _player;
  Future<void> _pending = Future<void>.value();
  bool _closed = false;

  Future<bool> run(
    Future<bool> Function(FeedbackPlayer player, bool Function() open) action, {
    bool create = true,
  }) {
    final operation = _pending.then((_) async {
      if (_closed || (!create && _player == null)) return false;
      try {
        final player = _player ??= _factory();
        return await action(player, () => !_closed);
      } on FlutterError {
        return false;
      } on Exception {
        // Optional feedback failure is separate from game state and rewards.
        return false;
      }
    });
    _pending = operation.then<void>((_) {});
    return operation;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final player = _player;
    if (player == null) return;
    unawaited(_safely(player.pause));
    unawaited(_pending.then((_) => _safely(player.dispose)));
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on FlutterError {
      // Asset loading may report an unavailable preview backend this way.
    } on Exception {
      // The native audio session can already have been interrupted or released.
    }
  }
}

class _DeviceFeedbackPlayer implements FeedbackPlayer {
  final _player = AudioPlayer();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;
  @override
  Future<void> setAsset(String asset) => _player.setSource(AssetSource(asset));
  @override
  Future<void> setBytes(Uint8List bytes, {required String mimeType}) =>
      _player.setSource(BytesSource(bytes, mimeType: mimeType));
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setLooping(bool looping) =>
      _player.setReleaseMode(looping ? ReleaseMode.loop : ReleaseMode.release);
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}
