enum ActivityKind {
  numberColor,
  freeColor,
  maze,
  guidedDraw,
  hiddenAnimals,
  oddFragment,
  connectDots,
  matchPairs,
  patternSequence,
  missingPuzzle,
  ropeTrace,
}

enum AgeBand {
  preschool(3, 5),
  primary(6, 8),
  advanced(9, 11);

  const AgeBand(this.minimumAge, this.maximumAge);
  final int minimumAge;
  final int maximumAge;

  static AgeBand fromAge(int age) {
    if (age < 3 || age > 11) {
      throw RangeError.range(age, 3, 11, 'age');
    }
    return values.firstWhere((band) => age <= band.maximumAge);
  }
}

class LocalizedText {
  const LocalizedText(this.ru, this.kk, this.en);
  final String ru;
  final String kk;
  final String en;
  String resolve(String language) => switch (language) {
    'kk' => kk,
    'en' => en,
    _ => ru,
  };
}

class WorldDefinition {
  const WorldDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.scene,
    required this.order,
  });
  final String id;
  final LocalizedText title;
  final LocalizedText subtitle;
  final int color;
  final String scene;
  final int order;
}

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.worldId,
    required this.kind,
    required this.scene,
    required this.variant,
    required this.difficulty,
    required this.title,
    required this.instruction,
    required this.order,
    this.illustrationAsset,
    this.voiceKey,
    this.activityData = const {},
  });
  final String id;
  final String worldId;
  final ActivityKind kind;
  final String scene;
  final int variant;
  final int difficulty;
  final LocalizedText title;
  final LocalizedText instruction;
  final int order;
  final String? illustrationAsset;
  final String? voiceKey;
  final Map<String, dynamic> activityData;
}

class LevelProgress {
  const LevelProgress({
    required this.stars,
    required this.completedAt,
    this.attempts = 1,
  });
  final int stars;
  final DateTime completedAt;
  final int attempts;
  Map<String, dynamic> toJson() => {
    'stars': stars,
    'completedAt': completedAt.toIso8601String(),
    'attempts': attempts,
  };
  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
    stars: (json['stars'] as num).toInt().clamp(1, 3),
    completedAt: DateTime.parse(json['completedAt'] as String),
    attempts: (json['attempts'] as num?)?.toInt() ?? 1,
  );
}

class Artwork {
  const Artwork({
    required this.levelId,
    required this.createdAt,
    required this.data,
    this.versionId,
  });
  final String levelId;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final String? versionId;
  String get id =>
      versionId ?? 'art_${levelId}_${createdAt.microsecondsSinceEpoch}';
  Map<String, dynamic> toJson() => {
    'levelId': levelId,
    'createdAt': createdAt.toIso8601String(),
    'data': data,
    'id': id,
  };
  factory Artwork.fromJson(Map<String, dynamic> json) => Artwork(
    levelId: json['levelId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    data: Map<String, dynamic>.from(json['data'] as Map),
    versionId: json['id'] is String && (json['id'] as String).isNotEmpty
        ? json['id'] as String
        : null,
  );
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.symbol,
    required this.target,
    this.kind,
  });
  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final String symbol;
  final int target;
  final ActivityKind? kind;
}

class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.title,
    required this.kind,
    required this.target,
  });
  final String id;
  final LocalizedText title;
  final ActivityKind kind;
  final int target;
}

class CompletionReward {
  const CompletionReward({
    required this.stars,
    required this.newAchievements,
    required this.firstCompletion,
    this.newSticker,
    this.completedDailyQuests = const [],
  });
  final int stars;
  final List<AchievementDefinition> newAchievements;
  final bool firstCompletion;
  final StickerDefinition? newSticker;
  final List<DailyQuestDefinition> completedDailyQuests;
}

class StickerDefinition {
  const StickerDefinition({
    required this.id,
    required this.levelId,
    required this.title,
    this.illustrationAsset,
  });
  final String id;
  final String levelId;
  final LocalizedText title;
  final String? illustrationAsset;
}

class DailyQuestDefinition extends MissionDefinition {
  const DailyQuestDefinition({
    required super.id,
    required super.title,
    required super.kind,
    required this.dayKey,
    super.target = 1,
  });
  final String dayKey;
}

class PlayDay {
  const PlayDay({
    required this.date,
    required this.completedActivities,
    required this.isToday,
  });
  final DateTime date;
  final int completedActivities;
  final bool isToday;
  bool get played => completedActivities > 0;
}
