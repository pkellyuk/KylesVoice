import '../grid/grid_geometry.dart';

/// What a card does when activated.
enum CardKind { speak, navigate, action }

/// How a card's artwork is drawn when it holds both a photograph and a symbol.
///
/// This exists because the speech and language therapy team asked specifically
/// for a system mixing real photographs with abstract symbols. A first board is
/// most motivating when it shows the child's own cup; the concept only
/// generalises once it is attached to a symbol that means any drink.
enum ImageMode {
  /// Photograph only.
  photo,

  /// Symbol only.
  symbol,

  /// Both, side by side.
  both,

  /// Cross-faded between the two by [BoardCard.blend].
  blend,
}

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

  /// File name of the card's photograph, relative to the board's media
  /// directory. Empty when the card has no photograph.
  ///
  /// Relative rather than absolute because an app's data directory path changes
  /// between installs and between devices, and because a board must stay valid
  /// when exported and opened somewhere else.
  final String photoFile;

  /// How the photograph and symbol are combined. Ignored when there is no
  /// photograph, in which case the symbol is always drawn.
  final ImageMode imageMode;

  /// Cross-fade position for [ImageMode.blend]: 0 is the photograph, 1 is the
  /// symbol.
  ///
  /// Intended to be advanced gradually over weeks, so a card can begin as a
  /// photograph of the child's own cup and end as the abstract symbol for
  /// "drink" without ever changing position or label.
  final double blend;

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
    this.photoFile = '',
    this.imageMode = ImageMode.photo,
    this.blend = 0,
    this.kind = CardKind.speak,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.hidden = false,
  });

  bool get hasPhoto => photoFile.trim().isNotEmpty;

  /// The mode actually used for drawing.
  ///
  /// A card with no photograph always shows its symbol, whatever mode is
  /// stored, so removing a photograph can never leave a blank card.
  ImageMode get effectiveImageMode {
    if (hasPhoto == false) {
      return ImageMode.symbol;
    }

    return imageMode;
  }

  /// Opacity of the symbol layer, 0..1, for the current mode.
  double get symbolOpacity {
    switch (effectiveImageMode) {
      case ImageMode.symbol:
        return 1;
      case ImageMode.photo:
        return 0;
      case ImageMode.both:
        return 1;
      case ImageMode.blend:
        return blend.clamp(0.0, 1.0);
    }
  }

  /// Opacity of the photograph layer, 0..1, for the current mode.
  double get photoOpacity {
    switch (effectiveImageMode) {
      case ImageMode.symbol:
        return 0;
      case ImageMode.photo:
        return 1;
      case ImageMode.both:
        return 1;
      case ImageMode.blend:
        return 1 - blend.clamp(0.0, 1.0);
    }
  }

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
    String? photoFile,
    ImageMode? imageMode,
    double? blend,
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
      photoFile: photoFile ?? this.photoFile,
      imageMode: imageMode ?? this.imageMode,
      blend: blend ?? this.blend,
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
      other.photoFile == photoFile &&
      other.imageMode == imageMode &&
      other.blend == blend &&
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
    photoFile,
    imageMode,
    blend,
    kind,
    rowSpan,
    colSpan,
    hidden,
  );
}
