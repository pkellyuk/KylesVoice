import 'dart:convert';

/// One symbol in the bundled set.
class SymbolEntry {
  /// File name within the symbol asset directory, e.g. `drink.svg`.
  final String file;

  /// Readable name, e.g. "drink, to".
  final String name;

  /// Mulberry's own grouping, e.g. "Drink Type".
  final String category;

  /// Part of speech, e.g. "Noun" or "Verb".
  ///
  /// Carried through because Fitzgerald colour coding assigns colours by part
  /// of speech, so this is what a future colour-coding feature will key off.
  final String grammar;

  final List<String> tags;

  const SymbolEntry({
    required this.file,
    required this.name,
    required this.category,
    required this.grammar,
    required this.tags,
  });

  @override
  String toString() => 'SymbolEntry($name -> $file)';
}

/// The bundled symbol set, searchable.
///
/// Pure Dart with no asset loading of its own: the app hands it the index
/// contents. That keeps searching and ranking testable headlessly, which
/// matters because a parent who cannot find "toilet" in three seconds will give
/// up and use an emoji instead.
class SymbolCatalog {
  final List<SymbolEntry> symbols;

  const SymbolCatalog({required this.symbols});

  static const SymbolCatalog empty = SymbolCatalog(symbols: <SymbolEntry>[]);

  bool get isEmpty => symbols.isEmpty;

  int get count => symbols.length;

  /// Parses the generated index. Never throws.
  ///
  /// A damaged index costs the symbol picker, not the app: cards keep working
  /// and the parent falls back to emoji.
  static SymbolCatalog parse(String? json) {
    if (json == null) {
      return empty;
    }

    if (json.trim().isEmpty) {
      return empty;
    }

    try {
      final Object? raw = jsonDecode(json);

      if (raw is! Map) {
        return empty;
      }

      final Object? list = raw['symbols'];

      if (list is! List) {
        return empty;
      }

      final List<SymbolEntry> entries = <SymbolEntry>[];

      for (final Object? item in list) {
        if (item is! Map) {
          continue;
        }

        final String file = _asString(item['file']);
        final String name = _asString(item['name']);

        if (file.isEmpty || name.isEmpty) {
          continue;
        }

        entries.add(
          SymbolEntry(
            file: file,
            name: name,
            category: _asString(item['category']),
            grammar: _asString(item['grammar']),
            tags: _asTags(item['tags']),
          ),
        );
      }

      return SymbolCatalog(symbols: entries);
    } catch (_) {
      return empty;
    }
  }

  /// Every category present, sorted.
  List<String> get categories {
    final Set<String> found = <String>{};

    for (final SymbolEntry entry in symbols) {
      if (entry.category.isEmpty) {
        continue;
      }

      found.add(entry.category);
    }

    final List<String> sorted = found.toList();
    sorted.sort();

    return sorted;
  }

  List<SymbolEntry> inCategory(String? category) {
    if (category == null || category.isEmpty) {
      return const <SymbolEntry>[];
    }

    return symbols
        .where(
          (SymbolEntry e) => e.category.toLowerCase() == category.toLowerCase(),
        )
        .toList(growable: false);
  }

  SymbolEntry? byFile(String? file) {
    if (file == null || file.trim().isEmpty) {
      return null;
    }

    final String wanted = file.trim().toLowerCase();

    for (final SymbolEntry entry in symbols) {
      if (entry.file.toLowerCase() == wanted) {
        return entry;
      }
    }

    return null;
  }

  /// Searches by name, tag and category, best matches first.
  ///
  /// Ranking matters more than it might appear. Mulberry has fifteen symbols
  /// whose names begin with "drink", so a plain substring match buries the plain
  /// one under "drink consistency honey cup". The order here is: exact name,
  /// then name prefix, then whole-word match within the name, then substring,
  /// then tags, then category.
  List<SymbolEntry> search(String? query, {int limit = 200}) {
    if (query == null) {
      return _firstN(symbols, limit);
    }

    final String needle = query.trim().toLowerCase();

    if (needle.isEmpty) {
      return _firstN(symbols, limit);
    }

    final List<({SymbolEntry entry, int rank})> scored =
        <({SymbolEntry entry, int rank})>[];

    for (final SymbolEntry entry in symbols) {
      final int rank = _rank(entry, needle);

      if (rank < 0) {
        continue;
      }

      scored.add((entry: entry, rank: rank));
    }

    scored.sort((
      ({SymbolEntry entry, int rank}) a,
      ({SymbolEntry entry, int rank}) b,
    ) {
      if (a.rank != b.rank) {
        return a.rank.compareTo(b.rank);
      }

      // Shorter names first within a rank, so "drink" beats "drink large".
      if (a.entry.name.length != b.entry.name.length) {
        return a.entry.name.length.compareTo(b.entry.name.length);
      }

      return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
    });

    return _firstN(
      scored.map((({SymbolEntry entry, int rank}) s) => s.entry).toList(),
      limit,
    );
  }

  /// Lower is better. Negative means no match.
  static int _rank(SymbolEntry entry, String needle) {
    final String name = entry.name.toLowerCase();

    if (name == needle) {
      return 0;
    }

    if (name.startsWith('$needle ') || name.startsWith('$needle,')) {
      return 1;
    }

    if (name.startsWith(needle)) {
      return 2;
    }

    if (_containsWord(name, needle)) {
      return 3;
    }

    if (name.contains(needle)) {
      return 4;
    }

    for (final String tag in entry.tags) {
      if (tag == needle) {
        return 5;
      }
    }

    for (final String tag in entry.tags) {
      if (tag.contains(needle)) {
        return 6;
      }
    }

    if (entry.category.toLowerCase().contains(needle)) {
      return 7;
    }

    return -1;
  }

  static bool _containsWord(String haystack, String needle) {
    final int index = haystack.indexOf(needle);

    if (index < 0) {
      return false;
    }

    final bool startsWord = index == 0 || haystack[index - 1] == ' ';
    final int end = index + needle.length;
    final bool endsWord = end == haystack.length || haystack[end] == ' ';

    return startsWord && endsWord;
  }

  static List<SymbolEntry> _firstN(List<SymbolEntry> source, int limit) {
    if (limit <= 0) {
      return const <SymbolEntry>[];
    }

    if (source.length <= limit) {
      return List<SymbolEntry>.unmodifiable(source);
    }

    return List<SymbolEntry>.unmodifiable(source.sublist(0, limit));
  }

  static String _asString(Object? value) {
    if (value is String) {
      return value;
    }

    if (value == null) {
      return '';
    }

    return value.toString();
  }

  static List<String> _asTags(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .where((Object? e) => e != null)
        .map((Object? e) => e.toString().toLowerCase())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
