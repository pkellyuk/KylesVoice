// Imports the Mulberry Symbol set into the app's assets.
//
// Run from the repository root:
//
//   dart run tools/import_symbols.dart <path-to-mulberry-repo>
//
// Mulberry Symbols are by Garry Paxton (2008-2017) and Steve Lee (2018-),
// licensed CC BY-SA 4.0, from https://github.com/mulberrysymbols/mulberry-symbols
//
// The set is imported rather than vendored by hand so that the provenance of
// every file is reproducible, and so a future contributor can re-run this
// against a newer release without guessing what was done last time.
//
// Deliberately standalone: no package dependencies, so it runs with a bare
// `dart run` and does not drag the asset pipeline into the app's dependency
// graph.

import 'dart:convert';
import 'dart:io';

const String _svgOutputDirectory = 'app/assets/symbols/svg';
const String _indexOutputFile = 'app/assets/symbols/index.json';
const String _licenceOutputFile = 'app/assets/symbols/LICENSE.txt';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tools/import_symbols.dart <path-to-mulberry-repo>',
    );
    exitCode = 2;
    return;
  }

  final Directory source = Directory(args.first);

  if (source.existsSync() == false) {
    stderr.writeln('Source repository not found: ${source.path}');
    exitCode = 2;
    return;
  }

  final Directory svgSource = Directory('${source.path}/EN');
  final File csvSource = File('${source.path}/scripts/data/symbol-info.csv');
  final File licenceSource = File('${source.path}/LICENSE.txt');

  for (final FileSystemEntity required in <FileSystemEntity>[
    svgSource,
    csvSource,
    licenceSource,
  ]) {
    if (required.existsSync() == false) {
      stderr.writeln('Expected to find ${required.path}, but it is missing.');
      exitCode = 2;
      return;
    }
  }

  final Map<String, String> availableFiles = _indexSvgFiles(svgSource);
  stdout.writeln('Found ${availableFiles.length} SVG files.');

  final List<Map<String, Object?>> entries = <Map<String, Object?>>[];
  final List<String> unmatched = <String>[];
  final Set<String> usedFiles = <String>{};

  for (final List<String> row in _readCsv(csvSource)) {
    final Map<String, Object?>? entry = _entryFor(row, availableFiles);

    if (entry == null) {
      unmatched.add(row.isEmpty ? '<empty row>' : row.join(','));
      continue;
    }

    entries.add(entry);
    usedFiles.add(entry['file']! as String);
  }

  // Files present on disk but absent from the metadata still deserve to be
  // searchable: a missing catalogue row should not hide a usable symbol.
  for (final MapEntry<String, String> file in availableFiles.entries) {
    if (usedFiles.contains(file.value)) {
      continue;
    }

    entries.add(<String, Object?>{
      'file': file.value,
      'name': _humanise(file.key),
      'category': '',
      'grammar': '',
      'tags': <String>[],
    });
  }

  entries.sort(
    (Map<String, Object?> a, Map<String, Object?> b) =>
        (a['name']! as String).toLowerCase().compareTo(
          (b['name']! as String).toLowerCase(),
        ),
  );

  _writeSvgs(svgSource, availableFiles);
  _writeIndex(entries);
  licenceSource.copySync(_licenceOutputFile);

  stdout.writeln('Wrote ${entries.length} index entries.');
  stdout.writeln('Copied ${availableFiles.length} SVG files.');

  if (unmatched.isNotEmpty) {
    stdout.writeln(
      'WARNING: ${unmatched.length} catalogue rows had no matching SVG file.',
    );

    for (final String row in unmatched.take(10)) {
      stdout.writeln('  $row');
    }
  }
}

/// Maps a normalised lookup key to the actual file name on disk.
Map<String, String> _indexSvgFiles(Directory svgSource) {
  final Map<String, String> files = <String, String>{};

  for (final FileSystemEntity entity in svgSource.listSync()) {
    if (entity is! File) {
      continue;
    }

    final String name = entity.uri.pathSegments.last;

    if (name.toLowerCase().endsWith('.svg') == false) {
      continue;
    }

    files[_normalise(name.substring(0, name.length - 4))] = name;
  }

  return files;
}

Map<String, Object?>? _entryFor(
  List<String> row,
  Map<String, String> availableFiles,
) {
  // symbol-id, category-id, grammar, rated, tags, symbol-en, category-en, ...
  if (row.length < 7) {
    return null;
  }

  final String displayName = row[5].trim();

  if (displayName.isEmpty) {
    return null;
  }

  final String? file = availableFiles[_normalise(displayName)];

  if (file == null) {
    return null;
  }

  final List<String> tags = row[4]
      .split(RegExp(r'[\s,]+'))
      .map((String t) => t.trim().toLowerCase())
      .where((String t) => t.isNotEmpty)
      .toList();

  return <String, Object?>{
    'file': file,
    'name': _humanise(displayName),
    'category': row[6].trim(),
    'grammar': row[2].trim(),
    'tags': tags,
  };
}

/// Reduces a name or file name to a comparable key.
///
/// Mulberry file names encode spaces as underscores and keep punctuation, so
/// "drink , to" on the catalogue side and "drink_,_to.svg" on disk have to meet
/// in the middle.
String _normalise(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
}

/// Turns a stored name into something readable on screen.
String _humanise(String value) {
  final String spaced = value.replaceAll('_', ' ').replaceAll(' , ', ', ');

  return spaced.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void _writeSvgs(Directory svgSource, Map<String, String> files) {
  final Directory target = Directory(_svgOutputDirectory);

  if (target.existsSync()) {
    target.deleteSync(recursive: true);
  }

  target.createSync(recursive: true);

  for (final String name in files.values) {
    File('${svgSource.path}/$name').copySync('${target.path}/$name');
  }
}

void _writeIndex(List<Map<String, Object?>> entries) {
  final File target = File(_indexOutputFile);
  target.parent.createSync(recursive: true);

  target.writeAsStringSync(
    const JsonEncoder().convert(<String, Object?>{
      'source': 'Mulberry Symbols',
      'url': 'https://github.com/mulberrysymbols/mulberry-symbols',
      'licence': 'CC BY-SA 4.0',
      'symbols': entries,
    }),
  );
}

List<List<String>> _readCsv(File file) {
  final List<List<String>> rows = <List<String>>[];
  final List<String> lines = file.readAsLinesSync();

  for (int i = 1; i < lines.length; i = i + 1) {
    final String line = lines[i];

    if (line.trim().isEmpty) {
      continue;
    }

    rows.add(_splitCsvLine(line));
  }

  return rows;
}

/// Splits one CSV line, honouring double-quoted fields.
List<String> _splitCsvLine(String line) {
  final List<String> fields = <String>[];
  final StringBuffer current = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i = i + 1) {
    final String ch = line[i];

    if (ch == '"') {
      final bool escapedQuote =
          inQuotes && i + 1 < line.length && line[i + 1] == '"';

      if (escapedQuote) {
        current.write('"');
        i = i + 1;
        continue;
      }

      inQuotes = inQuotes == false;
      continue;
    }

    if (ch == ',' && inQuotes == false) {
      fields.add(current.toString());
      current.clear();
      continue;
    }

    current.write(ch);
  }

  fields.add(current.toString());

  return fields;
}
