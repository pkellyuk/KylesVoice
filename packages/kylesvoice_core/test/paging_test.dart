import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

const CellAddress _topLeft = CellAddress(row: 0, col: 0);

BoardCard _card(int row, int col, String label) {
  return BoardCard(
    address: CellAddress(row: row, col: col),
    label: label,
    speech: '',
    glyph: 'X',
    colourArgb: 0xFF112233,
  );
}

/// A 2x2 board whose single page is completely full.
Board _fullBoard() {
  Board board = const Board(
    name: 'full',
    rows: 2,
    cols: 2,
    pages: <BoardPage>[BoardPage.blank],
  );

  for (int r = 0; r < 2; r = r + 1) {
    for (int c = 0; c < 2; c = c + 1) {
      board = board.withCard(page: 0, card: _card(r, c, 'r${r}c$c'));
    }
  }

  return board;
}

void main() {
  group('Pages', () {
    test('a new board has exactly one page', () {
      expect(Board.kyleStarter.pageCount, 1);
      expect(Board.kyleStarter.totalCards, 4);
    });

    test('adding a page disturbs nothing already placed', () {
      // The whole point: growing the vocabulary must never cost a learned
      // motor path.
      final Board grown = Board.kyleStarter.withPageAdded();

      expect(grown.pageCount, 2);
      expect(grown.rows, Board.kyleStarter.rows);
      expect(grown.cols, Board.kyleStarter.cols);

      for (final BoardCard original in Board.kyleStarter.pages.single.cards) {
        expect(
          grown.cardAt(page: 0, address: original.address),
          original,
          reason: 'card at ${original.address} moved',
        );
      }

      expect(grown.pageAt(1)!.isEmpty, isTrue);
    });

    test('a full page is reported as full, and an empty one is not', () {
      final Board full = _fullBoard();

      expect(full.isPageFull(0), isTrue);
      expect(full.isLastPageFull, isTrue);

      final Board grown = full.withPageAdded();

      expect(grown.isPageFull(0), isTrue);
      expect(grown.isPageFull(1), isFalse);
      expect(grown.isLastPageFull, isFalse);
    });

    test('cards on different pages may share an address', () {
      // Position is identity within a page. "Top left on page two" is a
      // different card from "top left on page one", and both keep their place.
      final Board board = Board.kyleStarter.withPageAdded().withCard(
        page: 1,
        card: _card(0, 0, 'second page word'),
      );

      expect(board.cardAt(page: 0, address: _topLeft)!.label, 'drink');
      expect(
        board.cardAt(page: 1, address: _topLeft)!.label,
        'second page word',
      );
    });

    test('editing one page leaves the others alone', () {
      final Board board = Board.kyleStarter
          .withPageAdded()
          .withCard(page: 1, card: _card(0, 0, 'other'))
          .withoutCard(page: 0, address: _topLeft);

      expect(board.cardAt(page: 0, address: _topLeft), isNull);
      expect(board.cardAt(page: 1, address: _topLeft)!.label, 'other');
    });

    test('an out-of-range page is refused rather than throwing', () {
      final Board board = Board.kyleStarter.withCard(
        page: 9,
        card: _card(0, 2, 'nowhere'),
      );

      expect(board.totalCards, Board.kyleStarter.totalCards);
      expect(board.pageAt(9), isNull);
      expect(board.cardAt(page: 9, address: _topLeft), isNull);
    });

    test('removing a page reports the cards that go with it', () {
      final Board board = Board.kyleStarter.withPageAdded().withCard(
        page: 1,
        card: _card(0, 0, 'doomed'),
      );

      final ({Board board, List<BoardCard> removed}) result = board
          .withPageRemoved(1);

      expect(result.removed.single.label, 'doomed');
      expect(result.board.pageCount, 1);
      expect(result.board.totalCards, 4);
    });

    test('the last page cannot be removed', () {
      // A board with no pages has nowhere to put anything and nothing to show.
      final ({Board board, List<BoardCard> removed}) result = Board.kyleStarter
          .withPageRemoved(0);

      expect(result.board.pageCount, 1);
      expect(result.removed, isEmpty);
    });

    test('a stale page number is clamped to one that exists', () {
      expect(Board.kyleStarter.clampPage(-4), 0);
      expect(Board.kyleStarter.clampPage(0), 0);
      expect(Board.kyleStarter.clampPage(7), 0);
      expect(Board.kyleStarter.withPageAdded().clampPage(7), 1);
    });

    test('resizing applies to every page and reports every orphan', () {
      final Board board = Board.kyleStarter.withPageAdded().withCard(
        page: 1,
        card: _card(1, 2, 'corner'),
      );

      final ({Board board, List<BoardCard> orphaned}) result = board.resized(
        newRows: 2,
        newCols: 2,
      );

      expect(result.board.pageCount, 2);
      expect(result.orphaned.map((BoardCard c) => c.label).toSet(), <String>{
        'finished',
        'corner',
      });
    });
  });

  group('Paged persistence', () {
    test('pages survive a round trip', () {
      final Board board = Board.kyleStarter.withPageAdded().withCard(
        page: 1,
        card: _card(0, 1, 'page two word'),
      );

      final BoardDecodeResult result = BoardCodec.decode(
        BoardCodec.encode(board),
      );

      expect(result.isClean, isTrue);
      expect(result.board!.pageCount, 2);
      expect(
        result.board!
            .cardAt(page: 1, address: const CellAddress(row: 0, col: 1))!
            .label,
        'page two word',
      );
      expect(result.board!.cardAt(page: 0, address: _topLeft)!.label, 'drink');
    });

    test('a board saved before pages existed is read as page one', () {
      // Kyle's board is already on a tablet in the old shape. Updating the app
      // must not cost him a single card.
      const String schemaOne = '''
      {"schemaVersion": 1, "name": "Kyle", "rows": 2, "cols": 3, "cards": [
        {"row": 0, "col": 0, "label": "drink", "speech": "I want a drink",
         "glyph": "D", "colourArgb": 255},
        {"row": 1, "col": 1, "label": "help", "speech": "help me",
         "glyph": "H", "colourArgb": 255}
      ]}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(schemaOne);

      expect(result.isClean, isTrue);
      expect(result.board!.pageCount, 1);
      expect(result.board!.totalCards, 2);
      expect(result.board!.cardAt(page: 0, address: _topLeft)!.label, 'drink');
      expect(
        result.board!
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 1))!
            .label,
        'help',
      );
    });

    test(
      'a board with neither pages nor cards still has somewhere to write',
      () {
        final BoardDecodeResult result = BoardCodec.decode(
          '{"schemaVersion": 2, "name": "x", "rows": 2, "cols": 2}',
        );

        expect(result.board!.pageCount, 1);
        expect(result.board!.isValid, isTrue);
      },
    );

    test('an unreadable page is dropped without losing the others', () {
      const String json = '''
      {"schemaVersion": 2, "name": "x", "rows": 1, "cols": 1, "pages": [
        {"cards": [{"row": 0, "col": 0, "label": "kept"}]},
        "this is not a page",
        {"cards": [{"row": 0, "col": 0, "label": "also kept"}]}
      ]}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(json);

      expect(result.board!.pageCount, 2);
      expect(result.problems.single, contains('Page 2'));
    });

    test('problems name the page they came from', () {
      const String json = '''
      {"schemaVersion": 2, "name": "x", "rows": 1, "cols": 1, "pages": [
        {"cards": []},
        {"cards": [{"row": 9, "col": 9, "label": "offgrid"}]}
      ]}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(json);

      expect(result.problems.single, contains('page 2'));
    });
  });
}
