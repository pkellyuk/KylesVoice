import '../grid/grid_geometry.dart';
import 'board_card.dart';

/// A board: fixed grid dimensions plus whichever cells are occupied.
///
/// Grid dimensions belong to the board, never to the device. A phone and a
/// tablet showing the same board have identical rows and columns and
/// differently sized cells, which preserves the relative motor plan when a user
/// moves between devices.
///
/// Immutable. Every edit produces a new board, which makes undo a matter of
/// keeping the previous value rather than of reversing operations.
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

  bool get isValid => rows > 0 && cols > 0;

  int get cellCount => rows * cols;

  /// Cards that are actually rendered. Hidden cards keep their cell reserved but
  /// are not shown.
  List<BoardCard> get visibleCards =>
      cards.where((BoardCard c) => c.hidden == false).toList(growable: false);

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

  bool isWithinGrid(CellAddress? address) {
    if (address == null) {
      return false;
    }

    if (address.row < 0 || address.row >= rows) {
      return false;
    }

    if (address.col < 0 || address.col >= cols) {
      return false;
    }

    return true;
  }

  /// Adds or replaces the card at [card]'s address.
  ///
  /// Returns the board unchanged if the address falls outside the grid, rather
  /// than throwing: a bad edit must never take the board down.
  Board withCard(BoardCard? card) {
    if (card == null) {
      return this;
    }

    if (isWithinGrid(card.address) == false) {
      return this;
    }

    final List<BoardCard> next = cards
        .where((BoardCard c) => c.address != card.address)
        .toList();

    next.add(card);

    return copyWith(cards: next);
  }

  /// Removes the card at [address], leaving the cell empty and in place.
  Board withoutCard(CellAddress? address) {
    if (address == null) {
      return this;
    }

    return copyWith(
      cards: cards.where((BoardCard c) => c.address != address).toList(),
    );
  }

  /// Moves a card to a new address, refusing if the destination is occupied.
  ///
  /// Moving a populated cell breaks the motor plan the user has learned, so the
  /// editor must warn before calling this. The model enforces only that two
  /// cards cannot occupy one position.
  Board withMovedCard({required CellAddress? from, required CellAddress? to}) {
    if (from == null || to == null) {
      return this;
    }

    if (from == to) {
      return this;
    }

    final BoardCard? moving = cardAt(from);

    if (moving == null) {
      return this;
    }

    if (isWithinGrid(to) == false) {
      return this;
    }

    if (cardAt(to) != null) {
      return this;
    }

    return withoutCard(from).withCard(moving.copyWith(address: to));
  }

  /// Changes the grid dimensions.
  ///
  /// Cards falling outside the new bounds are **kept in the returned
  /// [orphaned] list rather than silently deleted**, so the editor can tell the
  /// parent exactly what a resize would cost before committing to it.
  ({Board board, List<BoardCard> orphaned}) resized({
    required int newRows,
    required int newCols,
  }) {
    if (newRows < 1 || newCols < 1) {
      return (board: this, orphaned: const <BoardCard>[]);
    }

    final List<BoardCard> kept = <BoardCard>[];
    final List<BoardCard> lost = <BoardCard>[];

    for (final BoardCard card in cards) {
      final bool fits =
          card.address.row < newRows && card.address.col < newCols;

      if (fits) {
        kept.add(card);
        continue;
      }

      lost.add(card);
    }

    return (
      board: Board(name: name, rows: newRows, cols: newCols, cards: kept),
      orphaned: lost,
    );
  }

  Board copyWith({String? name, int? rows, int? cols, List<BoardCard>? cards}) {
    return Board(
      name: name ?? this.name,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      cards: cards ?? this.cards,
    );
  }

  /// Kyle's provisional starting board. See `docs/DESIGN.md` section 12.
  ///
  /// Three columns by two rows, sized from the measured 42 x 46 mm adult slap
  /// footprint scaled to a child's hand against the Fire HD 8's 172 x 108 mm
  /// panel. Only four of the six cells are filled: vocabulary grows by occupying
  /// empty cells, never by resizing or rearranging, so a motor path learned now
  /// stays correct for years.
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
        colourArgb: 0xFF4FA3D1,
      ),
      BoardCard(
        address: CellAddress(row: 0, col: 1),
        label: 'eat',
        speech: 'I want something to eat',
        glyph: '\u{1F34E}',
        colourArgb: 0xFFD96C6C,
      ),
      BoardCard(
        address: CellAddress(row: 1, col: 0),
        label: 'more',
        speech: 'more please',
        glyph: '\u{2795}',
        colourArgb: 0xFF6BA368,
      ),
      BoardCard(
        address: CellAddress(row: 1, col: 2),
        label: 'finished',
        speech: 'all done',
        glyph: '\u{270B}',
        colourArgb: 0xFFC08A3E,
      ),
    ],
  );

  @override
  String toString() => 'Board("$name", ${rows}x$cols, ${cards.length} cards)';
}
