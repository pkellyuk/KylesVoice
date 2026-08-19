import '../grid/grid_geometry.dart';

/// What a card does when activated.
enum CardKind { speak, navigate, action }

/// One card on a board.
///
/// Colour is stored as a plain ARGB integer rather than a Flutter `Color`, so
/// this model and its serialisation stay inside the platform-free core and can
/// be tested with no Flutter dependency.
class BoardCard {
  /// The card's fixed address. Position is identity: a card's coordinates never
  /// change once chosen, because the user learns the motor path to a word rather
  /// than the picture on it.
  final CellAddress address;

  /// Displayed text. Shown even for a non-reading user: incidental exposure to
  /// print alongside the image is standard practice and costs nothing.
  final String label;

  /// What is spoken. Always separate from [label], so a card reading "toilet"
  /// can say "I need the toilet".
  final String speech;

  /// Placeholder artwork until the symbol library and photo capture exist.
  final String glyph;

  final int colourArgb;
  final CardKind kind;

  /// How many rows and columns the card spans. Spans make a card physically
  /// larger without disturbing any other card's position.
  final int rowSpan;
  final int colSpan;

  /// Hidden, but the cell stays occupied and empty. Never collapse the gap: the
  /// position must survive so the card can be restored to it later.
  final bool hidden;

  const BoardCard({
    required this.address,
    required this.label,
    required this.speech,
    required this.glyph,
    required this.colourArgb,
    this.kind = CardKind.speak,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.hidden = false,
  });

  /// The text actually spoken, falling back to the label when no separate
  /// phrase was given.
  String get effectiveSpeech {
    if (speech.trim().isEmpty) {
      return label.trim();
    }

    return speech.trim();
  }

  BoardCard copyWith({
    CellAddress? address,
    String? label,
    String? speech,
    String? glyph,
    int? colourArgb,
    CardKind? kind,
    int? rowSpan,
    int? colSpan,
    bool? hidden,
  }) {
    return BoardCard(
      address: address ?? this.address,
      label: label ?? this.label,
      speech: speech ?? this.speech,
      glyph: glyph ?? this.glyph,
      colourArgb: colourArgb ?? this.colourArgb,
      kind: kind ?? this.kind,
      rowSpan: rowSpan ?? this.rowSpan,
      colSpan: colSpan ?? this.colSpan,
      hidden: hidden ?? this.hidden,
    );
  }

  @override
  String toString() => 'BoardCard($address "$label" -> "$effectiveSpeech")';

  @override
  bool operator ==(Object other) =>
      other is BoardCard &&
      other.address == address &&
      other.label == label &&
      other.speech == speech &&
      other.glyph == glyph &&
      other.colourArgb == colourArgb &&
      other.kind == kind &&
      other.rowSpan == rowSpan &&
      other.colSpan == colSpan &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(
    address,
    label,
    speech,
    glyph,
    colourArgb,
    kind,
    rowSpan,
    colSpan,
    hidden,
  );
}
