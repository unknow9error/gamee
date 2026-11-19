import '../domain/models.dart';

// Never use ActivityKind.values here: later content adds more engines.
const _legacyActivityKinds = <ActivityKind>[
  ActivityKind.numberColor,
  ActivityKind.freeColor,
  ActivityKind.maze,
  ActivityKind.guidedDraw,
  ActivityKind.hiddenAnimals,
];

/// Frozen v1 metadata. Never derive this archive from the active catalog.
/// IDs, copy and scene parameters identify saved work made before schema v2.
const legacyWorlds = <WorldDefinition>[
  WorldDefinition(
    id: 'ocean',
    title: LocalizedText('Океан чудес', 'Ғажайып мұхит', 'Wonder ocean'),
    subtitle: LocalizedText(
      'Ныряем за вдохновением',
      'Шабыт іздеп сүңгиміз',
      'Dive into imagination',
    ),
    color: 0xFF398EBA,
    scene: 'whale',
    order: 0,
  ),
  WorldDefinition(
    id: 'forest',
    title: LocalizedText('Лесные истории', 'Орман хикаялары', 'Forest stories'),
    subtitle: LocalizedText(
      'Подружись с лесом',
      'Орманмен достас',
      'Meet your woodland friends',
    ),
    color: 0xFF638A63,
    scene: 'fox',
    order: 1,
  ),
  WorldDefinition(
    id: 'meadow',
    title: LocalizedText('Цветочная поляна', 'Гүлді алаң', 'Blossom meadow'),
    subtitle: LocalizedText(
      'Маленькие открытия каждый день',
      'Күн сайын кішкентай жаңалық',
      'Little things, big discoveries',
    ),
    color: 0xFFAB78AC,
    scene: 'butterfly',
    order: 2,
  ),
  WorldDefinition(
    id: 'farm',
    title: LocalizedText('Солнечная ферма', 'Шуақты ферма', 'Sunny farm'),
    subtitle: LocalizedText(
      'Уютные приключения',
      'Жайлы шытырман оқиғалар',
      'A happy place to explore',
    ),
    color: 0xFFD7A342,
    scene: 'duck',
    order: 3,
  ),
  WorldDefinition(
    id: 'safari',
    title: LocalizedText('Большое сафари', 'Үлкен сафари', 'Grand safari'),
    subtitle: LocalizedText(
      'Вперёд, навстречу друзьям',
      'Достарға қарай алға',
      'Adventure with new friends',
    ),
    color: 0xFFC37A4D,
    scene: 'giraffe',
    order: 4,
  ),
  WorldDefinition(
    id: 'space',
    title: LocalizedText(
      'Звёздная мастерская',
      'Жұлдызды шеберхана',
      'Starlight studio',
    ),
    subtitle: LocalizedText(
      'Воображение без границ',
      'Қиялға шек жоқ',
      'Imagine beyond the stars',
    ),
    color: 0xFF7779B8,
    scene: 'rocket',
    order: 5,
  ),
];

const _worldScenes = <String, List<String>>{
  'ocean': ['whale', 'dolphin', 'turtle', 'whale'],
  'forest': ['fox', 'owl', 'rabbit', 'fox'],
  'meadow': ['butterfly', 'rabbit', 'turtle', 'butterfly'],
  'farm': ['duck', 'cat', 'rabbit', 'duck'],
  'safari': ['giraffe', 'lion', 'turtle', 'giraffe'],
  'space': ['rocket', 'owl', 'cat', 'rocket'],
};

const legacySceneNames = <String, LocalizedText>{
  'whale': LocalizedText('Кит', 'Кит', 'Whale'),
  'dolphin': LocalizedText('Дельфин', 'Дельфин', 'Dolphin'),
  'duck': LocalizedText('Утёнок', 'Үйрек балапаны', 'Duckling'),
  'turtle': LocalizedText('Черепашка', 'Тасбақа', 'Turtle'),
  'fox': LocalizedText('Лисёнок', 'Түлкі', 'Little fox'),
  'rabbit': LocalizedText('Зайчонок', 'Қоян', 'Bunny'),
  'cat': LocalizedText('Котёнок', 'Марғау', 'Kitten'),
  'butterfly': LocalizedText('Бабочка', 'Көбелек', 'Butterfly'),
  'lion': LocalizedText('Львёнок', 'Арыстан', 'Lion cub'),
  'giraffe': LocalizedText('Жираф', 'Керік', 'Giraffe'),
  'rocket': LocalizedText('Ракета', 'Зымыран', 'Rocket'),
  'owl': LocalizedText('Совёнок', 'Жапалақ', 'Little owl'),
};

