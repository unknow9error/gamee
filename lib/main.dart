import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/game_controller.dart';
import 'core/app_audio_scope.dart';
import 'core/feedback_service.dart';
import 'core/theme.dart';
import 'features/home/app_shell.dart';
import 'features/home/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await GameController.load();
  runApp(TinyTrailsApp(controller: controller));
}

class TinyTrailsApp extends StatefulWidget {
  const TinyTrailsApp({
    super.key,
    required this.controller,
    this.feedbackFactory,
  });
  final GameController controller;
  final FeedbackService Function()? feedbackFactory;

  @override
  State<TinyTrailsApp> createState() => _TinyTrailsAppState();
}

class _TinyTrailsAppState extends State<TinyTrailsApp>
    with WidgetsBindingObserver {
  late final _feedback = widget.feedbackFactory?.call() ?? FeedbackService();
  late final _narration = AppNarration(_feedback);
  bool _foreground = true;
  bool? _musicEnabled;
  bool? _voiceEnabled;
  String? _language;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncPreferences);
    _syncPreferences();
    _syncLifecycle();
  }

  @override
  void didUpdateWidget(TinyTrailsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncPreferences);
    oldWidget.controller.pauseSession();
    unawaited(_narration.stopAll(language: oldWidget.controller.language));
    widget.controller.addListener(_syncPreferences);
    _syncPreferences();
    _syncLifecycle();
  }

  void _syncPreferences() {
    final controller = widget.controller;
    if (_musicEnabled != controller.musicEnabled) {
      _musicEnabled = controller.musicEnabled;
      unawaited(_feedback.setMusicEnabled(controller.musicEnabled));
    }
    if ((_voiceEnabled == true && !controller.voice) ||
        (_language != null && _language != controller.language)) {
      unawaited(_narration.stopAll(language: controller.language));
    }
    _voiceEnabled = controller.voice;
    _language = controller.language;
  }

  void _syncLifecycle() {
    unawaited(_feedback.setPaused(!_foreground));
    if (_foreground) {
      widget.controller.resumeSession();
    } else {
      widget.controller.pauseSession();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _syncLifecycle();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncPreferences);
    widget.controller.pauseSession();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppAudioScope(
    feedback: _feedback,
    narration: _narration,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final reducedMotion =
            widget.controller.reducedMotion ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations;
        final theme = buildTheme();
        return MaterialApp(
          title: 'Tiny Trails',
          debugShowCheckedModeBanner: false,
          theme: reducedMotion
              ? theme.copyWith(
                  pageTransitionsTheme: PageTransitionsTheme(
                    builders: {
                      for (final platform in TargetPlatform.values)
                        platform: const _NoMotionTransitions(),
                    },
                  ),
                )
              : theme,
          themeAnimationDuration: reducedMotion
              ? Duration.zero
              : kThemeAnimationDuration,
          locale: Locale(widget.controller.language),
          supportedLocales: const [Locale('ru'), Locale('kk'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  reducedMotion || MediaQuery.disableAnimationsOf(context),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: widget.controller.onboardingComplete
              ? AppShell(controller: widget.controller)
              : OnboardingScreen(controller: widget.controller),
        );
      },
    ),
  );
}

class _NoMotionTransitions extends PageTransitionsBuilder {
  const _NoMotionTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
