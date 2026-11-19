import 'dart:convert';

import '../domain/models.dart';
import 'legacy_catalog.dart';

/// A read-only view of the original schema-v1 save. Its source remains intact
/// even when an individual damaged entry cannot be rendered by the app.
class LegacyArchive {
  const LegacyArchive._({
    required this.originalSnapshot,
    required this.progress,
    required this.drafts,
    required this.artworks,
    required this.settings,
    required this.damagedEntries,
  });

  factory LegacyArchive.fromEncoded(String encoded) {
    const maxSnapshotBytes = 16 * 1024 * 1024;
    if (encoded.length > maxSnapshotBytes ||
        utf8.encode(encoded).length > maxSnapshotBytes) {
      throw const FormatException('Legacy snapshot exceeds the v1 limit');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] is! int ||
        decoded['version'] != 1) {
      throw const FormatException('Not a schema-v1 snapshot');
    }
    final rawSettings = decoded['settings'];
    final rawProgress = decoded['progress'] ?? const <String, dynamic>{};
    final rawDrafts = decoded['drafts'] ?? const <String, dynamic>{};
    final rawArtworks = decoded['artworks'] ?? const <dynamic>[];
    if (rawSettings is! Map<String, dynamic> ||
        rawProgress is! Map<String, dynamic> ||
        rawDrafts is! Map<String, dynamic> ||
        rawArtworks is! List) {
      throw const FormatException('Invalid legacy snapshot structure');
    }
    final settings = _cloneMap(rawSettings);
    final progress = <String, LevelProgress>{};
    final drafts = <String, Map<String, dynamic>>{};
    final artworks = <Artwork>[];
    var damagedEntries = 0;

    // Iterate the frozen v1 index, not the active catalog or its new length.
    for (final id in legacyLevelIndex.keys) {
      if (rawProgress.containsKey(id)) {
        try {
          final raw = rawProgress[id];
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid legacy progress');
          }
          final stars = raw['stars'];
          final attempts = raw['attempts'] ?? 1;
          if (stars is! int ||
              stars < 1 ||
              stars > 3 ||
              attempts is! int ||
              attempts < 1 ||
              attempts > 1000000) {
            throw const FormatException('Invalid legacy score');
          }
          progress[id] = LevelProgress(
            stars: stars,
            attempts: attempts,
            completedAt: _parseDate(raw['completedAt']),
          );
        } catch (_) {
          damagedEntries++;
        }
      }
      if (rawDrafts.containsKey(id)) {
        try {
          final raw = rawDrafts[id];
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid legacy draft');
          }
          drafts[id] = _cloneMap(raw);
        } catch (_) {
          damagedEntries++;
        }
      }
    }
    damagedEntries += rawProgress.keys
        .where((id) => !legacyLevelIndex.containsKey(id))
        .length;
    damagedEntries += rawDrafts.keys
        .where((id) => !legacyLevelIndex.containsKey(id))
        .length;
    for (final raw in rawArtworks) {
      try {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid legacy artwork');
        }
        final id = raw['levelId'];
        final data = raw['data'];
        if (id is! String ||
            !legacyLevelIndex.containsKey(id) ||
            data is! Map<String, dynamic>) {
          throw const FormatException('Invalid legacy artwork data');
        }
        artworks.add(
          Artwork(
            levelId: id,
            createdAt: _parseDate(raw['createdAt']),
            data: _cloneMap(data),
          ),
        );
      } catch (_) {
        damagedEntries++;
      }
    }
    return LegacyArchive._(
      originalSnapshot: encoded,
      progress: Map.unmodifiable(progress),
      drafts: Map.unmodifiable(drafts),
      artworks: List.unmodifiable(artworks),
      settings: settings,
      damagedEntries: damagedEntries,
    );
  }

  final String originalSnapshot;
  final Map<String, LevelProgress> progress;
  final Map<String, Map<String, dynamic>> drafts;
  final List<Artwork> artworks;
  final Map<String, dynamic> settings;
  final int damagedEntries;

  bool get hasData =>
      progress.isNotEmpty || drafts.isNotEmpty || artworks.isNotEmpty;
  int get completedCount => progress.length;
  int get draftCount => drafts.length;
  int get artworkCount => artworks.length;
  int get totalStars =>
      progress.values.fold(0, (total, item) => total + item.stars);

  static Map<String, dynamic> _cloneMap(Map<String, dynamic> source) =>
      Map<String, dynamic>.unmodifiable({
        for (final entry in source.entries)
          entry.key: _cloneFiniteJson(entry.value),
      });

  /// Retain every mark and point. V2 drawing simplification and budgets must
  /// never alter work created by the original app.
  static Object? _cloneFiniteJson(Object? value) {
    if (value == null || value is String || value is bool) return value;
    if (value is num && value.isFinite) return value;
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_cloneFiniteJson));
    }
    if (value is Map<String, dynamic>) return _cloneMap(value);
    throw const FormatException('Legacy data must contain finite JSON values');
  }

  static DateTime _parseDate(Object? value) {
    if (value is! String) {
      throw const FormatException('Missing legacy timestamp');
    }
    final match = RegExp(
      r'^([+-]?\d{4,6})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})?$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid legacy timestamp');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final calendar = DateTime.utc(year, month, day);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      throw const FormatException('Invalid legacy calendar date');
    }
    final zone = match.group(7);
    if (zone != null && zone != 'Z') {
      final zoneHour = int.parse(zone.substring(1, 3));
      final zoneMinute = int.parse(zone.substring(4, 6));
      if (zoneHour > 23 || zoneMinute > 59) {
        throw const FormatException('Invalid legacy time zone');
      }
    }
    return DateTime.parse(value);
  }
}
