import '../domain/models.dart';
import '../domain/calendar.dart';
import 'legacy_catalog.dart';

const contentVersion = 2;

/// Ten teaching mechanics, each represented by exactly two authored levels.
/// Free coloring remains a creative replay tool, outside the 20-level catalog.
const activeActivityKinds = <ActivityKind>[
  ActivityKind.numberColor,
  ActivityKind.oddFragment,
  ActivityKind.connectDots,
  ActivityKind.matchPairs,
  ActivityKind.patternSequence,
  ActivityKind.missingPuzzle,
  ActivityKind.ropeTrace,
  ActivityKind.maze,
  ActivityKind.guidedDraw,
  ActivityKind.hiddenAnimals,
];

const worlds = <WorldDefinition>[
  WorldDefinition(
    id: 'ocean',
    title: LocalizedText(
      'Первые открытия',
      'Алғашқы жаңалықтар',
      'First discoveries',
    ),
    subtitle: LocalizedText(
      'Замечай, сравнивай, соединяй',
      'Байқа, салыстыр, қос',
      'Notice, compare and connect',
    ),
    color: 0xFF398EBA,
    scene: 'whale',
    order: 0,
  ),
  WorldDefinition(
    id: 'forest',
    title: LocalizedText('Ловкие ручки', 'Епті қолдар', 'Clever little hands'),
    subtitle: LocalizedText(
      'Линии, узоры и новые пути',
      'Сызықтар, өрнектер және жаңа жолдар',
      'Lines, patterns and new paths',
    ),
    color: 0xFF638A63,
    scene: 'fox',
    order: 1,
  ),
  WorldDefinition(
    id: 'meadow',
    title: LocalizedText(
      'Творческая поляна',
      'Шығармашылық алаңы',
      'Creative meadow',
    ),
    subtitle: LocalizedText(
      'Нарисуй и найди удивительное',
      'Сурет салып, ғажайыпты тап',
      'Draw and discover something wonderful',
    ),
    color: 0xFFAB78AC,
    scene: 'butterfly',
    order: 2,
  ),
  WorldDefinition(
    id: 'safari',
    title: LocalizedText(
      'Мир вокруг',
      'Айналамыздағы әлем',
      'The world around us',
    ),
    subtitle: LocalizedText(
      'Большие идеи в маленьких деталях',
      'Кішкентай бөлшектердегі үлкен ойлар',
      'Big ideas in little details',
    ),
    color: 0xFFC37A4D,
    scene: 'lion',
    order: 3,
  ),
  WorldDefinition(
    id: 'space',
    title: LocalizedText(
      'Большое приключение',
      'Үлкен шытырман',
      'The grand adventure',
    ),
    subtitle: LocalizedText(
      'Путешествуй, твори, открывай',
      'Саяхатта, жаса, жаңалық аш',
      'Travel, create and discover',
    ),
    color: 0xFF7779B8,
    scene: 'rocket',
    order: 4,
  ),
];

const activityNames = <ActivityKind, LocalizedText>{
  ActivityKind.numberColor: LocalizedText(
    'Цвета по правилу',
    'Ереже бойынша түстер',
    'Color by a rule',
  ),
  ActivityKind.freeColor: LocalizedText(
    'Свободное творчество',
    'Еркін шығармашылық',
    'Creative studio',
  ),
  ActivityKind.oddFragment: LocalizedText(
    'Что здесь лишнее?',
    'Мұнда не артық?',
    'Which one is different?',
  ),
  ActivityKind.connectDots: LocalizedText(
    'Соедини точки',
    'Нүктелерді қос',
    'Connect the dots',
  ),
  ActivityKind.matchPairs: LocalizedText(
    'Найди пару',
    'Жұбын тап',
    'Find a pair',
  ),
  ActivityKind.patternSequence: LocalizedText(
    'Продолжи узор',
    'Өрнекті жалғастыр',
    'Continue the pattern',
  ),
  ActivityKind.missingPuzzle: LocalizedText(
    'Недостающий кусочек',
    'Жетіспейтін бөлік',
    'The missing piece',
  ),
  ActivityKind.ropeTrace: LocalizedText(
    'Распутай дорожки',
    'Шатасқан жолдарды тап',
    'Follow the winding lines',
  ),
  ActivityKind.maze: LocalizedText('Найди дорогу', 'Жолды тап', 'Find the way'),
  ActivityKind.guidedDraw: LocalizedText(
    'Рисуем по шагам',
    'Қадаммен сурет салу',
    'Draw step by step',
  ),
  ActivityKind.hiddenAnimals: LocalizedText(
    'Кто спрятался?',
    'Кім жасырынды?',
    'Who is hiding?',
  ),
};

