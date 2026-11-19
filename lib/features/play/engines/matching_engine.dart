import '../content/matching_layouts.dart';

enum MatchingTapResult { ignored, selected, mismatch, matched, completed }

/// Pair identity and recovery rules are independent of timing and rendering.
class MatchingEngine {
  MatchingEngine({required this.layout, Map<String, dynamic>? initialData}) {
    _restore(initialData);
  }

  final MatchingLayout layout;
  final Set<String> _solved = {};
  String? _selected;
  List<String> _mismatch = const [];
  Set<String> get solvedPairIds => Set.unmodifiable(_solved);
  String? get selectedCardId => _selected;
  List<String> get mismatchCardIds => List.unmodifiable(_mismatch);
  bool get complete => _solved.length == layout.pairIds.length;
  bool get waitingForMismatch => _mismatch.isNotEmpty;
  bool isSolved(MatchingCard card) => _solved.contains(card.pairId);
  bool isRevealed(MatchingCard card) =>
      !layout.memoryMode ||
      isSolved(card) ||
      _selected == card.id ||
      _mismatch.contains(card.id);

  MatchingTapResult tap(String id) {
    final card = layout.cardById(id);
    if (card == null ||
        complete ||
        waitingForMismatch ||
        isSolved(card) ||
        id == _selected) {
      return MatchingTapResult.ignored;
    }
    final previous = layout.cardById(_selected);
    if (previous == null) {
      _selected = id;
      return MatchingTapResult.selected;
    }
    _selected = null;
    if (previous.pairId != card.pairId) {
      _mismatch = [previous.id, id];
      return MatchingTapResult.mismatch;
    }
    _solved.add(card.pairId);
    return complete ? MatchingTapResult.completed : MatchingTapResult.matched;
  }

  void clearMismatch() => _mismatch = const [];

  /// A visual aid only: it cannot select a card or award a pair.
  List<String> hintCardIds() {
    final first = layout.cards.where((card) => !isSolved(card)).firstOrNull;
    if (first == null) return const [];
    return layout.cards
        .where((card) => card.pairId == first.pairId)
        .map((card) => card.id)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'kind': 'matching',
    'levelId': layout.levelId,
    'ageBand': layout.ageBand.name,
    'layoutRevision': layout.revision,
    'solvedPairIds': _solved.toList(growable: false),
    'selectedCardId': _selected,
    'revealedCardIds': layout.memoryMode
        ? <String>[?_selected, ..._mismatch]
        : <String>[],
  };

  void _restore(Map<String, dynamic>? data) {
    if (data == null ||
        data['version'] != 2 ||
        data['kind'] != 'matching' ||
        data['levelId'] != layout.levelId ||
        data['ageBand'] != layout.ageBand.name ||
        data['layoutRevision'] != layout.revision) {
      return;
    }
    final rawPairs = data['solvedPairIds'];
    if (rawPairs is List) {
      _solved.addAll(
        rawPairs.take(12).whereType<String>().where(layout.pairIds.contains),
      );
    }
    final selected = data['selectedCardId'];
    final card = selected is String ? layout.cardById(selected) : null;
    if (card == null || isSolved(card)) return;
    // Only a coherent single-card reveal can survive a resume. Temporary
    // mismatches/hints close; malformed or oversized reveal lists cannot
    // expose the board or turn an unselected card into a match.
    if (layout.memoryMode) {
      final reveals = data['revealedCardIds'];
      if (reveals is! List ||
          reveals.length != 1 ||
          reveals.single != card.id) {
        return;
      }
    }
    _selected = card.id;
  }
}
