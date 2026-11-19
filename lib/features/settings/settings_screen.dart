import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/game_controller.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/catalog.dart';
import '../../shared/widgets/trail_icon.dart';
import 'child_age_picker.dart';

/// Preferences are available to the child; destructive actions live behind the
/// parent gate and a separate, explicit confirmation.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.onReplayGuide,
  });

  final GameController controller;
  final VoidCallback? onReplayGuide;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _parentUnlocked = false;
  bool _resetting = false;
  int _parentSession = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _parentSession++;
    if (_parentUnlocked && mounted) setState(() => _parentUnlocked = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _t(String ru, String kk, String en) =>
      textFor(widget.controller.language, ru, kk, en);

  Future<void> _openParentArea() async {
    final session = _parentSession;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => _ParentGate(language: widget.controller.language),
    );
    if (mounted && allowed == true && session == _parentSession) {
      setState(() => _parentUnlocked = true);
    }
  }

  Future<void> _resetProgress() async {
    if (!_parentUnlocked || _resetting) return;
    final session = _parentSession;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.restart_alt_rounded, size: 32),
        title: Text(_t('Начать заново?', 'Қайта бастаймыз ба?', 'Start over?')),
        content: Text(
          [
            _t(
              'Уровни, рисунки, наклейки и календарь будут удалены с этого устройства.',
              'Осы құрылғыдағы деңгейлер, суреттер, жапсырмалар мен күнтізбе өшіріледі.',
              'Levels, drawings, stickers, and the calendar will be removed from this device.',
            ),
            if (widget.controller.hasLegacyArchive ||
                widget.controller.legacyDamagedEntries > 0)
              _t(
                'Сохранённая история предыдущей версии тоже будет удалена.',
                'Алдыңғы нұсқаның сақталған тарихы да өшіріледі.',
                'Saved history from the previous version will also be deleted.',
              ),
            _t(
              'Отменить это действие не получится.',
              'Бұл әрекетті болдырмау мүмкін емес.',
              'This cannot be undone.',
            ),
          ].join(' '),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Оставить', 'Сақтау', 'Keep them')),
          ),
          FilledButton(
            key: const ValueKey('confirm-reset-progress'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFAE5144),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _t('Удалить прогресс', 'Жетістікті өшіру', 'Delete progress'),
            ),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !_parentUnlocked ||
        session != _parentSession) {
      return;
    }
    setState(() => _resetting = true);
    var saved = false;
    try {
      await widget.controller.resetProgress();
      saved = widget.controller.persistenceError == null;
    } on Exception {
      // The controller keeps the precise persistence status. Never report a
      // successful deletion when either the current save or archive failed.
    }
    if (!mounted) return;
    setState(() => _resetting = false);
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Всё готово для нового приключения',
              'Жаңа шытырман оқиғаға бәрі дайын',
              'Ready for a fresh adventure',
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Сброс не завершён.',
                  'Прогресті өшіру аяқталмады.',
                  'Reset was not completed.',
                ),
              ),
              if (widget.controller.persistenceError != null)
                Text(widget.controller.persistenceError!),
            ],
          ),
          action: SnackBarAction(
            label: _t('Повторить', 'Қайталау', 'Retry'),
            onPressed: _resetProgress,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(_t('Настройки', 'Баптаулар', 'Settings')),
        leading: IconButton(
          tooltip: _t('Назад', 'Артқа', 'Back'),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _intro(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    _t(
                      'Говорим на твоём языке',
                      'Өз тіліңде сөйлесейік',
                      'Speak your language',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _languageCard(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    _t(
                      'Как тебе нравится',
                      'Өзіңе ыңғайлы болсын',
                      'Make it yours',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _preferencesCard(),
                  if (widget.onReplayGuide != null) ...[
                    const SizedBox(height: 24),
                    _guideCard(),
                  ],
                  const SizedBox(height: 24),
                  _parentArea(),
                  const SizedBox(height: 24),
                  _offlineNote(),
                  if (widget.controller.persistenceError != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.controller.persistenceError!,
                        style: const TextStyle(color: Color(0xFFAE5144)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _intro() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.lime.withValues(alpha: .48),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const TrailIcon(
            TrailIconKind.settings,
            size: 30,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Твоё уютное место',
                  'Сенің жайлы мекенің',
                  'Your happy little place',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _t(
                  'Настрой всё для новых открытий.',
                  'Жаңа жаңалықтарға дайын бол.',
                  'A few little touches for your next discovery.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _guideCard() => Material(
    color: AppColors.blue.withValues(alpha: .5),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      key: const Key('settings-replay-fini-guide'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      minVerticalPadding: 14,
      leading: const TrailIcon(TrailIconKind.hint, size: 40),
      title: Text(
        _t(
          'Фини, покажи приложение',
          'Фини, қолданбаны көрсетші',
          'Fini, show me around',
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _t(
            'Снова пройдёмся по главным кнопкам.',
            'Негізгі батырмаларды қайта көрейік.',
            'Take another little tour of the main buttons.',
          ),
        ),
      ),
      onTap: widget.onReplayGuide,
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _languageCard() {
    const languages = [
      ('ru', 'Русский', 'RU'),
      ('kk', 'Қазақша', 'ҚАЗ'),
      ('en', 'English', 'EN'),
    ];
    return _SettingsCard(
      child: Column(
        children: [
          for (var index = 0; index < languages.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 20, endIndent: 20),
            Builder(
              builder: (context) {
                final (code, name, abbreviation) = languages[index];
                final selected = widget.controller.language == code;
                return Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: ValueKey('language-$code'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => widget.controller.setLanguage(code),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.lime
                                  : AppColors.paper,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(
                              abbreviation,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? AppColors.green : AppColors.line,
                            size: 27,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _preferencesCard() => _SettingsCard(
    child: Column(
      children: [
        _PreferenceTile(
          icon: TrailIconKind.speaker,
          color: AppColors.peach,
          title: _t('Звуки', 'Дыбыстар', 'Sounds'),
          subtitle: _t(
            'Маленькие мелодии и радостные отклики',
            'Шағын әуендер мен көңілді дыбыстар',
            'Little melodies and cheerful sounds',
          ),
          value: widget.controller.sound,
          onChanged: widget.controller.setSound,
          settingKey: 'sound',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.speaker,
          color: AppColors.yellow,
          title: _t('Музыка', 'Музыка', 'Music'),
          subtitle: _t(
            'Тихая мелодия для игры и творчества',
            'Ойын мен шығармашылыққа арналған баяу әуен',
            'A gentle melody for play and creativity',
          ),
          value: widget.controller.musicEnabled,
          onChanged: widget.controller.setMusicEnabled,
          settingKey: 'music',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.fox,
          color: AppColors.blue,
          title: _t('Голосовые подсказки', 'Дауыстық кеңестер', 'Spoken hints'),
          subtitle: _t(
            'Записанные подсказки работают без интернета',
            'Жазылған кеңестер интернетсіз жұмыс істейді',
            'Recorded instructions, available offline',
          ),
          value: widget.controller.voice,
          onChanged: widget.controller.setVoice,
          settingKey: 'voice',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.hint,
          color: AppColors.peach,
          title: _t(
            'Наглядные подсказки',
            'Көрнекі кеңестер',
            'Visual guidance',
          ),
          subtitle: _t(
            'Помощник показывает следующий шаг',
            'Көмекші келесі қадамды көрсетеді',
            'Your helper shows the next step',
          ),
          value: widget.controller.guidanceEnabled,
          onChanged: widget.controller.setGuidanceEnabled,
          settingKey: 'guidance',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.sparkles,
          color: AppColors.lavender,
          title: _t('Отклик на касание', 'Жанасу жауабы', 'Touch feedback'),
          subtitle: _t(
            'Лёгкая вибрация на телефоне',
            'Телефондағы жеңіл діріл',
            'Gentle vibrations on your phone',
          ),
          value: widget.controller.haptics,
          onChanged: widget.controller.setHaptics,
          settingKey: 'haptics',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.leaf,
          color: AppColors.lime,
          title: _t('Спокойные анимации', 'Баяу анимациялар', 'Gentle motion'),
          subtitle: _t(
            'Меньше движения, столько же радости',
            'Қимыл аз, қуаныш сол күйінде',
            'Less movement, just as much joy',
          ),
          value: widget.controller.reducedMotion,
          onChanged: widget.controller.setReducedMotion,
          settingKey: 'reduced-motion',
        ),
        const Divider(height: 1, indent: 78, endIndent: 18),
        _PreferenceTile(
          icon: TrailIconKind.rest,
          color: AppColors.blue,
          title: _t('Время отдохнуть', 'Демалыс уақыты', 'A little break'),
          subtitle: _t(
            'Мягкое предложение сделать паузу после игры',
            'Ойыннан кейін үзіліс жасауды жайлап ұсыну',
            'A gentle invitation to rest after playing',
          ),
          value: widget.controller.breakReminders,
          onChanged: widget.controller.setBreakReminders,
          settingKey: 'break-reminders',
        ),
      ],
    ),
  );

  Widget _parentArea() => _SettingsCard(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _parentUnlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Для родителей', 'Ата-аналарға', 'For grown-ups'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      _t(
                        'Успехи и управление прогрессом',
                        'Жетістіктер мен ойын барысы',
                        'Learning progress and a fresh start',
                      ),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_parentUnlocked)
            OutlinedButton.icon(
              key: const ValueKey('open-parent-area'),
              onPressed: _openParentArea,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 52),
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 19),
              label: Text(
                _t(
                  'Открыть родительский раздел',
                  'Ата-аналар бөлімін ашу',
                  'Open grown-ups area',
                ),
              ),
            )
          else ...[
            Text(
              _t(
                'Сколько лет ребёнку?',
                'Бала неше жаста?',
                'How old is your child?',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ChildAgePicker(
              language: widget.controller.language,
              selectedAge: widget.controller.childAge,
              onChanged: widget.controller.setChildAge,
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'Возраст меняет сложность заданий. Имя и дата рождения не нужны. Выбор можно изменить в любой момент.',
                'Жас тапсырмалардың қиындығын өзгертеді. Есім мен туған күн қажет емес. Таңдауды кез келген уақытта өзгертуге болады.',
                'Age changes the activity difficulty. No name or birthday is needed. You can change this choice at any time.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _ParentStat(
                  value:
                      '${widget.controller.completedCount} / ${levels.length}',
                  label: _t(
                    'уровней пройдено',
                    'деңгей аяқталды',
                    'levels completed',
                  ),
                ),
                _ParentStat(
                  value: '${widget.controller.playedDates.length}',
                  label: _t(
                    russianPlural(
                      widget.controller.playedDates.length,
                      'день открытий',
                      'дня открытий',
                      'дней открытий',
                    ),
                    'жаңалық күні',
                    widget.controller.playedDates.length == 1
                        ? 'day of discoveries'
                        : 'days of discoveries',
                  ),
                ),
                _ParentStat(
                  value: '${widget.controller.totalStars}',
                  label: _t(
                    russianPlural(
                      widget.controller.totalStars,
                      'звезда',
                      'звезды',
                      'звёзд',
                    ),
                    'жұлдыз',
                    widget.controller.totalStars == 1 ? 'star' : 'stars',
                  ),
                ),
              ],
            ),
            if (widget.controller.hasLegacyArchive) ...[
              const SizedBox(height: 14),
              Text(
                _t(
                  'В Мастерской также сохранена история предыдущей версии: ${widget.controller.legacyCompletedCount} заданий.',
                  'Шеберханада алдыңғы нұсқаның тарихы да сақталған: ${widget.controller.legacyCompletedCount} тапсырма.',
                  'My studio also keeps your history from the previous version: ${widget.controller.legacyCompletedCount} activities.',
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _t(
                'Лучше заниматься понемногу и вместе. Подсказки не уменьшают награды, а каждое задание можно повторить.',
                'Аз-аздан, бірге ойнаған жақсы. Кеңестер марапатты азайтпайды, әр тапсырманы қайталауға болады.',
                'Little moments together work well. Hints never reduce rewards, and every activity can be replayed.',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('reset-progress'),
              onPressed: _resetting ? null : _resetProgress,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFAE5144),
                minimumSize: const Size(48, 52),
                side: const BorderSide(color: Color(0xFFE8CAC5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _resetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt_rounded),
              label: Text(
                _t('Сбросить прогресс', 'Ойын барысын өшіру', 'Reset progress'),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _offlineNote() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        const TrailIcon(TrailIconKind.heart, size: 23, color: AppColors.green),
        const SizedBox(height: 8),
        Text(
          _t(
            'Можно играть без интернета',
            'Интернетсіз ойнауға болады',
            'Made for offline adventures',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          _t(
            'Все 20 игр доступны без интернета. Без рекламы, регистрации и сервера. Возраст, рисунки и успехи хранятся только на этом устройстве.',
            'Барлық 20 ойын интернетсіз қолжетімді. Жарнама, тіркелу мен сервер жоқ. Жас, суреттер мен жетістіктер тек осы құрылғыда сақталады.',
            'All 20 games work offline. No ads, sign-ups, or server. Age, drawings, and progress stay on this device.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.settingKey,
  });
  final TrailIconKind icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String settingKey;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TrailIcon(icon, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            key: ValueKey('setting-$settingKey'),
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.green,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
          ),
        ],
      ),
    ),
  );
}

class _ParentStat extends StatelessWidget {
  const _ParentStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 120),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ParentGate extends StatefulWidget {
  const _ParentGate({required this.language});
  final String language;

  @override
  State<_ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<_ParentGate> {
  final _answer = TextEditingController();
  final _random = Random();
  late final int _left = 13 + _random.nextInt(7);
  late final int _right = 12 + _random.nextInt(8);
  bool _incorrect = false;

  String _t(String ru, String kk, String en) =>
      textFor(widget.language, ru, kk, en);

  void _submit() {
    if (int.tryParse(_answer.text.trim()) == _left * _right) {
      Navigator.pop(context, true);
    } else {
      setState(() => _incorrect = true);
      _answer.clear();
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: const Icon(Icons.lock_outline_rounded, size: 32),
    title: Text(_t('Позови взрослого', 'Ересекті шақыр', 'Ask a grown-up')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t(
            'Этот раздел для родителей. Решите пример, чтобы продолжить.',
            'Бұл бөлім ата-аналарға арналған. Жалғастыру үшін есепті шығарыңыз.',
            'This area is for grown-ups. Solve the problem to continue.',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$_left × $_right = ?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('parent-gate-answer'),
          controller: _answer,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: _t('Ответ', 'Жауап', 'Answer'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            errorText: _incorrect
                ? _t('Попробуйте ещё раз', 'Қайта көріңіз', 'Please try again')
                : null,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => Navigator.pop(context, false),
        child: Text(_t('Назад', 'Артқа', 'Back')),
      ),
      FilledButton(
        key: const ValueKey('parent-gate-submit'),
        onPressed: _submit,
        child: Text(_t('Продолжить', 'Жалғастыру', 'Continue')),
      ),
    ],
  );
}
