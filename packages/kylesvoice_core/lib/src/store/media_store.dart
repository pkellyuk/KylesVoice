import 'dart:io';
import 'dart:math' as math;

import '../model/board.dart';
import '../model/board_card.dart';

/// Holds the photographs a board refers to.
///
/// Cards store a bare file name, never a path. An app's data directory changes
/// between installs and between devices, and a board must survive being exported
/// and opened somewhere else, so the location is resolved at read time and never
/// written down.
///
/// Media is deliberately **not** deleted when a card is deleted. Undo has to be
/// able to bring the card back with its photograph intact, and a stale image
/// costs a few kilobytes while a lost one costs a parent the trip back to
/// wherever they took it. Orphans are cleaned up explicitly by [pruneOrphans],
/// which the caller runs when it is safe to do so.
class MediaStore {
  static const String directoryName = 'media';

  /// Longest edge kept for stored photographs, in pixels.
  ///
  /// Enough to look sharp on an 8-inch tablet, small enough that a whole board
  /// can be emailed. Resizing happens at capture time, in the app layer, since
  /// it needs an image codec.
  static const int maxEdgePixels = 1024;

  final Directory directory;

  MediaStore({required this.directory});

  /// Builds a store rooted in a `media` subdirectory of [parent].
  static MediaStore under(Directory parent) {
    return MediaStore(
      directory: Directory(
        '${parent.path}${Platform.pathSeparator}$directoryName',
      ),
    );
  }

  /// Absolute path for a stored file name, or null if the name is empty.
  ///
  /// Returns a path even when the file is missing, so callers can distinguish
  /// "no photograph" from "photograph that failed to load".
  String? pathFor(String? fileName) {
    if (fileName == null) {
      return null;
    }

    if (fileName.trim().isEmpty) {
      return null;
    }

    return '${directory.path}${Platform.pathSeparator}${fileName.trim()}';
  }

  bool exists(String? fileName) {
    final String? path = pathFor(fileName);

    if (path == null) {
      return false;
    }

    return File(path).existsSync();
  }

  /// Stores [bytes] under a fresh name and returns that name.
  ///
  /// Returns an empty string on failure rather than throwing: a photograph that
  /// will not save must not prevent the rest of the card being saved.
  Future<String> save({
    required List<int>? bytes,
    String extension = 'jpg',
  }) async {
    if (bytes == null) {
      return '';
    }

    if (bytes.isEmpty) {
      return '';
    }

    try {
      if (directory.existsSync() == false) {
        directory.createSync(recursive: true);
      }

      final String name = _freshName(extension);
      final File target = File(
        '${directory.path}${Platform.pathSeparator}$name',
      );

      // Same atomic dance as the board file: write to a temporary name, flush,
      // then rename into place, so a device dying mid-write cannot leave a
      // truncated image a card already points at.
      final File temp = File('${target.path}.tmp');
      final RandomAccessFile handle = await temp.open(mode: FileMode.write);

      try {
        await handle.writeFrom(bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }

      await temp.rename(target.path);

      return name;
    } catch (_) {
      return '';
    }
  }

  /// Copies an existing file into the store, returning its new name.
  Future<String> importFile(String? sourcePath) async {
    if (sourcePath == null) {
      return '';
    }

    if (sourcePath.trim().isEmpty) {
      return '';
    }

    try {
      final File source = File(sourcePath);

      if (source.existsSync() == false) {
        return '';
      }

      return await save(
        bytes: await source.readAsBytes(),
        extension: _extensionOf(sourcePath),
      );
    } catch (_) {
      return '';
    }
  }

  /// Removes files no board card refers to.
  ///
  /// Returns the number removed. Never throws; a file that will not delete is
  /// simply left alone.
  Future<int> pruneOrphans(Board? board) async {
    if (board == null) {
      return 0;
    }

    if (directory.existsSync() == false) {
      return 0;
    }

    // Every page, not just the visible one: a photograph referenced on page
    // three is still in use.
    final Set<String> referenced = <String>{};

    for (final BoardPage page in board.pages) {
      for (final BoardCard card in page.cards) {
        if (card.hasPhoto == false) {
          continue;
        }

        referenced.add(card.photoFile.trim());
      }
    }

    int removed = 0;

    try {
      for (final FileSystemEntity entity in directory.listSync()) {
        if (entity is! File) {
          continue;
        }

        final String name = entity.uri.pathSegments.last;

        if (referenced.contains(name)) {
          continue;
        }

        try {
          entity.deleteSync();
          removed = removed + 1;
        } catch (_) {
          // Leave it; an undeletable stray costs only disk space.
        }
      }
    } catch (_) {
      return removed;
    }

    return removed;
  }

  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');

    if (dot < 0 || dot == path.length - 1) {
      return 'jpg';
    }

    final String raw = path.substring(dot + 1).toLowerCase();

    // Only allow plain alphanumeric extensions, so a hostile or malformed
    // source path cannot steer the written file name.
    if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(raw) == false) {
      return 'jpg';
    }

    return raw;
  }

  String _freshName(String extension) {
    final String stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
      36,
    );
    final String salt = math.Random().nextInt(0xFFFFFF).toRadixString(36);

    return 'img_${stamp}_$salt.$extension';
  }
}
