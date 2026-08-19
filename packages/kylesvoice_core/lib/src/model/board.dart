import '../grid/grid_geometry.dart';
import 'board_card.dart';

/// One screenful of cells.
///
/// Every page in a board shares the board's grid dimensions, so a card's
/// position means the same thing on every page and the motor plan survives
/// paging.
class BoardPage {
  final List<BoardCard> cards;

  const BoardPage({required this.cards});

  static const BoardPage blank = BoardPage(cards: <BoardCard>[]);

  int get cardCount => cards.length;

  bool get isEmpty => cards.isEmpty;

  /// The card at an address, or null if that cell is empty.
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

  BoardPage withCard(BoardCard card) {
    final List<BoardCard> next = cards
        .where((BoardCard c) => c.address != card.address)
        .toList();

    next.add(card);

    return BoardPage(cards: next);
  }

  BoardPage withoutCard(CellAddress address) {
    return BoardPage(
      cards: cards.where((BoardCard c) => c.address != address).toList(),
    );
  }

  @override
  String toString() => 'BoardPage(${cards.length} cards)';
}

/// A board: fixed grid dimensions and one or more pages of cells.
///
/// Grid dimensions belong to the board, never to the device or the page. A
/// phone and a tablet showing the same board have identical rows and columns
/// and differently sized cells, which preserves the relative motor plan when a
/// user moves between devices.
///
/// Vocabulary grows in two ways, neither of which disturbs an existing card:
/// by filling an empty cell, and by adding a page. Resizing the grid is the one
/// destructive option, and the editor warns about it accordingly.
///
/// Immutable. Every edit produces a new board, which makes undo a matter of
/// keeping the previous value rather than of reversing operations.
class Board {
  final String name;
  final int rows;
  final int cols;
  final List<BoardPage> pages;

  const Board({
    required this.name,
    required this.rows,
    required this.cols,
    required this.pages,
  });

  bool get isValid => rows > 0 && cols > 0 && pages.isNotEmpty;

  int get pageCount => pages.length;

  int get cellsPerPage => rows * cols;

  int get totalCards {
    int total = 0;

    for (final BoardPage page in pages) {
      total = total + page.cardCount;
    }

    return total;
  }

  /// Clamps [index] to a page that exists, so a stale page number can never
  /// leave the user looking at nothing.
  int clampPage(int index) {
    if (pages.isEmpty) {
      return 0;
    }

    if (index < 0) {
      return 0;
    }

    if (index >= pages.length) {
      return pages.length - 1;
    }

    return index;
  }

  BoardPage? pageAt(int index) {
    if (index < 0 || index >= pages.length) {
      return null;
    }

    return pages[index];
  }

  BoardCard? cardAt({required int page, required CellAddress? address}) {
    return pageAt(page)?.cardAt(address);
  }

  /// True when every cell on [page] is occupied.
  bool isPageFull(int page) {
    final BoardPage? target = pageAt(page);

    if (target == null) {
      return false;
    }

    return target.cardCount >= cellsPerPage;
  }

  bool get isLastPageFull => isPageFull(pages.length - 1);

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

  /// Adds or replaces a card on [page].
  ///
  /// Returns the board unchanged if the page or address is out of range, rather
  /// than throwing: a bad edit must never take the board down.
  Board withCard({required int page, required BoardCard? card}) {
    if (card == null) {
      return this;
    }

    if (isWithinGrid(card.address) == false) {
      return this;
    }

    final BoardPage? target = pageAt(page);

    if (target == null) {
      return this;
    }

    return _replacingPage(page, target.withCard(card));
  }

  /// Removes the card at [address] on [page], leaving the cell empty and in
  /// place.
  Board withoutCard({required int page, required CellAddress? address}) {
    if (address == null) {
      return this;
    }

    final BoardPage? target = pageAt(page);

    if (target == null) {
      return this;
    }

    return _replacingPage(page, target.withoutCard(address));
  }

