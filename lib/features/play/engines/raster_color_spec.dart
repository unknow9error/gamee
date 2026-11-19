import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/models.dart';

enum ColorRuleMode { color, number, shape, numberAndShape, parityAndShape }

/// Metadata is bound to one reviewed asset. Decoration is never implicitly a
/// target: only the region IDs in the selected age rule affect completion.
class ColorSceneSpec {
  ColorSceneSpec._({
    required this.version,
    required this.asset,
    required this.assetSha256,
    required this.imageWidth,
    required this.imageHeight,
    required this.palette,
    required this.regions,
    required this.rules,
    required this.labelSlots,
  });

  final int version;
  final String asset;
  final String assetSha256;
  final int imageWidth;
  final int imageHeight;
  final List<ColorPaletteEntry> palette;
  final List<ColorRegionSpec> regions;
  final Map<AgeBand, ColorAgeRule> rules;

  /// Reviewed blank-background rectangles for readable external clues.
  /// These never participate in region hit testing or accepted-color rules.
  final List<Rect> labelSlots;

  factory ColorSceneSpec.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) _invalid('version');
    final asset = _string(json['asset'], 'asset', 160);
    if (!RegExp(r'^assets/images/levels/[a-zA-Z0-9_-]+\.png$')
        .hasMatch(asset)) {
      _invalid('asset');
    }
    final digest = _string(json['assetSha256'], 'assetSha256', 64);
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest)) {
      _invalid('assetSha256');
    }
    final width = _integer(json['imageWidth'], 'imageWidth', 64, 8192);
    final height = _integer(json['imageHeight'], 'imageHeight', 64, 8192);
    final labelSlots = _list(
      json['labelSlots'] ?? const [],
      'labelSlots',
      0,
      8,
    ).map(_labelSlot).toList(growable: false);
    for (var i = 0; i < labelSlots.length; i++) {
      for (var j = i + 1; j < labelSlots.length; j++) {
        if (labelSlots[i].overlaps(labelSlots[j])) {
          _invalid('labelSlots.overlap');
        }
      }
    }
    final palette = _list(json['palette'], 'palette', 2, 8)
        .map((raw) => ColorPaletteEntry._fromJson(_map(raw, 'palette.entry')))
        .toList(growable: false);
    _unique(palette.map((entry) => entry.id), 'palette.id');
    _unique(palette.map((entry) => entry.color.toARGB32()), 'palette.color');
    final regions = _list(json['regions'], 'regions', 6, 32)
        .map((raw) => ColorRegionSpec._fromJson(_map(raw, 'regions.entry')))
        .toList(growable: false);
    _unique(regions.map((region) => region.id), 'regions.id');
    for (var i = 0; i < regions.length; i++) {
      for (var j = i + 1; j < regions.length; j++) {
        final overlap = Path.combine(
          PathOperation.intersect,
          regions[i].path,
          regions[j].path,
        );
        if (!overlap.getBounds().isEmpty) {
          _invalid('regions.overlap');
        }
      }
    }
    final paletteIds = palette.map((entry) => entry.id).toSet();
    for (final region in regions) {
      if (!paletteIds.contains(region.paletteId)) _invalid('regions.paletteId');
    }
    final rawRules = _map(json['rules'], 'rules');
    final rules = <AgeBand, ColorAgeRule>{};
    final regionIds = regions.map((region) => region.id).toSet();
    for (final band in AgeBand.values) {
      final rule = ColorAgeRule._fromJson(
        _map(rawRules[band.name], 'rules.ageBand'),
        band,
      );
      for (final id in rule.regionIds) {
        if (!regionIds.contains(id)) _invalid('rules.regionIds');
      }
      for (final lookup in rule.lookup) {
        if (!paletteIds.contains(lookup.paletteId)) {
          _invalid('rules.lookup.paletteId');
        }
      }
      rules[band] = rule;
    }
    final spec = ColorSceneSpec._(
      version: 1,
      asset: asset,
      assetSha256: digest.toLowerCase(),
      imageWidth: width,
      imageHeight: height,
      palette: List.unmodifiable(palette),
      regions: List.unmodifiable(regions),
      rules: Map.unmodifiable(rules),
      labelSlots: List.unmodifiable(labelSlots),
    );
    spec._validateSemantics();
    return spec;
  }

  ColorAgeRule ruleFor(AgeBand band) => rules[band]!;
  List<ColorRegionSpec> regionsFor(AgeBand band) {
    final byId = {for (final region in regions) region.id: region};
    return List.unmodifiable(ruleFor(band).regionIds.map((id) => byId[id]!));
  }

  List<ColorPaletteEntry> paletteFor(AgeBand band) {
    final ids = regionsFor(band).map((region) => region.paletteId).toSet();
    return List.unmodifiable(palette.where((entry) => ids.contains(entry.id)));
  }

  ColorPaletteEntry paletteById(String id) {
    for (final entry in palette) {
      if (entry.id == id) return entry;
    }
    throw ArgumentError('Unknown color palette ID');
  }

  ColorRegionSpec regionById(String id) {
    for (final region in regions) {
      if (region.id == id) return region;
    }
    throw ArgumentError('Unknown color region ID');
  }

  String acceptedPaletteIdFor(ColorRegionSpec region, AgeBand band) {
    final rule = ruleFor(band);
    if (!rule.regionIds.contains(region.id)) {
      throw ArgumentError('Region is not a target for this age band');
    }
    final canonical = regionById(region.id);
    final candidates = switch (rule.mode) {
      ColorRuleMode.color => palette.where(
        (entry) => entry.id == canonical.paletteId,
      ),
      ColorRuleMode.number => paletteFor(
        band,
      ).where((entry) => entry.number == canonical.value),
      ColorRuleMode.shape => paletteFor(
        band,
      ).where((entry) => entry.symbol == canonical.symbol),
      ColorRuleMode.numberAndShape || ColorRuleMode.parityAndShape =>
        rule.lookup
            .where((entry) => entry.matches(canonical, rule.mode))
            .map((entry) => paletteById(entry.paletteId)),
    };
    if (candidates.length != 1) _invalid('rules.ambiguous');
    return candidates.single.id;
  }

  ColorPaletteEntry acceptedPaletteFor(ColorRegionSpec region, AgeBand band) =>
      paletteById(acceptedPaletteIdFor(region, band));

  void _validateSemantics() {
    for (final band in AgeBand.values) {
      final rule = ruleFor(band);
      final activePalette = paletteFor(band);
      if (rule.mode == ColorRuleMode.number) {
        _unique(
          activePalette.map((entry) => entry.number),
          'rules.number.ambiguous',
        );
      }
      if (rule.mode == ColorRuleMode.shape) {
        _unique(
          activePalette.map((entry) => entry.symbol),
          'rules.shape.ambiguous',
        );
      }
      if (rule.mode == ColorRuleMode.numberAndShape ||
          rule.mode == ColorRuleMode.parityAndShape) {
        _unique(
          rule.lookup.map((entry) => entry.key(rule.mode)),
          'rules.lookup.ambiguous',
        );
        // A two-condition exercise must actually need both pieces of evidence.
        final first = <Object, Set<String>>{};
        final second = <String, Set<String>>{};
        for (final entry in rule.lookup) {
          final key = rule.mode == ColorRuleMode.numberAndShape
              ? entry.value!
              : entry.parity!;
          first.putIfAbsent(key, () => <String>{}).add(entry.paletteId);
          second
              .putIfAbsent(entry.symbol, () => <String>{})
              .add(entry.paletteId);
        }
        if (!first.values.any((ids) => ids.length > 1) ||
            !second.values.any((ids) => ids.length > 1)) {
          _invalid('rules.lookup.twoConditions');
        }
      }
      final usedLookups = <String>{};
      for (final region in regionsFor(band)) {
        final derived = acceptedPaletteIdFor(region, band);
        if (derived != region.paletteId) _invalid('rules.paletteMismatch');
        for (final entry in rule.lookup) {
          if (entry.matches(region, rule.mode)) {
            usedLookups.add(entry.key(rule.mode));
          }
        }
      }
      if (rule.lookup.isNotEmpty && usedLookups.length != rule.lookup.length) {
        _invalid('rules.lookup.unused');
      }
    }
  }
}

