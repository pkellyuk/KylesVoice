import 'dart:io';

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

BoardCard _card(int row, int col, String label) {
  return BoardCard(
    address: CellAddress(row: row, col: col),
    label: label,
    speech: 'I want $label',
    glyph: 'X',
    colourArgb: 0xFF112233,
  );
}

void main() {
  group('Board editing', () {
    test('adding a card leaves other cells untouched', () {
      final Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _card(1, 1, 'help'),
      );

      expect(board.totalCards, 5);
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 1))!
            .label,
        'help',
      );
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 0))!
            .label,
        'drink',
      );
    });

    test('adding to an occupied cell replaces only that card', () {
      final Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _card(0, 0, 'juice'),
      );

      expect(board.totalCards, 4);
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 0))!
            .label,
        'juice',
      );
    });

    test('a card outside the grid is refused rather than throwing', () {
      final Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _card(9, 9, 'nowhere'),
      );

      expect(board.totalCards, Board.kyleStarter.totalCards);
    });

    test('removing a card leaves the cell empty and in place', () {
      final Board board = Board.kyleStarter.withoutCard(
        page: 0,
        address: const CellAddress(row: 0, col: 0),
      );

      expect(
        board.cardAt(page: 0, address: const CellAddress(row: 0, col: 0)),
        isNull,
      );
      // Crucially the grid does not shrink and nothing shuffles up into the gap.
      expect(board.rows, 2);
      expect(board.cols, 3);
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 1))!
            .label,
        'eat',
      );
    });

    test('moving onto an occupied cell is refused', () {
      final Board board = Board.kyleStarter.withMovedCard(
        page: 0,
        from: const CellAddress(row: 0, col: 0),
        to: const CellAddress(row: 0, col: 1),
      );

      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 0))!
            .label,
        'drink',
      );
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 1))!
            .label,
        'eat',
      );
    });

    test('moving to an empty cell succeeds', () {
      final Board board = Board.kyleStarter.withMovedCard(
        page: 0,
        from: const CellAddress(row: 0, col: 0),
        to: const CellAddress(row: 1, col: 1),
      );

      expect(
        board.cardAt(page: 0, address: const CellAddress(row: 0, col: 0)),
        isNull,
      );
      expect(
        board
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 1))!
            .label,
        'drink',
      );
    });

    test('shrinking the grid reports what would be lost instead of deleting it', () {
      // The editor has to be able to tell a parent exactly what a resize costs
      // before it happens. Silently dropping cards would be unforgivable.
      final ({Board board, List<BoardCard> orphaned}) result = Board.kyleStarter
          .resized(newRows: 2, newCols: 2);

      expect(result.orphaned.length, 1);
      expect(result.orphaned.first.label, 'finished');
      expect(result.board.cols, 2);
      expect(result.board.totalCards, 3);
    });

    test('growing the grid keeps every card at its existing address', () {
      final ({Board board, List<BoardCard> orphaned}) result = Board.kyleStarter
          .resized(newRows: 4, newCols: 5);

      expect(result.orphaned, isEmpty);
      expect(
        result.board
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 2))!
            .label,
        'finished',
      );
    });

    test('speech falls back to the label when no phrase is given', () {
      const BoardCard card = BoardCard(
        address: CellAddress(row: 0, col: 0),
        label: 'toilet',
        speech: '   ',
        glyph: 'X',
        colourArgb: 0xFF000000,
      );

      expect(card.effectiveSpeech, 'toilet');
    });
  });

  group('BoardCodec', () {
    test('a board survives a round trip unchanged', () {
      final BoardDecodeResult result = BoardCodec.decode(
        BoardCodec.encode(Board.kyleStarter),
      );

      expect(result.isClean, isTrue);
      expect(result.board!.name, 'Kyle');
      expect(result.board!.rows, 2);
      expect(result.board!.cols, 3);
      expect(result.board!.totalCards, 4);

      for (final BoardCard original in Board.kyleStarter.pages.single.cards) {
        expect(
          result.board!.cardAt(page: 0, address: original.address),
          original,
        );
      }
    });

    test('empty and null input are reported, not thrown', () {
      expect(BoardCodec.decode(null).succeeded, isFalse);
      expect(BoardCodec.decode('').succeeded, isFalse);
      expect(BoardCodec.decode('   ').problems, isNotEmpty);
    });

    test('malformed JSON is reported, not thrown', () {
      final BoardDecodeResult result = BoardCodec.decode('{not json');

      expect(result.succeeded, isFalse);
      expect(result.problems.first, contains('not valid JSON'));
    });

    test('one bad card is dropped rather than losing the whole board', () {
      // Losing a vocabulary built over months because of a single corrupt entry
      // would be the worst possible failure mode.
      const String json = '''
      {
        "schemaVersion": 1,
        "name": "Kyle",
        "rows": 2,
        "cols": 3,
        "cards": [
          {"row": 0, "col": 0, "label": "drink", "speech": "a drink",
           "glyph": "D", "colourArgb": 255},
          "this is not a card",
          {"row": 9, "col": 9, "label": "offgrid", "speech": "x",
           "glyph": "O", "colourArgb": 255},
          {"row": 1, "col": 1, "label": "more", "speech": "more please",
           "glyph": "M", "colourArgb": 255}
        ]
      }
      ''';

      final BoardDecodeResult result = BoardCodec.decode(json);

      expect(result.succeeded, isTrue);
      expect(result.board!.totalCards, 2);
      expect(result.problems.length, 2);
      expect(
        result.board!
            .cardAt(page: 0, address: const CellAddress(row: 0, col: 0))!
            .label,
        'drink',
      );
      expect(
        result.board!
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 1))!
            .label,
        'more',
      );
    });

    test('duplicate positions are resolved rather than creating two cards', () {
      const String json = '''
      {"schemaVersion": 1, "name": "x", "rows": 1, "cols": 1, "cards": [
        {"row": 0, "col": 0, "label": "first", "speech": "", "glyph": "",
         "colourArgb": 1},
        {"row": 0, "col": 0, "label": "second", "speech": "", "glyph": "",
         "colourArgb": 1}
      ]}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(json);

      expect(result.board!.totalCards, 1);
      expect(result.board!.pages.single.cards.first.label, 'first');
      expect(result.problems.single, contains('Two cards on board claimed'));
    });

    test('a board with no usable grid is refused', () {
      final BoardDecodeResult result = BoardCodec.decode(
        '{"rows": 0, "cols": 0, "cards": []}',
      );

      expect(result.succeeded, isFalse);
    });

    test('a newer schema is read as far as possible, with a warning', () {
      const String json = '''
      {"schemaVersion": 999, "name": "x", "rows": 1, "cols": 1, "cards": []}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(json);

      expect(result.succeeded, isTrue);
      expect(result.problems.single, contains('newer version'));
    });

    test('missing optional fields fall back to sane defaults', () {
      final BoardDecodeResult result = BoardCodec.decode(
        '{"rows": 1, "cols": 1, "cards": [{"row": 0, "col": 0}]}',
      );

      final BoardCard card = result.board!.pages.single.cards.single;

      expect(card.label, '');
      expect(card.kind, CardKind.speak);
      expect(card.rowSpan, 1);
      expect(card.hidden, isFalse);
    });
  });

  group('BoardRepository', () {
    late Directory dir;
    late BoardRepository repo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kylesvoice_test_');
      repo = BoardRepository(directory: dir);
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('with nothing saved, the seed board is returned', () async {
      final BoardLoadResult result = await repo.load();

      expect(result.wasRestored, isFalse);
      expect(result.board.name, 'Kyle');
      expect(result.problems, isEmpty);
    });

    test('a saved board is restored exactly', () async {
      final Board edited = Board.kyleStarter
          .withCard(page: 0, card: _card(1, 1, 'help'))
          .copyWith(name: 'Kyle v2');

      expect(await repo.save(edited), isEmpty);

      final BoardLoadResult result = await repo.load();

      expect(result.wasRestored, isTrue);
      expect(result.board.name, 'Kyle v2');
      expect(result.board.totalCards, 5);
      expect(
        result.board
            .cardAt(page: 0, address: const CellAddress(row: 1, col: 1))!
            .label,
        'help',
      );
    });

    test('saving leaves no temporary file behind', () async {
      await repo.save(Board.kyleStarter);

      expect(repo.file.existsSync(), isTrue);
      expect(repo.tempFile.existsSync(), isFalse);
    });

    test('the previous board is kept as a backup', () async {
      await repo.save(Board.kyleStarter);
      await repo.save(Board.kyleStarter.copyWith(name: 'second'));

      expect(repo.backupFile.existsSync(), isTrue);

      final BoardDecodeResult backup = BoardCodec.decode(
        repo.backupFile.readAsStringSync(),
      );

      expect(backup.board!.name, 'Kyle');
    });

    test('a corrupted main file falls back to the backup', () async {
      await repo.save(Board.kyleStarter);
      await repo.save(Board.kyleStarter.copyWith(name: 'second'));

      // Simulate a file damaged by, say, the device dying mid-write.
      repo.file.writeAsStringSync('{{{ this is not json');

      final BoardLoadResult result = await repo.load();

      expect(result.usedBackup, isTrue);
      expect(result.board.name, 'Kyle');
      expect(result.problems.any((String p) => p.contains('backup')), isTrue);
    });

    test(
      'with both files corrupt, the seed is returned rather than nothing',
      () async {
        await repo.save(Board.kyleStarter);
        await repo.save(Board.kyleStarter.copyWith(name: 'second'));

        repo.file.writeAsStringSync('rubbish');
        repo.backupFile.writeAsStringSync('also rubbish');

        final BoardLoadResult result = await repo.load();

        // The user is left with a working board no matter what.
        expect(result.board.pages.single.cards, isNotEmpty);
        expect(result.wasRestored, isFalse);
      },
    );

    test('a truncated file still yields the cards that survived', () async {
      const String partial = '''
      {"schemaVersion": 1, "name": "Kyle", "rows": 2, "cols": 3, "cards": [
        {"row": 0, "col": 0, "label": "drink", "speech": "a drink",
         "glyph": "D", "colourArgb": 255},
        {"row": 1, "col": 1}
      ]}
      ''';

      repo.file.writeAsStringSync(partial);

      final BoardLoadResult result = await repo.load();

      expect(result.wasRestored, isTrue);
      expect(result.board.totalCards, 2);
    });

    test('saving a null or invalid board is refused with a reason', () async {
      expect(await repo.save(null), isNotEmpty);
      expect(
        await repo.save(
          const Board(name: 'x', rows: 0, cols: 0, pages: <BoardPage>[]),
        ),
        isNotEmpty,
      );
    });

    test('the directory is created if it does not exist', () async {
      final Directory nested = Directory(
        '${dir.path}${Platform.pathSeparator}deeper',
      );
      final BoardRepository nestedRepo = BoardRepository(directory: nested);

      expect(await nestedRepo.save(Board.kyleStarter), isEmpty);
      expect(nestedRepo.file.existsSync(), isTrue);
    });

    test('repeated saves keep working', () async {
      for (int i = 0; i < 5; i = i + 1) {
        expect(
          await repo.save(Board.kyleStarter.copyWith(name: 'save $i')),
          isEmpty,
        );
      }

      expect((await repo.load()).board.name, 'save 4');
    });
  });
}
