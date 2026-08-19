import 'dart:io';

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

BoardCard _photoCard({
  required String photoFile,
  ImageMode mode = ImageMode.photo,
  double blend = 0,
}) {
  return BoardCard(
    address: const CellAddress(row: 1, col: 1),
    label: 'cup',
    speech: 'my cup',
    glyph: 'C',
    colourArgb: 0xFF112233,
    photoFile: photoFile,
    imageMode: mode,
    blend: blend,
  );
}

void main() {
  group('Card artwork', () {
    test('a card with no photograph always shows its symbol', () {
      const BoardCard card = BoardCard(
        address: CellAddress(row: 0, col: 0),
        label: 'drink',
        speech: '',
        glyph: 'D',
        colourArgb: 0xFF000000,
        imageMode: ImageMode.photo,
      );

      // Removing a photograph must never leave a blank card.
      expect(card.hasPhoto, isFalse);
      expect(card.effectiveImageMode, ImageMode.symbol);
      expect(card.symbolOpacity, 1);
      expect(card.photoOpacity, 0);
    });

    test('blend cross-fades between the photograph and the symbol', () {
      // The staged transition the therapy team asked for: begin on the child's
      // own cup, end on the abstract symbol, without the card ever moving.
      BoardCard at(double blend) =>
          _photoCard(photoFile: 'cup.jpg', mode: ImageMode.blend, blend: blend);

      expect(at(0).photoOpacity, 1);
      expect(at(0).symbolOpacity, 0);
      expect(at(1).photoOpacity, 0);
      expect(at(1).symbolOpacity, 1);
      expect(at(0.25).photoOpacity, closeTo(0.75, 0.0001));
      expect(at(0.25).symbolOpacity, closeTo(0.25, 0.0001));
    });

    test('an out-of-range blend is clamped rather than trusted', () {
      BoardCard at(double blend) =>
          _photoCard(photoFile: 'a.jpg', mode: ImageMode.blend, blend: blend);

      expect(at(-3).symbolOpacity, 0);
      expect(at(-3).photoOpacity, 1);
      expect(at(9).symbolOpacity, 1);
      expect(at(9).photoOpacity, 0);
    });

    test('both mode draws the photograph and the symbol together', () {
      final BoardCard card = _photoCard(
        photoFile: 'cup.jpg',
        mode: ImageMode.both,
      );

      expect(card.photoOpacity, 1);
      expect(card.symbolOpacity, 1);
    });
  });

  group('Photo serialisation', () {
    test('photo fields survive a round trip', () {
      final Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _photoCard(
          photoFile: 'img_abc.jpg',
          mode: ImageMode.blend,
          blend: 0.4,
        ),
      );

      final BoardDecodeResult result = BoardCodec.decode(
        BoardCodec.encode(board),
      );

      final BoardCard restored = result.board!.cardAt(
        page: 0,
        address: const CellAddress(row: 1, col: 1),
      )!;

      expect(restored.photoFile, 'img_abc.jpg');
      expect(restored.imageMode, ImageMode.blend);
      expect(restored.blend, closeTo(0.4, 0.0001));
    });

    test('a board saved before photographs existed still loads', () {
      // Older files carry no photoFile, imageMode or blend keys at all, and a
      // parent who updates the app must not lose their board to that.
      const String legacy = '''
      {"schemaVersion": 1, "name": "Kyle", "rows": 1, "cols": 1, "cards": [
        {"row": 0, "col": 0, "label": "drink", "speech": "a drink",
         "glyph": "D", "colourArgb": 255}
      ]}
      ''';

      final BoardDecodeResult result = BoardCodec.decode(legacy);
      final BoardCard card = result.board!.pages.single.cards.single;

      expect(result.isClean, isTrue);
      expect(card.hasPhoto, isFalse);
      expect(card.effectiveImageMode, ImageMode.symbol);
    });

    test('an unknown image mode falls back rather than failing the card', () {
      final BoardDecodeResult result = BoardCodec.decode(
        '{"rows": 1, "cols": 1, "cards": [{"row": 0, "col": 0, '
        '"imageMode": "kaleidoscope"}]}',
      );

      expect(
        result.board!.pages.single.cards.single.imageMode,
        ImageMode.photo,
      );
    });
  });

  group('MediaStore', () {
    late Directory dir;
    late BoardRepository repo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kylesvoice_media_');
      repo = BoardRepository(directory: dir);
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('saving bytes returns a name that resolves to a real file', () async {
      final String name = await repo.media.save(bytes: <int>[1, 2, 3, 4, 5]);

      expect(name, isNotEmpty);
      expect(repo.media.exists(name), isTrue);
      expect(File(repo.media.pathFor(name)!).readAsBytesSync().length, 5);
    });

    test('saving leaves no temporary file behind', () async {
      await repo.media.save(bytes: <int>[1, 2, 3]);

      final List<String> names = repo.media.directory
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toList();

      expect(names.any((String n) => n.endsWith('.tmp')), isFalse);
    });

    test(
      'empty and null bytes are refused rather than creating a stub',
      () async {
        expect(await repo.media.save(bytes: null), isEmpty);
        expect(await repo.media.save(bytes: <int>[]), isEmpty);
      },
    );

    test('two saves never collide', () async {
      final String a = await repo.media.save(bytes: <int>[1]);
      final String b = await repo.media.save(bytes: <int>[2]);

      expect(a, isNot(b));
    });

    test('an ordinary extension is preserved', () async {
      final File source = File('${dir.path}${Platform.pathSeparator}shot.png');
      source.writeAsBytesSync(<int>[9, 9, 9]);

      expect(await repo.media.importFile(source.path), endsWith('.png'));
    });

    test(
      'an implausible extension falls back rather than being trusted',
      () async {
        // The stored name is always generated, so a source path can never steer
        // it. This checks the extension itself is also sanitised rather than
        // pasted through.
        for (final String odd in <String>['odd.a-b', 'odd.', 'oddnoext']) {
          final File source = File('${dir.path}${Platform.pathSeparator}$odd');
          source.writeAsBytesSync(<int>[9, 9, 9]);

          final String name = await repo.media.importFile(source.path);

          expect(name, endsWith('.jpg'), reason: 'for "$odd"');
          expect(name.contains('/'), isFalse, reason: 'for "$odd"');
          expect(name.contains(r'\'), isFalse, reason: 'for "$odd"');
          expect(name.contains('..'), isFalse, reason: 'for "$odd"');
        }
      },
    );

    test('importing a missing or empty path fails quietly', () async {
      expect(await repo.media.importFile('/no/such/file.jpg'), isEmpty);
      expect(await repo.media.importFile(null), isEmpty);
      expect(await repo.media.importFile('  '), isEmpty);
    });

    test('pathFor distinguishes no photograph from a missing one', () {
      expect(repo.media.pathFor(null), isNull);
      expect(repo.media.pathFor('  '), isNull);
      expect(repo.media.pathFor('gone.jpg'), isNotNull);
      expect(repo.media.exists('gone.jpg'), isFalse);
    });

    test('pruning removes only files no card refers to', () async {
      final String kept = await repo.media.save(bytes: <int>[1]);
      final String orphan = await repo.media.save(bytes: <int>[2]);

      final Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _photoCard(photoFile: kept),
      );

      expect(await repo.media.pruneOrphans(board), 1);
      expect(repo.media.exists(kept), isTrue);
      expect(repo.media.exists(orphan), isFalse);
    });

    test('deleting a card does not delete its photograph', () async {
      // Undo has to be able to bring the card back with its picture intact. A
      // stale image costs kilobytes; a lost one costs a parent the trip back to
      // wherever they took it.
      final String name = await repo.media.save(bytes: <int>[1]);

      Board board = Board.kyleStarter.withCard(
        page: 0,
        card: _photoCard(photoFile: name),
      );
      board = board.withoutCard(
        page: 0,
        address: const CellAddress(row: 1, col: 1),
      );
      await repo.save(board);

      expect(repo.media.exists(name), isTrue);
    });

    test('pruning a null board removes nothing', () async {
      final String name = await repo.media.save(bytes: <int>[1]);

      expect(await repo.media.pruneOrphans(null), 0);
      expect(repo.media.exists(name), isTrue);
    });

    test('media sits beside the board file, not inside it', () async {
      await repo.save(Board.kyleStarter);
      await repo.media.save(bytes: <int>[1]);

      expect(repo.media.directory.path, contains(MediaStore.directoryName));
      expect(repo.file.existsSync(), isTrue);
      expect(repo.media.directory.existsSync(), isTrue);
    });
  });
}
