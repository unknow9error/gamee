import 'package:flutter/widgets.dart';

import 'feedback_service.dart';

/// Shares one audio session across navigation, including dialogs and overlays.
/// Route widgets may stop narration, but the application owns its lifetime.
class AppAudioScope extends InheritedWidget {
  AppAudioScope({
    super.key,
    required this.feedback,
    AppNarration? narration,
    required super.child,
  }) : narration = narration ?? AppNarration(feedback);

  final FeedbackService feedback;
  final AppNarration narration;

  static FeedbackService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAudioScope>()?.feedback;

  static FeedbackService of(BuildContext context) {
    final feedback = maybeOf(context);
    if (feedback == null) {
      throw FlutterError('AppAudioScope is required above this widget.');
    }
    return feedback;
  }

  static AppNarration? maybeNarrationOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAudioScope>()?.narration;

  static AppNarration narrationOf(BuildContext context) {
    final narration = maybeNarrationOf(context);
    if (narration == null) {
      throw FlutterError('AppAudioScope is required above this widget.');
    }
    return narration;
  }

  @override
  bool updateShouldNotify(AppAudioScope oldWidget) =>
      oldWidget.feedback != feedback || oldWidget.narration != narration;
}

/// A departing route may stop only its own narration. This prevents its dispose
/// callback from interrupting the next route during a replacement transition.
class AppNarration {
  AppNarration(this._feedback);

  final FeedbackService _feedback;
  Object? _owner;
  String _language = 'ru';

  Future<void> speak(
    Object owner,
    String text,
    String language, {
    required bool enabled,
    String? narrationKey,
  }) {
    _owner = owner;
    _language = language;
    return _feedback.speak(
      text,
      language,
      enabled: enabled,
      narrationKey: narrationKey,
    );
  }

  Future<void> stop(Object owner) {
    if (!identical(_owner, owner)) return Future<void>.value();
    return stopAll();
  }

  Future<void> stopAll({String? language}) {
    _owner = null;
    return _feedback.speak('', language ?? _language, enabled: false);
  }
}