class ColorPaletteEntry {
  const ColorPaletteEntry._({
    required this.id,
    required this.color,
    required this.symbol,
    required this.number,
    required this.names,
  });
  final String id;
  final Color color;
  final String symbol;
  final int number;
  final LocalizedText names;

  factory ColorPaletteEntry._fromJson(Map<String, dynamic> json) {
    final hex = _string(json['color'], 'palette.color', 7);
    if (!RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(hex)) _invalid('palette.color');
    return ColorPaletteEntry._(
      id: _id(json['id'], 'palette.id'),
      color: Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)),
      symbol: _symbol(json['symbol'], 'palette.symbol'),
      number: _integer(json['number'], 'palette.number', 1, 8),
      names: _names(json['names'], 'palette.names'),
    );
  }
}

class ColorRegionSpec {
  const ColorRegionSpec._({
    required this.id,
    required this.paletteId,
    required this.points,
    required this.holes,
    required this.anchor,
    required this.value,
    required this.symbol,
    required this.advancedValue,
    required this.advancedSymbol,
    required this.names,
    required this.preschool,
  });
  final String id;
  final String paletteId;
  final List<Offset> points;
  final List<List<Offset>> holes;
  final Offset anchor;
  final int value;
  final String symbol;
  final int advancedValue;
  final String advancedSymbol;
  final LocalizedText names;
  final bool preschool;

