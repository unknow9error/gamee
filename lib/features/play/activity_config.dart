import 'package:flutter/material.dart';

import '../../domain/models.dart';

@immutable
class ActivityConfig {
  const ActivityConfig({
    required this.level,
    required this.language,
    required this.onChanged,
    required this.onCompleted,
    required this.onFeedback,
    this.initialData,
    this.reducedMotion = false,
    this.showHint = false,
    this.childAge = 6,
    this.onSpeak,
  });
  final LevelDefinition level;
  final String language;
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<Map<String, dynamic>> onCompleted;
  final VoidCallback onFeedback;
  final bool reducedMotion;
  final bool showHint;
  final int childAge;
  AgeBand get ageBand => AgeBand.fromAge(childAge);
  final ValueChanged<String>? onSpeak;
}