const levels = <LevelDefinition>[
  LevelDefinition(
    id: 'v2_01',
    worldId: 'ocean',
    kind: ActivityKind.numberColor,
    scene: 'toybox',
    variant: 0,
    difficulty: 1,
    order: 0,
    illustrationAsset: 'assets/images/levels/01-toybox.png',
    voiceKey: 'v2_01',
    activityData: {
      'ruleMode': 'numbers',
      'colorSpecAsset': 'assets/content/color-toybox.json',
    },
    title: LocalizedText(
      'Игрушки и числа',
      'Ойыншықтар мен сандар',
      'Toys and numbers',
    ),
    instruction: LocalizedText(
      'Выбери краску по подсказке на игрушке.',
      'Ойыншықтағы белгіге қарап, бояу түсін таңда.',
      'Choose a paint color using the hint on the toy.',
    ),
  ),
  LevelDefinition(
    id: 'v2_02',
    worldId: 'ocean',
    kind: ActivityKind.oddFragment,
    scene: 'zebra',
    variant: 0,
    difficulty: 1,
    order: 1,
    illustrationAsset: 'assets/images/levels/02-zebra.png',
    voiceKey: 'v2_02',
    title: LocalizedText(
      'Секрет полосатой зебры',
      'Жолақты зебраның құпиясы',
      'The zebra stripe mystery',
    ),
    instruction: LocalizedText(
      'Рассмотри узоры и найди тот, который отличается.',
      'Өрнектерге қарап, өзгеше өрнекті тап.',
      'Look at the patterns and find the one that is different.',
    ),
  ),
  LevelDefinition(
    id: 'v2_03',
    worldId: 'ocean',
    kind: ActivityKind.connectDots,
    scene: 'crocodile',
    variant: 0,
    difficulty: 1,
    order: 2,
    illustrationAsset: 'assets/images/levels/03-crocodile.png',
    voiceKey: 'v2_03',
    title: LocalizedText(
      'Крокодил из точек',
      'Нүктелерден шыққан қолтырауын',
      'A dot-to-dot crocodile',
    ),
    instruction: LocalizedText(
      'Соединяй точки по порядку и открой крокодила.',
      'Нүктелерді ретімен қосып, қолтырауынды аш.',
      'Connect the dots in order to reveal the crocodile.',
    ),
  ),
  LevelDefinition(
    id: 'v2_04',
    worldId: 'ocean',
    kind: ActivityKind.matchPairs,
    scene: 'shoes',
    variant: 0,
    difficulty: 1,
    order: 3,
    illustrationAsset: 'assets/images/levels/04-shoes.png',
    voiceKey: 'v2_04',
    title: LocalizedText(
      'Каждому ботинку — пара',
      'Әр аяқкиімге — жұп',
      'A friend for every shoe',
    ),
    instruction: LocalizedText(
      'Сравни цвета и узоры. Подбери каждому ботинку пару.',
      'Түстер мен өрнектерді салыстыр. Әр аяқкиімнің жұбын тап.',
      'Compare colors and patterns. Find the matching shoe.',
    ),
  ),
  LevelDefinition(
    id: 'v2_05',
    worldId: 'forest',
    kind: ActivityKind.patternSequence,
    scene: 'balloons',
    variant: 0,
    difficulty: 1,
    order: 4,
    illustrationAsset: 'assets/images/levels/05-balloons.png',
    voiceKey: 'v2_05',
    title: LocalizedText(
      'Праздничный узор',
      'Мерекелік өрнек',
      'A celebration pattern',
    ),
    instruction: LocalizedText(
      'Посмотри, как чередуются шарики. Продолжи узор.',
      'Шарлардың кезектесуіне қара. Өрнекті жалғастыр.',
      'Look at how the balloons repeat. Continue the pattern.',
    ),
  ),
  LevelDefinition(
    id: 'v2_06',
    worldId: 'forest',
    kind: ActivityKind.missingPuzzle,
    scene: 'puppy',
    variant: 0,
    difficulty: 1,
    order: 5,
    illustrationAsset: 'assets/images/levels/06-puppy.png',
    voiceKey: 'v2_06',
    title: LocalizedText(
      'Собери портрет щенка',
      'Күшіктің суретін құрастыр',
      'Complete the puppy picture',
    ),
    instruction: LocalizedText(
      'Найди кусочек, который подходит в пустое место.',
      'Бос орынға сәйкес келетін бөлікті тап.',
      'Find the piece that fits the empty space.',
    ),
  ),
  LevelDefinition(
    id: 'v2_07',
    worldId: 'forest',
    kind: ActivityKind.ropeTrace,
    scene: 'kites',
    variant: 0,
    difficulty: 1,
    order: 6,
    illustrationAsset: 'assets/images/levels/07-kites.png',
    voiceKey: 'v2_07',
    title: LocalizedText(
      'Чей воздушный змей?',
      'Батпырауық кімдікі?',
      'Whose kite is it?',
    ),
    instruction: LocalizedText(
      'Найди начало ниточки. Проследи по ней до воздушного змея.',
      'Жіптің басын тап. Онымен батпырауыққа дейін жүр.',
      'Find the start of the string. Follow it to the kite.',
    ),
  ),
  LevelDefinition(
    id: 'v2_08',
    worldId: 'forest',
    kind: ActivityKind.maze,
    scene: 'school',
    variant: 0,
    difficulty: 1,
    order: 7,
    illustrationAsset: 'assets/images/levels/08-school.png',
    voiceKey: 'v2_08',
    title: LocalizedText(
      'Автобус идёт в школу',
      'Автобус мектепке барады',
      'The bus goes to school',
    ),
    instruction: LocalizedText(
      'Проведи автобус к школе. Объезжай места ремонта.',
      'Автобусты мектепке жеткіз. Жөндеу жерлерін айналып өт.',
      'Guide the bus to school. Go around the roadworks.',
    ),
  ),
  LevelDefinition(
    id: 'v2_09',
    worldId: 'meadow',
    kind: ActivityKind.guidedDraw,
    scene: 'duck',
    variant: 0,
    difficulty: 1,
    order: 8,
    illustrationAsset: 'assets/images/levels/09-duck.png',
    voiceKey: 'v2_09',
    title: LocalizedText(
      'Нарисуй утёнка',
      'Үйрек балапанын сал',
      'Draw a duckling',
    ),
    instruction: LocalizedText(
      'Обведи линии и добавь свои детали.',
      'Сызықтарды бастырып, өзіңше толықтыр.',
      'Trace the lines and add your own details.',
    ),
  ),
  LevelDefinition(
    id: 'v2_10',
    worldId: 'meadow',
    kind: ActivityKind.hiddenAnimals,
    scene: 'reef',
    variant: 0,
    difficulty: 1,
    order: 9,
    illustrationAsset: 'assets/images/levels/10-reef.png',
    voiceKey: 'v2_10',
    activityData: {'hiddenSpecAsset': 'assets/content/hidden-reef.json'},
    title: LocalizedText(
      'Кто спрятался на рифе?',
      'Рифте кім жасырынды?',
      'Who is hiding in the reef?',
    ),
    instruction: LocalizedText(
      'Посмотри на карточку. Найди такого же друга на большой картинке.',
      'Картаға қара. Үлкен суреттен сондай досыңды тап.',
      'Look at the card. Find the matching friend in the big picture.',
    ),
  ),
  LevelDefinition(
    id: 'v2_11',
    worldId: 'meadow',
    kind: ActivityKind.numberColor,
    scene: 'garden',
    variant: 1,
    difficulty: 2,
    order: 10,
    illustrationAsset: 'assets/images/levels/11-garden.png',
    voiceKey: 'v2_11',
    activityData: {
      'ruleMode': 'shapes',
      'colorSpecAsset': 'assets/content/color-garden.json',
    },
    title: LocalizedText(
      'Сад цветных фигур',
      'Түрлі түсті пішіндер бағы',
      'The garden of colorful shapes',
    ),
    instruction: LocalizedText(
      'Посмотри на подсказки. Выбери подходящие краски.',
      'Белгілерге қара. Сәйкес бояуларды таңда.',
      'Look at the clues. Choose the matching colors.',
    ),
  ),
  LevelDefinition(
    id: 'v2_12',
    worldId: 'meadow',
    kind: ActivityKind.oddFragment,
    scene: 'robot',
    variant: 1,
    difficulty: 2,
    order: 11,
    illustrationAsset: 'assets/images/levels/12-robot.png',
    voiceKey: 'v2_12',
    title: LocalizedText(
      'Робот заметил отличие',
      'Робот айырмашылықты байқады',
      'The robot spots a difference',
    ),
    instruction: LocalizedText(
      'Сравни детали роботов. Какая деталь не подходит к остальным?',
      'Роботтардың бөлшектерін салыстыр. Қай бөлшек өзгелерге ұқсамайды?',
      'Compare the robot parts. Which piece does not belong?',
    ),
  ),
  LevelDefinition(
    id: 'v2_13',
    worldId: 'safari',
    kind: ActivityKind.connectDots,
    scene: 'rocket',
    variant: 1,
    difficulty: 2,
    order: 12,
    illustrationAsset: 'assets/images/levels/13-rocket.png',
    voiceKey: 'v2_13',
    title: LocalizedText(
      'Ракета готова к старту',
      'Зымыран ұшуға дайын',
      'Ready for rocket launch',
    ),
    instruction: LocalizedText(
      'Соедини точки по порядку. Помоги ракете приготовиться к старту.',
      'Нүктелерді ретімен қос. Зымыранды ұшуға дайында.',
      'Connect the dots in order and get the rocket ready to launch.',
    ),
  ),
  LevelDefinition(
    id: 'v2_14',
    worldId: 'safari',
    kind: ActivityKind.matchPairs,
    scene: 'picnic',
    variant: 1,
    difficulty: 2,
    order: 13,
    illustrationAsset: 'assets/images/levels/14-picnic.png',
    voiceKey: 'v2_14',
    title: LocalizedText(
      'Пары для пикника',
      'Серуенге арналған жұптар',
      'Picnic pairs',
    ),
    instruction: LocalizedText(
      'Найди подходящие пары предметов для весёлого пикника.',
      'Көңілді серуенге қажетті заттардың жұбын тап.',
      'Find the matching pairs for a happy picnic.',
    ),
  ),
  LevelDefinition(
    id: 'v2_15',
    worldId: 'safari',
    kind: ActivityKind.patternSequence,
    scene: 'growth',
    variant: 1,
    difficulty: 2,
    order: 14,
    illustrationAsset: 'assets/images/levels/15-growth.png',
    voiceKey: 'v2_15',
    title: LocalizedText(
      'Как всё растёт',
      'Бәрі қалай өседі',
      'Watch things grow',
    ),
    instruction: LocalizedText(
      'Посмотри, как меняются картинки. Выбери картинку для пустого места.',
      'Суреттердің қалай өзгеретінін қара. Бос орынға сәйкес суретті таңда.',
      'Look at how the pictures change. Choose the picture for the empty space.',
    ),
  ),
  LevelDefinition(
    id: 'v2_16',
    worldId: 'safari',
    kind: ActivityKind.missingPuzzle,
    scene: 'fox',
    variant: 1,
    difficulty: 2,
    order: 15,
    illustrationAsset: 'assets/images/levels/16-fox.png',
    voiceKey: 'v2_16',
    title: LocalizedText(
      'Лисёнок и потерянный пазл',
      'Түлкі және жоғалған бөлік',
      'The fox and the missing puzzle',
    ),
    instruction: LocalizedText(
      'Подбери недостающий кусочек и восстанови картинку с лисёнком.',
      'Жетіспейтін бөлікті тауып, түлкінің суретін толықтыр.',
      'Find the missing piece and complete the fox picture.',
    ),
  ),
  LevelDefinition(
    id: 'v2_17',
    worldId: 'space',
    kind: ActivityKind.ropeTrace,
    scene: 'river',
    variant: 1,
    difficulty: 2,
    order: 16,
    illustrationAsset: 'assets/images/levels/17-river.png',
    voiceKey: 'v2_17',
    title: LocalizedText(
      'Извилистые речные пути',
      'Өзеннің ирек жолдары',
      'Winding river trails',
    ),
    instruction: LocalizedText(
      'Проведи лодочку от старта к отметке.',
      'Қайықты бастау нүктесінен белгіге дейін жүргіз.',
      'Guide the boat from the start to the marker.',
    ),
  ),
  LevelDefinition(
    id: 'v2_18',
    worldId: 'space',
    kind: ActivityKind.maze,
    scene: 'park',
    variant: 1,
    difficulty: 2,
    order: 17,
    illustrationAsset: 'assets/images/levels/18-park.png',
    voiceKey: 'v2_18',
    title: LocalizedText(
      'Приключение в парке',
      'Саябақтағы шытырман',
      'An adventure in the park',
    ),
    instruction: LocalizedText(
      'Найди безопасную дорожку через парк и доберись до цели.',
      'Саябақтан қауіпсіз жол тауып, мақсатқа жет.',
      'Find a safe path through the park and reach the goal.',
    ),
  ),
  LevelDefinition(
    id: 'v2_19',
    worldId: 'space',
    kind: ActivityKind.guidedDraw,
    scene: 'cat',
    variant: 1,
    difficulty: 2,
    order: 18,
    illustrationAsset: 'assets/images/levels/19-cat.png',
    voiceKey: 'v2_19',
    title: LocalizedText('Нарисуй котёнка', 'Марғауды сал', 'Draw a kitten'),
    instruction: LocalizedText(
      'Обведи линии и добавь свои детали.',
      'Сызықтарды бастырып, өзіңше толықтыр.',
      'Trace the lines and add your own details.',
    ),
  ),
  LevelDefinition(
    id: 'v2_20',
    worldId: 'space',
    kind: ActivityKind.hiddenAnimals,
    scene: 'forest',
    variant: 1,
    difficulty: 2,
    order: 19,
    illustrationAsset: 'assets/images/levels/20-forest.png',
    voiceKey: 'v2_20',
    activityData: {'hiddenSpecAsset': 'assets/content/hidden-forest.json'},
    title: LocalizedText(
      'Секреты лесной тропинки',
      'Орман соқпағының құпиялары',
      'Secrets of the forest trail',
    ),
    instruction: LocalizedText(
      'Посмотри на карточку. Найди такого же друга на лесной картинке.',
      'Картаға қара. Орман суретінен сондай досыңды тап.',
      'Look at the card. Find the matching friend in the forest picture.',
    ),
  ),
];