  Path get path {
    final result = Path()
      ..fillType = PathFillType.evenOdd
      ..addPolygon(points, true);
    for (final hole in holes) {
      result.addPolygon(hole, true);
    }
    return result;
  }

  factory ColorRegionSpec._fromJson(Map<String, dynamic> json) {
    final points = _polygon(json['points'], 'regions.points');
    final outer = Path()..addPolygon(points, true);
    final holes = <List<Offset>>[];
    if (json['holes'] != null) {
      for (final raw in _list(json['holes'], 'regions.holes', 0, 32)) {
        final hole = _polygon(raw, 'regions.holes.points');
        if (hole.any((point) => !outer.contains(point)) ||
            _contoursIntersect(points, hole)) {
          _invalid('regions.holes.outside');
        }
        for (final earlier in holes) {
          final earlierPath = Path()..addPolygon(earlier, true);
          final holePath = Path()..addPolygon(hole, true);
          if (_contoursIntersect(earlier, hole) ||
              earlierPath.contains(hole.first) ||
              holePath.contains(earlier.first)) {
            _invalid('regions.holes.overlap');
          }
        }
        holes.add(hole);
      }
    }
    final anchor = _point(json['anchor'], 'regions.anchor');
    final value = _integer(json['value'], 'regions.value', 1, 32);
    final symbol = _symbol(json['symbol'], 'regions.symbol');
    final preschool = json['preschool'];
    if (preschool != null && preschool is! bool) _invalid('regions.preschool');
    final region = ColorRegionSpec._(
      id: _id(json['id'], 'regions.id'),
      paletteId: _id(json['paletteId'], 'regions.paletteId'),
      points: points,
      holes: List.unmodifiable(holes),
      anchor: anchor,
      value: value,
      symbol: symbol,
      advancedValue: json['advancedValue'] == null
          ? value
          : _integer(json['advancedValue'], 'regions.advancedValue', 1, 32),
      advancedSymbol: json['advancedSymbol'] == null
          ? symbol
          : _symbol(json['advancedSymbol'], 'regions.advancedSymbol'),
      names: _names(json['names'], 'regions.names'),
      preschool: preschool == true,
    );
    if (!region.path.contains(anchor)) _invalid('regions.anchor.outside');
    return region;
  }
}

class ColorAgeRule {
  const ColorAgeRule._({
    required this.regionIds,
    required this.mode,
    required this.lookup,
  });
  final List<String> regionIds;
  final ColorRuleMode mode;
  final List<ColorRuleLookup> lookup;

