import 'dart:ui';

import '../../../domain/models.dart';
import '../engines/choice_engine.dart';

/// Revision 1 coordinates were checked against the shipped ImageGen artwork.
/// Crops preserve the original pixels; no replacement drawing is used as art.
PictureChallenge choiceChallenge(
  LevelDefinition level,
  AgeBand age, {
  int? childAge,
}) {
  final scene = level.scene;
  final expectedKind = switch (scene) {
    'zebra' || 'robot' => ActivityKind.oddFragment,
    'puppy' || 'fox' => ActivityKind.missingPuzzle,
    'balloons' || 'growth' => ActivityKind.patternSequence,
    _ => throw ArgumentError('No checked picture layout for $scene'),
  };
  if (level.kind != expectedKind) {
    throw ArgumentError(
      'Picture layout and activity kind do not match: $scene',
    );
  }
  final asset =
      level.illustrationAsset ??
      'assets/images/levels/${switch (scene) {
        'zebra' => '02-zebra',
        'robot' => '12-robot',
        'balloons' => '05-balloons',
        'growth' => '15-growth',
        'puppy' => '06-puppy',
        'fox' => '16-fox',
        _ => throw ArgumentError('No checked picture layout for $scene'),
      }}.png';
  final stages = <PictureStage>[];
  final holes = <PicturePiece>[];
  if (level.kind == ActivityKind.missingPuzzle) {
    final source = scene == 'puppy' ? _puppy : _fox;
    final count = switch (age) {
      AgeBand.preschool => 1,
      AgeBand.primary => 2,
      AgeBand.advanced => 4,
    };
    holes.addAll(source.take(count));
    for (var i = 0; i < count; i++) {
      final correct = holes[i];
      final candidates = <PicturePiece>[
        correct,
        source[(i + 1) % source.length],
        source[(i + 2) % source.length],
        age == AgeBand.advanced
            ? correct.transform(turns: (i % 3) + 1)
            : source[(i + 3) % source.length],
      ];
      stages.add(
        PictureStage.match(
          id: 'hole-$i',
          rule: ChoiceRule.missingPiece,
          target: i,
          expected: correct,
          options: _options(candidates, i + age.index),
        ),
      );
    }
  } else if (level.kind == ActivityKind.oddFragment) {
    final source = scene == 'zebra' ? _zebra : _robot;
    final count = age == AgeBand.preschool ? 4 : 6;
    for (var s = 0; s <= age.index; s++) {
      final references = age == AgeBand.preschool
          ? <PicturePiece>[source[s]]
          : source;
      final turn = age == AgeBand.advanced ? (s % 3) + 1 : 0;
      final oddIndex = (s * 2 + 1) % count;
      final options = <PictureOption>[];
      for (var i = 0; i < count; i++) {
        final ref = i % references.length;
        options.add(
          PictureOption(
            'fragment-$i',
            references[ref].transform(turns: turn, mirrored: i == oddIndex),
            reference: ref,
          ),
        );
      }
      stages.add(
        PictureStage.odd(
          id: 'odd-$s',
          options: options,
          references: references,
          referenceTurns: turn,
        ),
      );
    }
  } else if (scene == 'growth') {
    final blanks = switch (age) {
      AgeBand.preschool => [2],
      AgeBand.primary => [1, 3],
      AgeBand.advanced => [0, 1, 2, 3],
    };
    final remaining = blanks.toSet();
    for (var s = 0; s < blanks.length; s++) {
      final active = blanks[s];
      stages.add(
        PictureStage.match(
          id: 'grow-$active',
          rule: ChoiceRule.growthOrder,
          expected: _growth[active],
          activeIndex: active,
          sequence: [
            for (var i = 0; i < 4; i++)
              remaining.contains(i) ? null : _growth[i],
          ],
          options: _options(
            age == AgeBand.preschool ? [_growth[active], _growth[0]] : _growth,
            s + 1,
          ),
        ),
      );
      remaining.remove(active);
    }
  } else {
    final a = _balloons[0];
    final b = _balloons[1];
    final pattern = PicturePattern(switch (age) {
      AgeBand.preschool => [a, b],
      AgeBand.primary => [a, b, b],
      AgeBand.advanced => [
        for (var turn = 0; turn < 4; turn++) ...[
          a.transform(turns: turn),
          b.transform(turns: turn),
        ],
      ],
    });
    final rounds = age.index + 1;
    for (var s = 0; s < rounds; s++) {
      final start = age == AgeBand.advanced ? s * 2 : s;
      final length = age == AgeBand.preschool ? 3 : 5;
      final expected = pattern.at(start + length);
      final options = age == AgeBand.advanced
          ? [
              expected,
              expected.transform(turns: expected.turns + 1),
              a.transform(turns: expected.turns),
              a.transform(turns: expected.turns + 1),
            ]
          : <PicturePiece>[a, b, _balloons[2], _balloons[3]];
      stages.add(
        PictureStage.match(
          id: 'pattern-$s',
          rule: ChoiceRule.repeatingPattern,
          expected: expected,
          sequence: [
            for (var i = 0; i < length; i++) pattern.at(start + i),
            null,
          ],
          activeIndex: length,
          options: _options(options, s + age.index),
        ),
      );
    }
  }
  return PictureChallenge(
    levelId: level.id,
    scene: level.scene,
    childAge: childAge ?? age.minimumAge,
    asset: asset,
    ageBand: age,
    revision: 1,
    stages: stages,
    holes: holes,
  );
}