final levelIndex = Map<String, LevelDefinition>.unmodifiable({
  for (final level in levels) level.id: level,
});
final worldIndex = Map<String, WorldDefinition>.unmodifiable({
  for (final world in worlds) world.id: world,
});
final allLevelIndex = Map<String, LevelDefinition>.unmodifiable({
  ...legacyLevelIndex,
  ...levelIndex,
});
final allWorldIndex = Map<String, WorldDefinition>.unmodifiable({
  ...legacyWorldIndex,
  ...worldIndex,
});
final sceneNames = Map<String, LocalizedText>.unmodifiable({
  ...legacySceneNames,
  for (final level in levels) level.scene: level.title,
});

List<LevelDefinition> levelsForWorld(String worldId) =>
    levels.where((level) => level.worldId == worldId).toList(growable: false);

final stickers = List<StickerDefinition>.unmodifiable([
  for (final level in levels)
    StickerDefinition(
      id: 'sticker_${level.id}',
      levelId: level.id,
      title: level.title,
      illustrationAsset: level.illustrationAsset,
    ),
]);

const _masteryTitles = <ActivityKind, LocalizedText>{
  ActivityKind.numberColor: LocalizedText(
    'Знаток цветных правил',
    'Түс ережелерінің білгірі',
    'Color rule master',
  ),
  ActivityKind.oddFragment: LocalizedText(
    'Зоркий глаз',
    'Қырағы көз',
    'Eagle eyes',
  ),
  ActivityKind.connectDots: LocalizedText(
    'Волшебные точки',
    'Сиқырлы нүктелер',
    'Magic dots',
  ),
  ActivityKind.matchPairs: LocalizedText(
    'Лучший друг пары',
    'Жұптардың досы',
    'Pair finder',
  ),
  ActivityKind.patternSequence: LocalizedText(
    'Мастер узоров',
    'Өрнек шебері',
    'Pattern master',
  ),
  ActivityKind.missingPuzzle: LocalizedText(
    'Мастер пазлов',
    'Бөлшектер шебері',
    'Puzzle master',
  ),
  ActivityKind.ropeTrace: LocalizedText(
    'Верный след',
    'Дұрыс із',
    'Trail finder',
  ),
  ActivityKind.maze: LocalizedText(
    'Смелый путешественник',
    'Батыл саяхатшы',
    'Brave explorer',
  ),
  ActivityKind.guidedDraw: LocalizedText(
    'Юный художник',
    'Жас суретші',
    'Young artist',
  ),
  ActivityKind.hiddenAnimals: LocalizedText(
    'Друг леса и моря',
    'Орман мен теңіздің досы',
    'Friend of land and sea',
  ),
};

