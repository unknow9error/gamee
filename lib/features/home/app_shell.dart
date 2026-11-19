import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/trail_icon.dart';
import '../play/play_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';
import 'interface_tour.dart';
import 'studio_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final GameController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  bool _retrying = false;
  InterfaceTourStep? _tourStep;
  bool _offeredTour = false;
  final _startTarget = GlobalKey(debugLabel: 'tour-start');
  final _chapterTarget = GlobalKey(debugLabel: 'tour-chapters');
  final _settingsTarget = GlobalKey(debugLabel: 'tour-settings');
  final _navigationTargets = List.generate(
    3,
    (index) => GlobalKey(debugLabel: 'tour-navigation-$index'),
  );

  @override
  void initState() {
    super.initState();
    _offerTour();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _tourStep = null;
      _offeredTour = false;
      _offerTour();
    }
  }

  void _offerTour() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _offeredTour ||
          ModalRoute.of(context)?.isCurrent != true ||
          !widget.controller.needsInterfaceTour) {
        return;
      }
      _offeredTour = true;
      _startTour();
    });
  }

  void _startTour() {
    setState(() {
      _tab = 0;
      _tourStep = InterfaceTourStep.begin;
    });
  }

  void _showTourStep(InterfaceTourStep step) {
    setState(() {
      _tourStep = step;
      _tab = step.tab;
    });
  }

  void _dismissTour() {
    if (_tourStep == null) return;
    setState(() {
      _tourStep = null;
      _tab = 0;
    });
    unawaited(widget.controller.markInterfaceTourSeen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tourStep != null) return;
      final target = _startTarget.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, alignment: .15));
      }
    });
  }

  GlobalKey _targetFor(InterfaceTourStep step) => switch (step) {
    InterfaceTourStep.begin => _startTarget,
    InterfaceTourStep.chapters => _chapterTarget,
    InterfaceTourStep.studio => _navigationTargets[1],
    InterfaceTourStep.rewards => _navigationTargets[2],
    InterfaceTourStep.settings => _settingsTarget,
  };

  Future<void> _openSettings() async {
    final replay = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (settingsContext) => SettingsScreen(
          controller: widget.controller,
          onReplayGuide: () => Navigator.of(settingsContext).pop(true),
        ),
      ),
    );
    if (mounted && replay == true) _startTour();
  }

  void _play(LevelDefinition level) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayScreen(controller: widget.controller, level: level),
    ),
  );

  Future<void> _retrySaving() async {
    setState(() => _retrying = true);
    try {
      await widget.controller.retryPersistence();
    } catch (_) {
      // The controller keeps a localized recovery message in the banner.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final lang = c.language;
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final labels = [
        textFor(lang, 'Приключения', 'Шытырман', 'Adventures'),
        textFor(lang, 'Мастерская', 'Шеберхана', 'My studio'),
        textFor(lang, 'Награды', 'Марапаттар', 'Rewards'),
      ];
      const icons = [
        TrailIconKind.adventures,
        TrailIconKind.studio,
        TrailIconKind.rewards,
      ];
      final tour = _tourStep;
      final scaffold = Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 18,
                  8,
                  wide ? 32 : 12,
                  8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const TrailIcon(
                        TrailIconKind.leaf,
                        color: AppColors.lime,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'tiny trails',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    StarCount(count: c.totalStars),
                    const SizedBox(width: 2),
                    KeyedSubtree(
                      key: _settingsTarget,
                      child: IconButton(
                        key: const Key('open-settings'),
                        tooltip: textFor(
                          lang,
                          'Настройки',
                          'Баптаулар',
                          'Settings',
                        ),
                        onPressed: _openSettings,
                        icon: const TrailIcon(TrailIconKind.settings),
                      ),
                    ),
                  ],
                ),
              ),
              if (c.persistenceError != null)
                Container(
                  key: const Key('persistence-banner'),
                  width: double.infinity,
                  color: AppColors.peach.withValues(alpha: .40),
                  padding: const EdgeInsets.fromLTRB(18, 10, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.cloud_off_rounded, size: 20),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                c.persistenceError!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            key: const Key('retry-persistence'),
                            onPressed: _retrying ? null : _retrySaving,
                            icon: _retrying
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              textFor(
                                lang,
                                'Повторить сохранение',
                                'Қайта сақтау',
                                'Retry saving',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _tab = 1),
                            child: Text(
                              textFor(
                                lang,
                                'Открыть альбом',
                                'Альбомды ашу',
                                'Open my album',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      NavigationRail(
                        selectedIndex: _tab,
                        onDestinationSelected: (value) =>
                            setState(() => _tab = value),
                        backgroundColor: AppColors.paper,
                        indicatorColor: AppColors.lime,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (var index = 0; index < labels.length; index++)
                            NavigationRailDestination(
                              icon: KeyedSubtree(
                                key: _navigationTargets[index],
                                child: TrailIcon(
                                  icons[index],
                                  selected: _tab == index,
                                ),
                              ),
                              label: Text(labels[index]),
                            ),
                        ],
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          HomeScreen(
                            controller: c,
                            onPlay: _play,
                            onOpenSettings: _openSettings,
                            startTourTarget: _startTarget,
                            chapterTourTarget: _chapterTarget,
                          ),
                          StudioScreen(controller: c, onPlay: _play),
                          ProgressScreen(controller: c, onPlay: _play),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                height: 74,
                backgroundColor: AppColors.paper,
                indicatorColor: AppColors.lime,
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                destinations: [
                  for (var index = 0; index < labels.length; index++)
                    NavigationDestination(
                      icon: KeyedSubtree(
                        key: _navigationTargets[index],
                        child: TrailIcon(icons[index], selected: _tab == index),
                      ),
                      label: labels[index],
                    ),
                ],
              ),
      );
      return PopScope<void>(
        canPop: tour == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _tourStep != null) _dismissTour();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: tour != null,
              child: ExcludeSemantics(
                excluding: tour != null,
                child: AbsorbPointer(absorbing: tour != null, child: scaffold),
              ),
            ),
            if (tour != null)
              InterfaceTour(
                step: tour,
                target: _targetFor(tour),
                language: lang,
                reducedMotion: c.reducedMotion,
                onDismiss: _dismissTour,
                onBack: tour.index == 0
                    ? null
                    : () => _showTourStep(
                        InterfaceTourStep.values[tour.index - 1],
                      ),
                onNext: tour == InterfaceTourStep.settings
                    ? _dismissTour
                    : () => _showTourStep(
                        InterfaceTourStep.values[tour.index + 1],
                      ),
              ),
          ],
        ),
      );
    },
  );
}
