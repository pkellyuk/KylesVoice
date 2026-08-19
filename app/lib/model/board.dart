import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

/// What a card does when activated.
enum CardKind { speak, navigate, action }

/// One card on the board.
///
/// Deliberately minimal for now: no persistence, no dual photograph and symbol,
/// no recorded audio. Those arrive with the data model in `docs/DATA-MODEL.md`.
/// This exists so the resolver can be driven by a real rendered grid on a real
/// device.
class BoardCard {
  final CellAddress address;

  /// Displayed text. Shown even though Kyle cannot read: incidental exposure to
  /// print alongside the image is standard practice and costs nothing.
  final String label;

  /// What is spoken. Always separate from [label], so a card reading "toilet"
  /// can say "I need the toilet".
  final String speech;

  /// Placeholder artwork until the symbol library and photo capture exist.
  final String glyph;

  final Color colour;
  final CardKind kind;

  const BoardCard({
    required this.address,
    required this.label,
    required this.speech,
    required this.glyph,
    required this.colour,
    this.kind = CardKind.speak,
  });
}

/// A board: fixed grid dimensions plus whichever cells are occupied.
///
/// Grid dimensions belong to the board, never to the device. A phone and a
/// tablet showing this board have the same rows and columns and differently
/// sized cells, which preserves the relative motor plan across devices.
class Board {
  final String name;
  final int rows;
  final int cols;
  final List<BoardCard> cards;

  const Board({
    required this.name,
    required this.rows,
    required this.cols,
    required this.cards,
  });

  /// The card at an address, or null if that cell is empty.
  ///
  /// Empty cells are ordinary and permanent. The board never collapses gaps,
  /// because a card's position is the thing the user learns.
  BoardCard? cardAt(CellAddress? address) {
    if (address == null) {
      return null;
    }

    for (final BoardCard card in cards) {
      if (card.address == address) {
        return card;
      }
    }

    return null;
  }

  /// Kyle's provisional starting board. See `docs/DESIGN.md` section 12.
  ///
  /// Three columns by two rows, sized from the measured 42 x 46 mm adult slap
  /// footprint scaled to a child's hand against the Fire HD 8's 172 x 108 mm
  /// panel. Only four of the six cells are filled: vocabulary grows by
  /// occupying empty cells, never by resizing or rearranging the grid, so a
  /// motor path learned now stays correct for years.
  ///
  /// The vocabulary itself is a placeholder. Choosing it is the speech and
  /// language therapy team's job, not ours.
  static const Board kyleStarter = Board(
    name: 'Kyle',
    rows: 2,
    cols: 3,
    cards: <BoardCard>[
      BoardCard(
        address: CellAddress(row: 0, col: 0),
        label: 'drink',
        speech: 'I want a drink',
        glyph: '\u{1F964}',
        colour: Color(0xFF4FA3D1),
      ),
      BoardCard(
        address: CellAddress(row: 0, col: 1),
        label: 'eat',
        speech: 'I want something to eat',
        glyph: '\u{1F34E}',
        colour: Color(0xFFD96C6C),
      ),
      BoardCard(
        address: CellAddress(row: 1, col: 0),
        label: 'more',
        speech: 'more please',
        glyph: '\u{2795}',
        colour: Color(0xFF6BA368),
      ),
      BoardCard(
        address: CellAddress(row: 1, col: 2),
        label: 'finished',
        speech: 'all done',
        glyph: '\u{270B}',
        colour: Color(0xFFC08A3E),
      ),
    ],
  );
}