final achievements = List<AchievementDefinition>.unmodifiable([
  const AchievementDefinition(
    id: 'first_step',
    title: LocalizedText(
      'Первое открытие',
      'Алғашқы жаңалық',
      'First discovery',
    ),
    description: LocalizedText(
      'Заверши первое задание',
      'Алғашқы тапсырманы аяқта',
      'Complete your first activity',
    ),
    symbol: 'spark',
    target: 1,
  ),
  const AchievementDefinition(
    id: 'five_discoveries',
    title: LocalizedText('Пять открытий', 'Бес жаңалық', 'Five discoveries'),
    description: LocalizedText(
      'Заверши 5 разных заданий',
      '5 түрлі тапсырманы аяқта',
      'Complete 5 different activities',
    ),
    symbol: 'compass',
    target: 5,
  ),
  const AchievementDefinition(
    id: 'halfway',
    title: LocalizedText('Уже десять!', 'Міне, он болды!', 'Ten discoveries!'),
    description: LocalizedText(
      'Заверши 10 разных заданий',
      '10 түрлі тапсырманы аяқта',
      'Complete 10 different activities',
    ),
    symbol: 'flag',
    target: 10,
  ),
  const AchievementDefinition(
    id: 'all_twenty',
    title: LocalizedText(
      'Большая коллекция',
      'Үлкен жинақ',
      'The whole collection',
    ),
    description: LocalizedText(
      'Открой все 20 наклеек',
      'Барлық 20 жапсырманы аш',
      'Unlock all 20 stickers',
    ),
    symbol: 'crown',
    target: 20,
  ),
  for (final kind in activeActivityKinds)
    AchievementDefinition(
      id: 'mastery_${kind.name}',
      title: _masteryTitles[kind]!,
      description: const LocalizedText(
        'Заверши оба задания этого вида',
        'Осы түрдегі екі тапсырманы аяқта',
        'Complete both activities of this kind',
      ),
      symbol: switch (kind) {
        ActivityKind.numberColor => 'palette',
        ActivityKind.guidedDraw => 'pencil',
        ActivityKind.maze || ActivityKind.ropeTrace => 'route',
        ActivityKind.hiddenAnimals || ActivityKind.oddFragment => 'search',
        _ => 'spark',
      },
      target: 2,
      kind: kind,
    ),
]);

/// Permanent goals remain reachable within the finite 20-level collection.
final missions = List<MissionDefinition>.unmodifiable([
  for (final kind in activeActivityKinds)
    for (final target in [1, 2])
      MissionDefinition(
        id: '${kind.name}_mission_$target',
        kind: kind,
        target: target,
        title: LocalizedText(
          '${activityNames[kind]!.ru} · $target',
          '${activityNames[kind]!.kk} · $target',
          '${activityNames[kind]!.en} · $target',
        ),
      ),
]);

/// Stable across launches and platforms. Replays can satisfy a new day's quest.
List<DailyQuestDefinition> dailyQuestsFor(DateTime day) {
  final dayKey = calendarDayKey(day);
  final seed = day.year * 372 + day.month * 31 + day.day;
  return List.unmodifiable([
    for (final offset in [0, 3, 6])
      DailyQuestDefinition(
        id: 'v${contentVersion}_${dayKey}_${activeActivityKinds[(seed + offset) % activeActivityKinds.length].name}',
        dayKey: dayKey,
        kind: activeActivityKinds[(seed + offset) % activeActivityKinds.length],
        title:
            activityNames[activeActivityKinds[(seed + offset) %
                activeActivityKinds.length]]!,
      ),
  ]);
}