  factory ColorAgeRule._fromJson(Map<String, dynamic> json, AgeBand band) {
    final minimum = band == AgeBand.preschool ? 2 : 6;
    final maximum = band == AgeBand.preschool ? 4 : 10;
    final ids = _list(
      json['regionIds'],
      'rules.regionIds',
      minimum,
      maximum,
    ).map((raw) => _id(raw, 'rules.regionIds')).toList(growable: false);
    _unique(ids, 'rules.regionIds');
    final modeName = _string(json['mode'], 'rules.mode', 24);
    final mode = ColorRuleMode.values
        .where((mode) => mode.name == modeName)
        .firstOrNull;
    final allowed = switch (band) {
      AgeBand.preschool => const [ColorRuleMode.color],
      AgeBand.primary => const [ColorRuleMode.number, ColorRuleMode.shape],
      AgeBand.advanced => const [
        ColorRuleMode.numberAndShape,
        ColorRuleMode.parityAndShape,
      ],
    };
    if (mode == null || !allowed.contains(mode)) _invalid('rules.mode');
    final advanced = band == AgeBand.advanced;
    final lookup = <ColorRuleLookup>[];
    if (advanced) {
      for (final raw in _list(json['lookup'], 'rules.lookup', 2, 10)) {
        lookup.add(
          ColorRuleLookup._fromJson(_map(raw, 'rules.lookup.entry'), mode),
        );
      }
    } else if (json['lookup'] != null &&
        _list(json['lookup'], 'rules.lookup', 0, 10).isNotEmpty) {
      _invalid('rules.lookup.unexpected');
    }
    return ColorAgeRule._(
      regionIds: List.unmodifiable(ids),
      mode: mode,
      lookup: List.unmodifiable(lookup),
    );
  }

  String resolvePalette(ColorRegionSpec region) {
    if (!regionIds.contains(region.id)) {
      throw ArgumentError('Region is not a target for this age band');
    }
    if (mode != ColorRuleMode.numberAndShape &&
        mode != ColorRuleMode.parityAndShape) {
      return region.paletteId; // The scene validates each simple legend.
    }
    final matches = lookup.where((entry) => entry.matches(region, mode));
    if (matches.length != 1) _invalid('rules.lookup.ambiguous');
    return matches.single.paletteId;
  }
}

class ColorRuleLookup {
  const ColorRuleLookup._({
    required this.paletteId,
    required this.symbol,
    this.value,
    this.parity,
  });
  final String paletteId;
  final String symbol;
  final int? value;
  final String? parity;

  factory ColorRuleLookup._fromJson(
    Map<String, dynamic> json,
    ColorRuleMode mode,
  ) {
    final parity = json['parity'];
    if (mode == ColorRuleMode.parityAndShape &&
        parity != 'odd' &&
        parity != 'even') {
      _invalid('rules.lookup.parity');
    }
    return ColorRuleLookup._(
      paletteId: _id(json['paletteId'], 'rules.lookup.paletteId'),
      symbol: _symbol(json['symbol'], 'rules.lookup.symbol'),
      value: mode == ColorRuleMode.numberAndShape
          ? _integer(json['value'], 'rules.lookup.value', 1, 32)
          : null,
      parity: mode == ColorRuleMode.parityAndShape ? parity as String : null,
    );
  }

  bool matches(ColorRegionSpec region, ColorRuleMode mode) => switch (mode) {
    ColorRuleMode.numberAndShape =>
      value == region.advancedValue && symbol == region.advancedSymbol,
    ColorRuleMode.parityAndShape =>
      parity == (region.advancedValue.isOdd ? 'odd' : 'even') &&
          symbol == region.advancedSymbol,
    _ => false,
  };
  String key(ColorRuleMode mode) => mode == ColorRuleMode.numberAndShape
      ? '$value:$symbol'
      : '$parity:$symbol';
}

Never _invalid(String field) =>
    throw FormatException('Invalid raster color content: $field');

Rect _labelSlot(dynamic value) {
  final raw = _list(value, 'labelSlots.rect', 4, 4);
  if (raw.any(
    (coordinate) =>
        coordinate is! num ||
        !coordinate.isFinite ||
        coordinate < 0 ||
        coordinate > 1,
  )) {
    _invalid('labelSlots.rect');
  }
  final slot = Rect.fromLTWH(
    (raw[0] as num).toDouble(),
    (raw[1] as num).toDouble(),
    (raw[2] as num).toDouble(),
    (raw[3] as num).toDouble(),
  );
  if (slot.width <= 0 ||
      slot.height <= 0 ||
      slot.right > 1 ||
      slot.bottom > 1) {
    _invalid('labelSlots.rect');
  }
  return slot;
}

