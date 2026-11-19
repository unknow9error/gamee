import '../../../domain/models.dart';

/// Manually checked object bounds in the original 1254 × 1254 ImageGen art.
/// A pair is defined by subject and pattern, never by pixel equality: the
/// generated counterparts have deliberately different poses and proportions.
class MatchingCrop {
  const MatchingCrop(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
  static const sourceSize = 1254.0;
}

class MatchingCard {
  const MatchingCard({
    required this.id,
    required this.pairId,
    required this.crop,
    required this.name,
  });
  final String id;
  final String pairId;
  final MatchingCrop crop;
  final LocalizedText name;
}

class MatchingLayout {
  const MatchingLayout({
    required this.levelId,
    required this.ageBand,
    required this.revision,
    required this.assetPath,
    required this.cards,
  });
  final String levelId;
  final AgeBand ageBand;
  final String revision;
  final String assetPath;
  final List<MatchingCard> cards;
  bool get memoryMode => ageBand == AgeBand.advanced;
  Set<String> get pairIds => cards.map((card) => card.pairId).toSet();
  MatchingCard? cardById(String? id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }
}

MatchingLayout matchingLayoutFor(LevelDefinition level, int childAge) {
  final band = AgeBand.fromAge(childAge);
  if (level.scene != 'shoes' && level.scene != 'picnic') {
    throw ArgumentError.value(level.scene, 'scene', 'Unknown matching artwork');
  }
  final picnic = level.scene == 'picnic';
  final source = picnic ? _picnicCards : _shoeCards;
  final pairs = switch (band) {
    AgeBand.preschool => childAge == 3 ? 2 : 3,
    AgeBand.primary => 4,
    AgeBand.advanced => 6,
  };
  final activePairs = source
      .map((card) => card.pairId)
      .toSet()
      .take(pairs)
      .toSet();
  // A stable dispersed order preserves spatial memory across resume/rotation.
  // Each source list contains the first copy of every class, then its second.
  const order = [0, 7, 3, 8, 4, 11, 2, 9, 5, 6, 1, 10];
  final cards = order
      .map((index) => source[index])
      .where((card) => activePairs.contains(card.pairId))
      .toList();
  return MatchingLayout(
    levelId: level.id,
    ageBand: band,
    revision: '${picnic ? 'picnic' : 'shoes'}-roi-1-$pairs',
    assetPath: picnic
        ? 'assets/images/levels/14-picnic.png'
        : 'assets/images/levels/04-shoes.png',
    cards: List.unmodifiable(cards),
  );
}

const _shoeCards = <MatchingCard>[
  MatchingCard(
    id: 'star-a',
    pairId: 'star',
    crop: MatchingCrop(190, 165, 265, 180),
    name: LocalizedText(
      'Красный кед со звездой',
      'Жұлдызды қызыл кеды',
      'Red star sneaker',
    ),
  ),
  MatchingCard(
    id: 'boot-a',
    pairId: 'boot',
    crop: MatchingCrop(535, 100, 225, 250),
    name: LocalizedText(
      'Сапог в жёлтый горошек',
      'Сары нүктелі етік',
      'Yellow-dotted boot',
    ),
  ),
  MatchingCard(
    id: 'sandal-a',
    pairId: 'sandal',
    crop: MatchingCrop(835, 150, 270, 205),
    name: LocalizedText(
      'Сиреневая сандалия с ромашкой',
      'Түймедақты күлгін сандал',
      'Lilac daisy sandal',
    ),
  ),
  MatchingCard(
    id: 'slipper-a',
    pairId: 'slipper',
    crop: MatchingCrop(155, 400, 280, 180),
    name: LocalizedText(
      'Жёлтый тапочек с зелёной полоской',
      'Жасыл жолақты сары тәпішке',
      'Yellow slipper with green stripe',
    ),
  ),
  MatchingCard(
    id: 'zigzag-a',
    pairId: 'zigzag',
    crop: MatchingCrop(500, 408, 270, 175),
    name: LocalizedText(
      'Светлый кед с бирюзовым зигзагом',
      'Көгілдір иректі ашық кеды',
      'Cream sneaker with teal zigzag',
    ),
  ),
  MatchingCard(
    id: 'lace-a',
    pairId: 'lace',
    crop: MatchingCrop(835, 395, 280, 185),
    name: LocalizedText(
      'Зелёный кед с оранжевыми шнурками',
      'Қызғылт сары баулы жасыл кеды',
      'Green sneaker with orange laces',
    ),
  ),
  MatchingCard(
    id: 'star-b',
    pairId: 'star',
    crop: MatchingCrop(830, 642, 270, 185),
    name: LocalizedText(
      'Красный кед со звездой',
      'Жұлдызды қызыл кеды',
      'Red star sneaker',
    ),
  ),
  MatchingCard(
    id: 'boot-b',
    pairId: 'boot',
    crop: MatchingCrop(165, 585, 225, 250),
    name: LocalizedText(
      'Сапог в жёлтый горошек',
      'Сары нүктелі етік',
      'Yellow-dotted boot',
    ),
  ),
  MatchingCard(
    id: 'sandal-b',
    pairId: 'sandal',
    crop: MatchingCrop(480, 635, 275, 205),
    name: LocalizedText(
      'Сиреневая сандалия с ромашкой',
      'Түймедақты күлгін сандал',
      'Lilac daisy sandal',
    ),
  ),
  MatchingCard(
    id: 'slipper-b',
    pairId: 'slipper',
    crop: MatchingCrop(480, 892, 280, 180),
    name: LocalizedText(
      'Жёлтый тапочек с зелёной полоской',
      'Жасыл жолақты сары тәпішке',
      'Yellow slipper with green stripe',
    ),
  ),
  MatchingCard(
    id: 'zigzag-b',
    pairId: 'zigzag',
    crop: MatchingCrop(830, 903, 280, 175),
    name: LocalizedText(
      'Светлый кед с бирюзовым зигзагом',
      'Көгілдір иректі ашық кеды',
      'Cream sneaker with teal zigzag',
    ),
  ),
  MatchingCard(
    id: 'lace-b',
    pairId: 'lace',
    crop: MatchingCrop(145, 890, 280, 185),
    name: LocalizedText(
      'Зелёный кед с оранжевыми шнурками',
      'Қызғылт сары баулы жасыл кеды',
      'Green sneaker with orange laces',
    ),
  ),
];

const _picnicCards = <MatchingCard>[
  MatchingCard(
    id: 'apple-a',
    pairId: 'apple',
    crop: MatchingCrop(115, 195, 220, 240),
    name: LocalizedText('Красное яблоко', 'Қызыл алма', 'Red apple'),
  ),
  MatchingCard(
    id: 'banana-a',
    pairId: 'banana',
    crop: MatchingCrop(895, 185, 245, 250),
    name: LocalizedText('Жёлтый банан', 'Сары банан', 'Yellow banana'),
  ),
  MatchingCard(
    id: 'grapes-a',
    pairId: 'grapes',
    crop: MatchingCrop(655, 185, 215, 255),
    name: LocalizedText('Фиолетовый виноград', 'Күлгін жүзім', 'Purple grapes'),
  ),
  MatchingCard(
    id: 'sandwich-a',
    pairId: 'sandwich',
    crop: MatchingCrop(365, 215, 245, 220),
    name: LocalizedText(
      'Квадратный сэндвич',
      'Төртбұрышты сэндвич',
      'Square sandwich',
    ),
  ),
  MatchingCard(
    id: 'melon-a',
    pairId: 'melon',
    crop: MatchingCrop(105, 500, 240, 235),
    name: LocalizedText(
      'Треугольный ломтик арбуза',
      'Үшбұрышты қарбыз тілімі',
      'Triangular watermelon slice',
    ),
  ),
  MatchingCard(
    id: 'berries-a',
    pairId: 'berries',
    crop: MatchingCrop(370, 530, 245, 215),
    name: LocalizedText(
      'Клубника в голубой миске',
      'Көк тостағандағы құлпынай',
      'Strawberries in a blue bowl',
    ),
  ),
  MatchingCard(
    id: 'apple-b',
    pairId: 'apple',
    crop: MatchingCrop(655, 490, 230, 250),
    name: LocalizedText('Красное яблоко', 'Қызыл алма', 'Red apple'),
  ),
  MatchingCard(
    id: 'banana-b',
    pairId: 'banana',
    crop: MatchingCrop(100, 792, 245, 250),
    name: LocalizedText('Жёлтый банан', 'Сары банан', 'Yellow banana'),
  ),
  MatchingCard(
    id: 'grapes-b',
    pairId: 'grapes',
    crop: MatchingCrop(930, 480, 205, 265),
    name: LocalizedText('Фиолетовый виноград', 'Күлгін жүзім', 'Purple grapes'),
  ),
  MatchingCard(
    id: 'sandwich-b',
    pairId: 'sandwich',
    crop: MatchingCrop(370, 810, 240, 230),
    name: LocalizedText(
      'Квадратный сэндвич',
      'Төртбұрышты сэндвич',
      'Square sandwich',
    ),
  ),
  MatchingCard(
    id: 'melon-b',
    pairId: 'melon',
    crop: MatchingCrop(915, 795, 245, 240),
    name: LocalizedText(
      'Треугольный ломтик арбуза',
      'Үшбұрышты қарбыз тілімі',
      'Triangular watermelon slice',
    ),
  ),
  MatchingCard(
    id: 'berries-b',
    pairId: 'berries',
    crop: MatchingCrop(650, 830, 245, 210),
    name: LocalizedText(
      'Клубника в голубой миске',
      'Көк тостағандағы құлпынай',
      'Strawberries in a blue bowl',
    ),
  ),
];
