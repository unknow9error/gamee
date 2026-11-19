import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/game_controller.dart';
import '../../core/feedback_service.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../shared/widgets/fini_companion.dart';
import '../../shared/widgets/trail_icon.dart';
import '../settings/child_age_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _pages = PageController();
  final _feedback = FeedbackService();
  int _page = 0;
  int? _selectedAge;
  bool _speechAvailable = false;
  String? _checkedSpeech;
  int _speechRevision = 0;
  bool get _reduceMotion =>
      widget.controller.reducedMotion ||
      MediaQuery.disableAnimationsOf(context);

  String _t(String ru, String kk, String en) =>
      textFor(widget.controller.language, ru, kk, en);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_controllerChanged);
    unawaited(_refreshSpeechAvailability());
  }

  @override
  void didUpdateWidget(OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      _checkedSpeech = null;
      unawaited(_refreshSpeechAvailability());
    }
  }

  void _controllerChanged() => unawaited(_refreshSpeechAvailability());

  Future<void> _refreshSpeechAvailability() async {
    final controller = widget.controller;
    final key = '${controller.language}:$_page:${controller.voice}';
    if (_checkedSpeech == key) return;
    _checkedSpeech = key;
    final revision = ++_speechRevision;
    if (_speechAvailable && mounted) setState(() => _speechAvailable = false);
    await _feedback.speak('', controller.language, enabled: false);
    final available =
        controller.voice &&
        await _feedback.isSpeechAvailable(
          controller.language,
          narrationKey: 'onboarding_0${_page + 1}',
        );
    if (mounted && revision == _speechRevision && _checkedSpeech == key) {
      setState(() => _speechAvailable = available);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_feedback.setPaused(state != AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_controllerChanged);
    _speechRevision++;
    _feedback.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page == 2 && _selectedAge == null) return;
    _pages.animateToPage(
      page,
      duration: Duration(milliseconds: _reduceMotion ? 1 : 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _chooseAge(int age) {
    setState(() => _selectedAge = age);
    unawaited(widget.controller.setChildAge(age));
  }

  void _next() {
    if (_page == 2) {
      if (_selectedAge != null) unawaited(widget.controller.finishOnboarding());
    } else {
      _goTo(_page + 1);
    }
  }

  Widget _headerAction() => _page == 0
      ? TextButton(
          key: const Key('onboarding-skip-intro'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _goTo(1),
          child: Text(
            _t('Выбрать возраст', 'Жасты таңдау', 'Choose age'),
            textAlign: TextAlign.center,
          ),
        )
      : TextButton.icon(
          key: const Key('onboarding-back'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _goTo(_page - 1),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(_t('Назад', 'Артқа', 'Back')),
        );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final size = MediaQuery.sizeOf(context);
      final compact = size.height < 450;
      final stackedHeader =
          size.width < 360 ||
          size.width < 600 && MediaQuery.textScalerOf(context).scale(14) > 20;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, compact ? 4 : 12, 12, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const TrailIcon(TrailIconKind.leaf, size: 26),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'tiny trails',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.7,
                                ),
                              ),
                            ),
                            if (_speechAvailable)
                              IconButton(
                                key: const Key('onboarding-speak'),
                                tooltip: _t('Послушать', 'Тыңдау', 'Listen'),
                                onPressed: () => unawaited(
                                  _feedback.speak(
                                    _pageBody(_page),
                                    widget.controller.language,
                                    enabled: widget.controller.voice,
                                    narrationKey: 'onboarding_0${_page + 1}',
                                  ),
                                ),
                                icon: const TrailIcon(
                                  TrailIconKind.speaker,
                                  size: 25,
                                ),
                              ),
                            if (!stackedHeader)
                              Flexible(flex: 2, child: _headerAction()),
                          ],
                        ),
                        if (stackedHeader)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _headerAction(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      key: const Key('onboarding-pages'),
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() => _page = page);
                        unawaited(_refreshSpeechAvailability());
                      },
                      children: [
                        _pageLayout(0),
                        _pageLayout(1),
                        _pageLayout(2),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      compact ? 4 : 10,
                      22,
                      compact ? 6 : 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: _t(
                            'Шаг ${_page + 1} из 3',
                            '3 қадамның ${_page + 1}-қадамы',
                            'Step ${_page + 1} of 3',
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (index) => AnimatedContainer(
                                duration: Duration(
                                  milliseconds: _reduceMotion ? 0 : 200,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: index == _page ? 25 : 8,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: index == _page
                                      ? AppColors.green
                                      : AppColors.line,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 15),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('onboarding-next'),
                              onPressed: _page == 1 && _selectedAge == null
                                  ? null
                                  : _next,
                              label: Text(
                                _page == 2
                                    ? _t(
                                        'Пойдём играть!',
                                        'Ойнауға кеттік!',
                                        'Let’s go play!',
                                      )
                                    : _page == 1 && _selectedAge == null
                                    ? _t(
                                        'Выберите возраст',
                                        'Жасты таңдаңыз',
                                        'Choose an age',
                                      )
                                    : _t('Дальше', 'Келесі', 'Next'),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _pageLayout(int index) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 680;
      final illustrationSide = math
          .min(
            wide ? constraints.maxHeight - 16 : constraints.maxWidth * .72,
            wide ? 350.0 : 260.0,
          )
          .clamp(110.0, 350.0)
          .toDouble();
      final content = _pageContent(index);
      if (wide) {
        return Row(
          children: [
            Expanded(
              flex: 4,
              child: Center(child: _illustration(index, illustrationSide)),
            ),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                key: ValueKey('onboarding-content-$index'),
                padding: const EdgeInsets.fromLTRB(18, 16, 28, 20),
                child: content,
              ),
            ),
          ],
        );
      }
      return SingleChildScrollView(
        key: ValueKey('onboarding-content-$index'),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
        child: Column(
          children: [
            if (index != 1) ...[
              _illustration(index, illustrationSide),
              const SizedBox(height: 20),
            ],
            content,
          ],
        ),
      );
    },
  );

  Widget _illustration(int index, double side) => SizedBox(
    width: side,
    height: side,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: side * .91,
          height: side * .91,
          decoration: BoxDecoration(
            color: [
              AppColors.lime,
              AppColors.blue,
              AppColors.peach,
            ][index].withValues(alpha: .65),
            shape: BoxShape.circle,
          ),
        ),
        FiniCompanion(
          size: side,
          reducedMotion: _reduceMotion,
          animate: _page == index,
          semanticLabel: _t('Лисёнок Фини', 'Фини түлкі', 'Fini the fox'),
        ),
      ],
    ),
  );

  Widget _pageContent(int index) {
    final title = [
      _t(
        'Большой мир\nмаленьких открытий',
        'Кішкентай жаңалықтардың\nүлкен әлемі',
        'A big world of\nlittle discoveries',
      ),
      _t('Возраст\nребёнка', 'Балаңыздың\nжасы', 'Your child’s\nage'),
      _t(
        'Учимся\nбез спешки',
        'Асықпай\nүйренеміз',
        'Little discoveries,\nat your own pace',
      ),
    ][index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index == 1) ...[
          Text(
            _t('РОДИТЕЛЯМ', 'АТА-АНАЛАРҒА', 'FOR GROWN-UPS'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.green,
              letterSpacing: 1.5,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        Text(
          _pageBody(index),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (index == 0) _languagePicker(),
        if (index == 1)
          ChildAgePicker(
            language: widget.controller.language,
            selectedAge: _selectedAge,
            onChanged: _chooseAge,
            keyPrefix: 'onboarding-age',
          ),
        if (index == 2) ...[
          _benefit(
            TrailIconKind.rewards,
            AppColors.yellow,
            _t(
              '20 наклеек для коллекции',
              'Жинаққа арналған 20 жапсырма',
              '20 stickers to collect',
            ),
          ),
          const SizedBox(height: 9),
          _benefit(
            TrailIconKind.heart,
            AppColors.lime,
            _t(
              'Можно учиться в своём темпе',
              'Өз қарқыныңмен үйренуге болады',
              'Learn at your own pace',
            ),
          ),
          const SizedBox(height: 9),
          _benefit(
            TrailIconKind.offline,
            AppColors.blue,
            _t(
              'Играем без интернета и рекламы',
              'Интернетсіз және жарнамасыз ойнаймыз',
              'Play offline, without ads',
            ),
          ),
        ],
      ],
    );
  }

  String _pageBody(int index) => [
    _t(
      'Я лисёнок Фини! Нас ждут 20 разных игр: будем рисовать, искать, сравнивать и открывать новое.',
      'Мен Фини түлкімін! Бізді 20 түрлі ойын күтіп тұр: сурет саламыз, іздейміз, салыстырамыз және жаңалық ашамыз.',
      'I’m Fini the fox! There are 20 different games to draw, search, compare, and discover.',
    ),
    _t(
      'Выберите возраст от 3 до 11 лет. Он нужен только для сложности игр — без имени и даты рождения.',
      '3–11 жас аралығын таңдаңыз. Бұл тек ойын қиындығы үшін қажет. Есім мен туған күн керек емес.',
      'Choose an age from 3 to 11 to set the game difficulty. No name or birthday is needed.',
    ),
    _t(
      'Каждая игра дарит наклейку. Подсказки всегда рядом, а рисунки и открытия сохраняются на устройстве.',
      'Әр ойын жапсырма сыйлайды. Кеңестер әрдайым жаныңда, ал суреттер мен жаңалықтар құрылғыда сақталады.',
      'Every game gives you a sticker. Help is always nearby, and your drawings and discoveries stay on this device.',
    ),
  ][index];

  Widget _languagePicker() => LayoutBuilder(
    builder: (context, constraints) {
      const languages = [
        ('ru', 'Русский'),
        ('kk', 'Қазақша'),
        ('en', 'English'),
      ];
      const labelStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        // Nunito's proportional leading keeps the visible letters centered.
        height: 1.1,
      );
      final effectiveStyle = DefaultTextStyle.of(context).style
          .merge(labelStyle);
      final labelWidth = constraints.maxWidth / languages.length - 18;
      var stackButtons = false;
      for (final language in languages) {
        final painter = TextPainter(
          text: TextSpan(text: language.$2, style: effectiveStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        stackButtons = stackButtons || painter.width > labelWidth;
        painter.dispose();
      }

      Widget languageButton((String, String) language) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          selected: widget.controller.language == language.$1,
          button: true,
          child: Material(
            color: widget.controller.language == language.$1
                ? AppColors.lime
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('onboarding-language-${language.$1}'),
              onTap: () => widget.controller.setLanguage(language.$1),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Center(
                    heightFactor: 1,
                    child: Text(
                      language.$2,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Keep native names intact when accessibility text outgrows three columns.
      if (stackButtons) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < languages.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              languageButton(languages[index]),
            ],
          ],
        );
      }
      return Row(
        children: [
          for (final language in languages)
            Expanded(child: languageButton(language)),
        ],
      );
    },
  );

  Widget _benefit(TrailIconKind icon, Color color, String label) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(child: TrailIcon(icon, size: 28)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