Map<String, dynamic> _map(dynamic value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) _invalid(field);
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(dynamic value, String field, int minimum, int maximum) {
  if (value is! List || value.length < minimum || value.length > maximum) {
    _invalid(field);
  }
  return value;
}

String _string(dynamic value, String field, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximum ||
      value.contains(RegExp(r'[\x00-\x1F]'))) {
    _invalid(field);
  }
  return value;
}

String _id(dynamic value, String field) {
  final id = _string(value, field, 64);
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) _invalid(field);
  return id;
}

const _symbols = {
  'circle',
  'triangle',
  'square',
  'star',
  'heart',
  'diamond',
  'flower',
  'leaf',
};
String _symbol(dynamic value, String field) {
  final symbol = _string(value, field, 16);
  if (!_symbols.contains(symbol)) _invalid(field);
  return symbol;
}

int _integer(dynamic value, String field, int minimum, int maximum) {
  if (value is! int || value < minimum || value > maximum) _invalid(field);
  return value;
}

LocalizedText _names(dynamic value, String field) {
  final map = _map(value, field);
  return LocalizedText(
    _string(map['ru'], field, 100),
    _string(map['kk'], field, 100),
    _string(map['en'], field, 100),
  );
}

void _unique(Iterable<Object> values, String field) {
  final seen = <Object>{};
  for (final value in values) {
    if (!seen.add(value)) _invalid(field);
  }
}

Offset _point(dynamic value, String field) {
  final pair = _list(value, field, 2, 2);
  if (pair.any((n) => n is! num || !n.isFinite || n < 0 || n > 1)) {
    _invalid(field);
  }
  return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
}

List<Offset> _polygon(dynamic value, String field) {
  final points = _list(
    value,
    field,
    3,
    2049,
  ).map((raw) => _point(raw, field)).toList();
  if (points.length > 3 && (points.first - points.last).distance < 1e-10) {
    points.removeLast();
  }
  if (points.length > 2048) _invalid(field);
  var twiceArea = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    if ((a - b).distance < 1e-10) _invalid(field);
    twiceArea += a.dx * b.dy - b.dx * a.dy;
  }
  if (twiceArea.abs() < 1e-7) _invalid(field);
  for (var i = 0; i < points.length; i++) {
    final next = (i + 1) % points.length;
    for (var j = i + 1; j < points.length; j++) {
      final otherNext = (j + 1) % points.length;
      if (i == j || next == j || otherNext == i) continue;
      if (_intersects(points[i], points[next], points[j], points[otherNext])) {
        _invalid(field);
      }
    }
  }
  return List.unmodifiable(points);
}

bool _contoursIntersect(List<Offset> a, List<Offset> b) {
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      if (_intersects(
        a[i],
        a[(i + 1) % a.length],
        b[j],
        b[(j + 1) % b.length],
      )) {
        return true;
      }
    }
  }
  return false;
}

double _cross(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
bool _intersects(Offset a, Offset b, Offset c, Offset d) {
  const epsilon = 1e-10;
  if (math.max(a.dx, b.dx) + epsilon < math.min(c.dx, d.dx) ||
      math.max(c.dx, d.dx) + epsilon < math.min(a.dx, b.dx) ||
      math.max(a.dy, b.dy) + epsilon < math.min(c.dy, d.dy) ||
      math.max(c.dy, d.dy) + epsilon < math.min(a.dy, b.dy)) {
    return false;
  }
  final ac = _cross(a, b, c),
      ad = _cross(a, b, d),
      ca = _cross(c, d, a),
      cb = _cross(c, d, b);
  int sign(double value) => value.abs() <= epsilon ? 0 : (value > 0 ? 1 : -1);
  return sign(ac) * sign(ad) <= 0 && sign(ca) * sign(cb) <= 0;
}