const legacyActivityNames = <ActivityKind, LocalizedText>{
  ActivityKind.numberColor: LocalizedText(
    'Цвета и числа',
    'Түстер мен сандар',
    'Colors & numbers',
  ),
  ActivityKind.freeColor: LocalizedText(
    'Мастерская цвета',
    'Түс шеберханасы',
    'Color studio',
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

const _chapterNames = <LocalizedText>[
  LocalizedText('Первое открытие', 'Алғашқы жаңалық', 'First discovery'),
  LocalizedText('Новые секреты', 'Жаңа құпиялар', 'New secrets'),
  LocalizedText('Смелое приключение', 'Батыл саяхат', 'Brave adventure'),
  LocalizedText('Большое мастерство', 'Үлкен шеберлік', 'Creative master'),
];

LocalizedText _title(ActivityKind kind, String scene, int chapter) {
  final animal = legacySceneNames[scene]!;
  final suffix = _chapterNames[chapter];
  if (kind == ActivityKind.maze) {
    return LocalizedText(
      'Дорога к друзьям · ${chapter + 1}',
      'Достарға апарар жол · ${chapter + 1}',
      'The road to friends · ${chapter + 1}',
    );
  }
  if (kind == ActivityKind.hiddenAnimals) {
    return LocalizedText(
      'Секреты фигур · ${chapter + 1}',
      'Пішіндер құпиясы · ${chapter + 1}',
      'Shape detectives · ${chapter + 1}',
    );
  }
  return LocalizedText(
    '${animal.ru}: ${suffix.ru.toLowerCase()}',
    '${animal.kk}: ${suffix.kk.toLowerCase()}',
    '${animal.en}: ${suffix.en.toLowerCase()}',
  );
}

const _legacyInstructions = <ActivityKind, LocalizedText>{
  ActivityKind.numberColor: LocalizedText(
    'Выбери цвет с нужным числом и коснись подходящей области. Прояви спрятанную картинку!',
    'Керекті саны бар түсті таңдап, сәйкес бөлікке түрт. Жасырын суретті аш!',
    'Pick a numbered color, then tap the matching area. Reveal the hidden picture!',
  ),
  ActivityKind.freeColor: LocalizedText(
    'Выбери любимые цвета. Закрашивай области или рисуй кистью — здесь ты художник!',
    'Сүйікті түстеріңді таңда. Бөліктерді боя немесе қылқаламмен сурет сал — сен суретшісің!',
    'Choose your favorite colors. Fill the shapes or use the brush. You are the artist!',
  ),
  ActivityKind.maze: LocalizedText(
    'Проведи друга по дороге к цели. Держись дорожки и обходи места ремонта.',
    'Досыңды жолмен мақсатқа жеткіз. Жолдан шықпай, жөндеу жерлерін айналып өт.',
    'Guide your friend along the road to the goal. Stay on the path and avoid roadworks.',
  ),
  ActivityKind.guidedDraw: LocalizedText(
    'Обводи подсвеченные линии по порядку. Шаг за шагом получится твой рисунок!',
    'Жарқыраған сызықтарды ретімен бастыр. Қадам сайын өз суретің пайда болады!',
    'Trace the highlighted lines in order. Build your own drawing, one step at a time!',
  ),
  ActivityKind.hiddenAnimals: LocalizedText(
    'Внимательно рассмотри фигуры. Найди спрятанных друзей и раскрась их части.',
    'Пішіндерге мұқият қара. Жасырын достарды тауып, олардың бөліктерін боя.',
    'Look closely at the shapes. Find the hidden friends and color their pieces.',
  ),
};

LocalizedText _instruction(ActivityKind kind, int chapter) =>
    _legacyInstructions[kind] ??
    (throw ArgumentError.value(kind, 'kind', 'Not a v1 activity'));

/// Four chapters per world. Engines consume both [LevelDefinition.variant] and
/// [LevelDefinition.difficulty]; these are 120 exercises over 12 art scenes,
/// not a claim of 120 separately illustrated pictures.
final legacyLevels = List<LevelDefinition>.unmodifiable([
  for (final world in legacyWorlds)
    for (var chapter = 0; chapter < 4; chapter++)
      for (final kind in _legacyActivityKinds)
        LevelDefinition(
          id: '${world.id}_${kind.name}_${chapter + 1}',
          worldId: world.id,
          kind: kind,
          scene: _worldScenes[world.id]![chapter],
          variant: chapter,
          difficulty: chapter + 1,
          title: _title(kind, _worldScenes[world.id]![chapter], chapter),
          instruction: _instruction(kind, chapter),
          order:
              chapter * _legacyActivityKinds.length +
              _legacyActivityKinds.indexOf(kind),
        ),
]);

final legacyLevelIndex = Map<String, LevelDefinition>.unmodifiable({
  for (final level in legacyLevels) level.id: level,
});

List<LevelDefinition> legacyLevelsForWorld(String worldId) => legacyLevels
    .where((level) => level.worldId == worldId)
    .toList(growable: false);

final legacyWorldIndex = Map<String, WorldDefinition>.unmodifiable({
  for (final world in legacyWorlds) world.id: world,
});
