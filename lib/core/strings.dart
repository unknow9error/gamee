import '../domain/models.dart';

String textFor(String language, String ru, String kk, String en) =>
    LocalizedText(ru, kk, en).resolve(language);

String ageLabel(int age, String language) => textFor(
  language,
  '$age ${age == 3 || age == 4 ? 'года' : 'лет'}',
  '$age жас',
  'Age $age',
);

String russianPlural(int count, String one, String few, String many) {
  final value = count.abs();
  final lastTwo = value % 100;
  if (lastTwo >= 11 && lastTwo <= 19) {
    return many;
  }
  return switch (value % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}

String activityName(ActivityKind kind, String language) => switch (kind) {
  ActivityKind.numberColor => textFor(
    language,
    'Цвета по правилу',
    'Ереже бойынша түстер',
    'Color by a rule',
  ),
  ActivityKind.freeColor => textFor(
    language,
    'Мастерская цвета',
    'Түстер шеберханасы',
    'Color studio',
  ),
  ActivityKind.maze => textFor(
    language,
    'Найди дорогу',
    'Жолды тап',
    'Find the way',
  ),
  ActivityKind.guidedDraw => textFor(
    language,
    'Рисуем по шагам',
    'Қадамдап сурет салу',
    'Draw step by step',
  ),
  ActivityKind.hiddenAnimals => textFor(
    language,
    'Кто спрятался?',
    'Кім жасырынды?',
    'Who is hiding?',
  ),
  ActivityKind.oddFragment => textFor(
    language,
    'Найди лишнее',
    'Артығын тап',
    'Find the odd one',
  ),
  ActivityKind.connectDots => textFor(
    language,
    'Соедини точки',
    'Нүктелерді қос',
    'Connect the dots',
  ),
  ActivityKind.matchPairs => textFor(
    language,
    'Найди пару',
    'Жұбын тап',
    'Find the pairs',
  ),
  ActivityKind.patternSequence => textFor(
    language,
    'Узоры и порядок',
    'Өрнектер және реттілік',
    'Patterns and order',
  ),
  ActivityKind.missingPuzzle => textFor(
    language,
    'Собери картинку',
    'Суретті құрастыр',
    'Complete the picture',
  ),
  ActivityKind.ropeTrace => textFor(
    language,
    'Весёлые дорожки',
    'Көңілді жолдар',
    'Playful trails',
  ),
};
