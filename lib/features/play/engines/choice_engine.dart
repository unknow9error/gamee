import 'dart:ui';

import '../../../domain/models.dart';

/// A view of the original illustration. Coordinates are normalized to the image.
class PicturePiece {
  const PicturePiece(this.crop, {this.turns = 0, this.mirrored = false});
  final Rect crop;
  final int turns;
  final bool mirrored;

  PicturePiece transform({int? turns, bool? mirrored}) => PicturePiece(
    crop,
    turns: turns ?? this.turns,
    mirrored: mirrored ?? this.mirrored,
  );

  bool samePicture(PicturePiece other) =>
      crop == other.crop &&
      turns % 4 == other.turns % 4 &&
      mirrored == other.mirrored;
}

enum ChoiceRule { missingPiece, oddPiece, repeatingPattern, growthOrder }

class PictureOption {
  const PictureOption(this.id, this.piece, {this.reference = 0});
  final String id;
  final PicturePiece piece;
  final int reference;
}

class PictureStage {
  PictureStage.match({
    required this.id,
    required this.rule,
    required this.options,
    required PicturePiece expected,
    this.target = 0,
    this.sequence = const [],
    this.activeIndex = -1,
    this.references = const [],
    this.referenceTurns = 0,
  }) {
    final matches = options
        .where((o) => o.piece.samePicture(expected))
        .toList();
    if (matches.length != 1) {
      throw ArgumentError('A picture match must have exactly one answer: $id');
    }
    answer = matches.single.id;
  }

  PictureStage.odd({
    required this.id,
    required this.options,
    required this.references,
    this.referenceTurns = 0,
  }) : rule = ChoiceRule.oddPiece,
       target = 0,
       sequence = const [],
       activeIndex = -1 {
    final mismatches = options
        .where(
          (o) => !o.piece.samePicture(
            references[o.reference].transform(turns: referenceTurns),
          ),
        )
        .toList();
    if (mismatches.length != 1) {
      throw ArgumentError('Exactly one fragment must differ: $id');
    }
    answer = mismatches.single.id;
  }

  final String id;
  final ChoiceRule rule;
  final List<PictureOption> options;
  final List<PicturePiece> references;
  final List<PicturePiece?> sequence;
  final int referenceTurns;
  final int activeIndex;
  final int target;
  late final String answer;
  PictureOption get answerOption => options.firstWhere((o) => o.id == answer);
}

/// Indexing the period is the rule: the answer is never an authored option index.
class PicturePattern {
  const PicturePattern(this.period);
  final List<PicturePiece> period;
  PicturePiece at(int position) => period[position % period.length];
}

class PictureChallenge {
  const PictureChallenge({
    required this.levelId,
    required this.scene,
    required this.childAge,
    required this.asset,
    required this.ageBand,
    required this.revision,
    required this.stages,
    this.holes = const [],
  });
  final String levelId;
  final String scene;
  final int childAge;
  final String asset;
  final AgeBand ageBand;
  final int revision;
  final List<PictureStage> stages;
  final List<PicturePiece> holes;
}

/// Progress is a checked, contiguous prefix of answers, bounded by the layout.
class ChoiceEngine {
  ChoiceEngine(this.challenge, {Map<String, dynamic>? initialData}) {
    if (initialData == null ||
        initialData['version'] != 3 ||
        initialData['kind'] != 'pictureChoice' ||
        initialData['levelId'] != challenge.levelId ||
        initialData['scene'] != challenge.scene ||
        initialData['childAge'] != challenge.childAge ||
        initialData['asset'] != challenge.asset ||
        initialData['ageBand'] != challenge.ageBand.name ||
        initialData['layoutRevision'] != challenge.revision) {
      return;
    }
    final raw = initialData['answers'];
    final rawStage = initialData['stage'];
    if (raw is! List ||
        raw.length > challenge.stages.length ||
        rawStage is! int ||
        rawStage != raw.length) {
      return;
    }
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] is! String || raw[i] != challenge.stages[i].answer) return;
    }
    _answers.addAll(raw.cast<String>());
  }

  final PictureChallenge challenge;
  final List<String> _answers = [];
  int get stageIndex => _answers.length;
  bool get complete => stageIndex == challenge.stages.length;
  PictureStage get stage =>
      challenge.stages[complete ? challenge.stages.length - 1 : stageIndex];
  List<String> get answers => List.unmodifiable(_answers);

  bool choose(String optionId) {
    if (complete || optionId != stage.answer) return false;
    _answers.add(optionId);
    return true;
  }

  Map<String, dynamic> toJson() => {
    'version': 3,
    'kind': 'pictureChoice',
    'levelId': challenge.levelId,
    'scene': challenge.scene,
    'childAge': challenge.childAge,
    'asset': challenge.asset,
    'ageBand': challenge.ageBand.name,
    'layoutRevision': challenge.revision,
    'stage': stageIndex,
    'answers': List<String>.of(_answers),
    'illustrationAsset': challenge.asset,
  };
}