List<PictureOption> _options(List<PicturePiece> pieces, int offset) => [
  for (var i = 0; i < pieces.length; i++)
    PictureOption(
      'piece-${(i + offset) % pieces.length}',
      pieces[(i + offset) % pieces.length],
    ),
];

const _zebra = [
  PicturePiece(Rect.fromLTWH(.14, .13, .24, .24)), // eye, muzzle edge, mane
  PicturePiece(Rect.fromLTWH(.25, .30, .24, .24)), // mane meeting shoulder
  PicturePiece(Rect.fromLTWH(.65, .33, .24, .24)), // rump contour and tail
];

// Asymmetric robot details: one eye and ear, half-heart panel, left gripper.
const _robot = [
  PicturePiece(Rect.fromLTWH(.25, .20, .24, .24)),
  PicturePiece(Rect.fromLTWH(.50, .40, .24, .24)),
  PicturePiece(Rect.fromLTWH(.22, .60, .24, .24)),
];

const _puppy = [
  PicturePiece(Rect.fromLTWH(.39, .38, .25, .25)), // face
  PicturePiece(Rect.fromLTWH(.735, .62, .25, .25)), // ball
  PicturePiece(Rect.fromLTWH(.09, .18, .25, .25)), // raised tail
  PicturePiece(Rect.fromLTWH(.34, .64, .25, .25)), // forepaw
];
const _fox = [
  PicturePiece(Rect.fromLTWH(.39, .18, .24, .24)), // face
  PicturePiece(Rect.fromLTWH(.73, .28, .24, .24)), // painted leaves
  PicturePiece(Rect.fromLTWH(.16, .52, .24, .24)), // tail
  PicturePiece(Rect.fromLTWH(.43, .55, .24, .24)), // paint on overalls
];
const _balloons = [
  PicturePiece(
    Rect.fromLTWH(.02, .145, .24, .285),
  ), // coral flowers, knot below
  PicturePiece(Rect.fromLTWH(.26, .145, .24, .285)), // turquoise stars
  PicturePiece(Rect.fromLTWH(.50, .145, .23, .285)), // lavender dots
  PicturePiece(Rect.fromLTWH(.735, .145, .24, .285)), // yellow stripes
];
const _growth = [
  PicturePiece(Rect.fromLTWH(.055, .565, .19, .10)),
  PicturePiece(Rect.fromLTWH(.285, .505, .16, .15)),
  PicturePiece(Rect.fromLTWH(.49, .41, .19, .245)),
  PicturePiece(Rect.fromLTWH(.735, .305, .22, .35)),
];
