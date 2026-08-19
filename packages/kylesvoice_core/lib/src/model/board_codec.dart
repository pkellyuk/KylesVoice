import 'dart:convert';

import '../grid/grid_geometry.dart';
import 'board.dart';
import 'board_card.dart';

/// The outcome of decoding a board, carrying any problems found.
///
/// Decoding never throws. A parent whose board file has been damaged must not
/// be met with a crash: they should get whatever survived, plus a clear list of
/// what did not.
class BoardDecodeResult {
  final Board? board;
  final List<String> problems;

  const BoardDecodeResult({required this.board, required this.problems});

  bool get succeeded => board != null;

  bool get isClean => board != null && problems.isEmpty;
}

/// Reads and writes boards as JSON.
///
/// JSON rather than a relational schema, deliberately. A board is a few dozen
/// cards, so there is nothing to gain from partial updates, and a single
/// document has real advantages here: it is written atomically, it is the same
/// representation used for export and for home-to-school transfer, and it can be
/// inspected and repaired by hand. One representation instead of two means less
/// to keep in step on the path between a child and their voice.
///
/// This supersedes the SQLite sketch in `docs/DATA-MODEL.md`, which was written
/// before the data volume was clear.
class BoardCodec {
  /// Bumped whenever the on-disk shape changes in a way that needs migration.
  static const int schemaVersion = 1;

  static String encode(Board? board) {
    if (board == null) {
      return '';
    }

    return const JsonEncoder.withIndent('  ').convert(toJson(board));
  }

  static Map<String, Object?> toJson(Board board) {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'name': board.name,
      'rows': board.rows,
      'cols': board.cols,
      'cards': board.cards
          .map(
            (BoardCard c) => <String, Object?>{
              'row': c.address.row,
              'col': c.address.col,
              'label': c.label,
              'speech': c.speech,
              'glyph': c.glyph,
              'symbolFile': c.symbolFile,
              'colourArgb': c.colourArgb,
              'photoFile': c.photoFile,
              'imageMode': c.imageMode.name,
              'blend': c.blend,
              'kind': c.kind.name,
              'rowSpan': c.rowSpan,
              'colSpan': c.colSpan,
              'hidden': c.hidden,
            },
          )
          .toList(),
    };
  }

  /// Decodes a board from JSON text.
  ///
  /// Salvages what it can: a single malformed card is dropped and reported
  /// rather than failing the whole board, because losing one card is far better
  /// than losing a vocabulary built over months.
  static BoardDecodeResult decode(String? text) {
    if (text == null) {
      return const BoardDecodeResult(
        board: null,
        problems: <String>['No data to read.'],
      );
    }

    if (text.trim().isEmpty) {
      return const BoardDecodeResult(
        board: null,
        problems: <String>['File was empty.'],
      );
    }

    final List<String> problems = <String>[];
    Object? raw;

    try {
      raw = jsonDecode(text);
    } catch (e) {
      return BoardDecodeResult(
        board: null,
        problems: <String>['File is not valid JSON: $e'],
      );
    }

    if (raw is! Map) {
      return const BoardDecodeResult(
        board: null,
        problems: <String>['File does not contain a board.'],
      );
    }

    final int version = _asInt(raw['schemaVersion'], 0);

    if (version > schemaVersion) {
      problems.add(
        'Board was written by a newer version of the app '
        '(schema $version, this app understands $schemaVersion). '
        'Some settings may be missing.',
      );
    }

    final int rows = _asInt(raw['rows'], 0);
    final int cols = _asInt(raw['cols'], 0);

    if (rows < 1 || cols < 1) {
      return BoardDecodeResult(
        board: null,
        problems: <String>[
          ...problems,
          'Board has no usable grid ($rows x $cols).',
        ],
      );
    }

    final List<BoardCard> cards = <BoardCard>[];
    final Set<CellAddress> seen = <CellAddress>{};
    final Object? rawCards = raw['cards'];

    if (rawCards is List) {
      for (int i = 0; i < rawCards.length; i = i + 1) {
        final Object? entry = rawCards[i];

        if (entry is! Map) {
          problems.add('Card $i was not readable and has been dropped.');
          continue;
        }

        final int row = _asInt(entry['row'], -1);
        final int col = _asInt(entry['col'], -1);

        if (row < 0 || row >= rows || col < 0 || col >= cols) {
          problems.add(
            'Card $i sat outside the grid at row $row, column $col, '
            'and has been dropped.',
          );
          continue;
        }

        final CellAddress address = CellAddress(row: row, col: col);

        if (seen.contains(address)) {
          problems.add(
            'Two cards claimed row $row, column $col. The later one was dropped.',
          );
          continue;
        }

        seen.add(address);

        cards.add(
          BoardCard(
            address: address,
            label: _asString(entry['label'], ''),
            speech: _asString(entry['speech'], ''),
            glyph: _asString(entry['glyph'], ''),
            symbolFile: _asString(entry['symbolFile'], ''),
            colourArgb: _asInt(entry['colourArgb'], 0xFF4FA3D1),
            photoFile: _asString(entry['photoFile'], ''),
            imageMode: _asImageMode(entry['imageMode']),
            blend: _asDouble(entry['blend'], 0).clamp(0.0, 1.0),
            kind: _asKind(entry['kind']),
            rowSpan: _asInt(entry['rowSpan'], 1).clamp(1, rows),
            colSpan: _asInt(entry['colSpan'], 1).clamp(1, cols),
            hidden: entry['hidden'] == true,
          ),
        );
      }
    } else if (rawCards != null) {
      problems.add('Card list was not readable; the board is empty.');
    }

    return BoardDecodeResult(
      board: Board(
        name: _asString(raw['name'], 'Board'),
        rows: rows,
        cols: cols,
        cards: cards,
      ),
      problems: problems,
    );
  }

  static ImageMode _asImageMode(Object? value) {
    final String name = _asString(value, ImageMode.photo.name);

    for (final ImageMode mode in ImageMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }

    return ImageMode.photo;
  }

  static double _asDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static CardKind _asKind(Object? value) {
    final String name = _asString(value, CardKind.speak.name);

    for (final CardKind kind in CardKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }

    return CardKind.speak;
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static String _asString(Object? value, String fallback) {
    if (value is String) {
      return value;
    }

    if (value == null) {
      return fallback;
    }

    return value.toString();
  }
}
