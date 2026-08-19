import 'dart:convert';
import 'dart:io';

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

/// The real index the app ships, so search behaviour is tested against the
/// actual 3,400-odd symbols rather than a convenient handful.
const String _bundledIndex = '../../app/assets/symbols/index.json';

String _indexJson(List<Map<String, Object?>> symbols) {
  return jsonEncode(<String, Object?>{
    'source': 'test',
    'licence': 'CC BY-SA 4.0',
    'symbols': symbols,
  });
}

Map<String, Object?> _symbol(
  String name, {
  String? file,
  String category = 'Test',
  String grammar = 'Noun',
  List<String> tags = const <String>[],
}) {
  return <String, Object?>{
    'file': file ?? '${name.replaceAll(' ', '_')}.svg',
    'name': name,
    'category': category,
    'grammar': grammar,
    'tags': tags,
  };
}

void main() {
  group('SymbolCatalog parsing', () {
    test('a damaged index costs the picker, not the app', () {
      // Cards keep working and the parent falls back to emoji.
      expect(SymbolCatalog.parse(null).isEmpty, isTrue);
      expect(SymbolCatalog.parse('').isEmpty, isTrue);
      expect(SymbolCatalog.parse('{{{ not json').isEmpty, isTrue);
      expect(SymbolCatalog.parse('[]').isEmpty, isTrue);
      expect(SymbolCatalog.parse('{"symbols": "nope"}').isEmpty, isTrue);
    });

    test('entries missing a file or name are skipped, not fatal', () {
      final SymbolCatalog catalog = SymbolCatalog.parse(
        _indexJson(<Map<String, Object?>>[
          _symbol('good'),
          <String, Object?>{'name': 'no file'},
          <String, Object?>{'file': 'no_name.svg'},
          _symbol('also good'),
        ]),
      );

      expect(catalog.count, 2);
    });

    test('categories are listed once and sorted', () {
      final SymbolCatalog catalog = SymbolCatalog.parse(
        _indexJson(<Map<String, Object?>>[
          _symbol('a', category: 'Food'),
          _symbol('b', category: 'Animals'),
          _symbol('c', category: 'Food'),
          _symbol('d', category: ''),
        ]),
      );

      expect(catalog.categories, <String>['Animals', 'Food']);
      expect(catalog.inCategory('food').length, 2);
      expect(catalog.inCategory(null), isEmpty);
      expect(catalog.inCategory(''), isEmpty);
    });

    test('lookup by file is case-insensitive and tolerates nothing', () {
      final SymbolCatalog catalog = SymbolCatalog.parse(
        _indexJson(<Map<String, Object?>>[_symbol('drink')]),
      );

      expect(catalog.byFile('DRINK.svg')!.name, 'drink');
      expect(catalog.byFile('missing.svg'), isNull);
      expect(catalog.byFile(null), isNull);
      expect(catalog.byFile('  '), isNull);
    });
  });

  group('SymbolCatalog search ranking', () {
    late SymbolCatalog catalog;

    setUp(() {
      catalog = SymbolCatalog.parse(
        _indexJson(<Map<String, Object?>>[
          _symbol('drink consistency honey cup'),
          _symbol('hot drink'),
          _symbol('drink large'),
          _symbol('drink'),
          _symbol('drink, to'),
          _symbol('juice', tags: <String>['drink', 'beverage']),
          _symbol('kitchen', category: 'Drink Type'),
        ]),
      );
    });

    test('an exact name wins', () {
      // Mulberry has fifteen symbols starting with "drink". A parent typing
      // "drink" must not have to scroll past "drink consistency honey cup".
      expect(catalog.search('drink').first.name, 'drink');
    });

    test('a name prefix beats a substring, and a tag beats a category', () {
      final List<String> names = catalog
          .search('drink')
          .map((SymbolEntry e) => e.name)
          .toList();

      expect(names.indexOf('drink'), 0);
      expect(
        names.indexOf('drink, to'),
        lessThan(names.indexOf('drink large')),
      );
      expect(
        names.indexOf('drink large'),
        lessThan(names.indexOf('hot drink')),
      );
      expect(names.indexOf('hot drink'), lessThan(names.indexOf('juice')));
      expect(names.indexOf('juice'), lessThan(names.indexOf('kitchen')));
    });

    test('shorter names come first within the same rank', () {
      final SymbolCatalog c = SymbolCatalog.parse(
        _indexJson(<Map<String, Object?>>[
          _symbol('cup of tea please'),
          _symbol('cup big'),
          _symbol('cup'),
        ]),
      );

      expect(c.search('cup').map((SymbolEntry e) => e.name).toList(), <String>[
        'cup',
        'cup big',
        'cup of tea please',
      ]);
    });

    test('search is case-insensitive and ignores surrounding space', () {
      expect(catalog.search('  DRINK  ').first.name, 'drink');
    });

    test('an empty or null query returns the catalogue', () {
      expect(catalog.search('').length, catalog.count);
      expect(catalog.search(null).length, catalog.count);
      expect(catalog.search('   ').length, catalog.count);
    });

    test('a query matching nothing returns nothing rather than everything', () {
      expect(catalog.search('zzzzznotasymbol'), isEmpty);
    });

    test('the limit is honoured', () {
      expect(catalog.search('drink', limit: 2).length, 2);
      expect(catalog.search('', limit: 3).length, 3);
      expect(catalog.search('drink', limit: 0), isEmpty);
    });
  });

  group('The bundled Mulberry set', () {
    late SymbolCatalog catalog;

    setUp(() {
      final File file = File(_bundledIndex);

      if (file.existsSync() == false) {
        throw StateError(
          'Bundled symbol index missing at $_bundledIndex. '
          'Run: dart run tools/import_symbols.dart <mulberry-repo>',
        );
      }

      catalog = SymbolCatalog.parse(file.readAsStringSync());
    });

    test('loads the whole set', () {
      expect(catalog.count, greaterThan(3000));
      expect(catalog.categories.length, greaterThan(50));
    });

    test('every entry has a file name and a readable name', () {
      for (final SymbolEntry entry in catalog.symbols) {
        expect(entry.file.endsWith('.svg'), isTrue, reason: entry.toString());
        expect(entry.name.trim(), isNotEmpty, reason: entry.toString());
      }
    });

    test('file names cannot escape the asset directory', () {
      for (final SymbolEntry entry in catalog.symbols) {
        expect(entry.file.contains('..'), isFalse, reason: entry.file);
        expect(entry.file.contains('/'), isFalse, reason: entry.file);
        expect(entry.file.contains(r'\'), isFalse, reason: entry.file);
      }
    });

    test('the everyday words the set does have are findable in one search', () {
      // If a parent cannot find these in one search, the ranking is not doing
      // its job, whatever the size of the set.
      for (final String word in <String>[
        'drink',
        'more',
        'toilet',
        'school',
        'car',
        'music',
        'outside',
        'finish',
        'correct',
        'wait',
      ]) {
        final List<SymbolEntry> hits = catalog.search(word, limit: 5);

        expect(hits, isNotEmpty, reason: 'nothing found for "$word"');
        expect(
          hits.first.name.toLowerCase(),
          contains(word),
          reason: 'best hit for "$word" was "${hits.first.name}"',
        );
      }
    });

    test('records the core vocabulary the set is missing', () {
      // Mulberry was designed with adult AAC users in mind and is far stronger
      // on nouns (2,973 of 3,436) than on core vocabulary. These everyday words
      // have no symbol at all, which is exactly why the emoji fallback is kept
      // rather than removed, and why this is flagged to the therapy team in
      // docs/FOR-CLINICIANS.md.
      //
      // This test exists to notice if a future import changes the situation in
      // either direction, rather than to assert that the gap is acceptable.
      const List<String> knownMissing = <String>[
        'yes',
        'no',
        'stop',
        'again',
        'please',
        'thank you',
        'hurt',
        'mum',
        'dad',
        'like',
      ];

      final List<String> unexpectedlyPresent = <String>[];

      for (final String word in knownMissing) {
        final List<SymbolEntry> hits = catalog.search(word, limit: 3);
        final bool exact = hits.any(
          (SymbolEntry e) => e.name.toLowerCase() == word,
        );

        if (exact) {
          unexpectedlyPresent.add(word);
        }
      }

      expect(
        unexpectedlyPresent,
        isEmpty,
        reason:
            'The symbol set now contains ${unexpectedlyPresent.join(', ')}. '
            'That is good news: update THIRD-PARTY-ASSETS.md and '
            'docs/FOR-CLINICIANS.md, and remove them from this list.',
      );
    });

    test('the set is dominated by nouns, which is why core words are thin', () {
      final int nouns = catalog.symbols
          .where((SymbolEntry e) => e.grammar.toLowerCase() == 'noun')
          .length;

      expect(nouns / catalog.count, greaterThan(0.7));
    });

    test('every indexed file exists on disk', () {
      final Directory svgDir = Directory('../../app/assets/symbols/svg');

      expect(svgDir.existsSync(), isTrue);

      final Set<String> onDisk = svgDir
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toSet();

      for (final SymbolEntry entry in catalog.symbols) {
        expect(onDisk.contains(entry.file), isTrue, reason: entry.file);
      }
    });
  });
}