  /// Moves a card within a page, refusing if the destination is occupied.
  ///
  /// Moving a populated cell breaks the motor plan the user has learned, so the
  /// editor must warn before calling this. The model enforces only that two
  /// cards cannot occupy one position.
  Board withMovedCard({
    required int page,
    required CellAddress? from,
    required CellAddress? to,
  }) {
    if (from == null || to == null || from == to) {
      return this;
    }

    final BoardPage? target = pageAt(page);

    if (target == null) {
      return this;
    }

    final BoardCard? moving = target.cardAt(from);

    if (moving == null) {
      return this;
    }

    if (isWithinGrid(to) == false) {
      return this;
    }

    if (target.cardAt(to) != null) {
      return this;
    }

    return _replacingPage(
      page,
      target.withoutCard(from).withCard(moving.copyWith(address: to)),
    );
  }

  /// Appends an empty page.
  ///
  /// This is how a board grows once a page is full. Nothing already placed
  /// moves, which is the whole point: adding vocabulary must never cost a
  /// learned motor path.
  Board withPageAdded() {
    return copyWith(pages: <BoardPage>[...pages, BoardPage.blank]);
  }

  /// Removes a page, reporting the cards that would go with it.
  ///
  /// Refuses to remove the last remaining page: a board with no pages has
  /// nowhere to put anything and nothing to show.
  ({Board board, List<BoardCard> removed}) withPageRemoved(int index) {
    if (pages.length <= 1) {
      return (board: this, removed: const <BoardCard>[]);
    }

    final BoardPage? target = pageAt(index);

    if (target == null) {
      return (board: this, removed: const <BoardCard>[]);
    }

    final List<BoardPage> next = <BoardPage>[...pages];
    next.removeAt(index);

    return (board: copyWith(pages: next), removed: target.cards);
  }

  /// Changes the grid dimensions, across every page.
  ///
  /// Cards falling outside the new bounds are returned in [orphaned] rather
  /// than silently deleted, so the editor can tell the parent exactly what a
  /// resize would cost before committing to it.
  ({Board board, List<BoardCard> orphaned}) resized({
    required int newRows,
    required int newCols,
  }) {
    if (newRows < 1 || newCols < 1) {
      return (board: this, orphaned: const <BoardCard>[]);
    }

    final List<BoardPage> keptPages = <BoardPage>[];
    final List<BoardCard> lost = <BoardCard>[];

    for (final BoardPage page in pages) {
      final List<BoardCard> kept = <BoardCard>[];

      for (final BoardCard card in page.cards) {
        final bool fits =
            card.address.row < newRows && card.address.col < newCols;

        if (fits) {
          kept.add(card);
          continue;
        }

        lost.add(card);
      }

      keptPages.add(BoardPage(cards: kept));
    }

    return (
      board: Board(name: name, rows: newRows, cols: newCols, pages: keptPages),
      orphaned: lost,
    );
  }

  Board _replacingPage(int index, BoardPage page) {
    final List<BoardPage> next = <BoardPage>[...pages];
    next[index] = page;

    return copyWith(pages: next);
  }

  Board copyWith({String? name, int? rows, int? cols, List<BoardPage>? pages}) {
    return Board(
      name: name ?? this.name,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      pages: pages ?? this.pages,
    );
  }

  /// Kyle's provisional starting board. See `docs/DESIGN.md` section 12.
  ///
  /// Three columns by two rows, sized from the measured 42 x 46 mm adult slap
  /// footprint scaled to a child's hand against the Fire HD 8's 172 x 108 mm
  /// panel. One page, four of its six cells filled: vocabulary grows by
  /// occupying empty cells and then by adding pages, never by resizing or
  /// rearranging, so a motor path learned now stays correct for years.
  ///
  /// The vocabulary itself is a placeholder. Choosing it is the speech and
  /// language therapy team's job, not ours.
  static const Board kyleStarter = Board(
    name: 'Kyle',
    rows: 2,
    cols: 3,
    pages: <BoardPage>[
      BoardPage(
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
      ),
    ],
  );

  @override
  String toString() =>
      'Board("$name", ${rows}x$cols, $pageCount page(s), $totalCards cards)';
}
