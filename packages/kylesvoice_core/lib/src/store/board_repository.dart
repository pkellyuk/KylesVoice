import 'dart:io';

import '../model/board.dart';
import '../model/board_codec.dart';

/// The outcome of loading a board.
class BoardLoadResult {
  final Board board;

  /// True when the board came from a saved file rather than from the seed.
  final bool wasRestored;

  /// True when the main file was unusable and the backup was used instead.
  final bool usedBackup;

  final List<String> problems;

  const BoardLoadResult({
    required this.board,
    required this.wasRestored,
    required this.usedBackup,
    required this.problems,
  });
}

/// Reads and writes the board to disk.
///
/// Durability matters more here than in most apps. The target user sometimes
/// throws the device, so the process can die at any instant, and the board is
/// the vocabulary a family may have spent months building. Three defences:
///
/// 1. **Atomic writes.** Content goes to a temporary file which is flushed and
///    then renamed over the target. A rename within a directory either happens
///    or does not, so a half-written file can never replace a good one.
/// 2. **A backup of the last good file**, kept before each write and used
///    automatically if the main file turns out to be unreadable.
/// 3. **Salvaging decode.** A damaged file yields whatever cards survived rather
///    than nothing at all.
///
/// Takes a directory rather than discovering one, so it stays free of Flutter
/// and can be tested against a temporary directory.
class BoardRepository {
  static const String fileName = 'board.json';
  static const String backupSuffix = '.bak';
  static const String tempSuffix = '.tmp';

  final Directory directory;

  BoardRepository({required this.directory});

  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');

  File get backupFile =>
      File('${directory.path}${Platform.pathSeparator}$fileName$backupSuffix');

  File get tempFile =>
      File('${directory.path}${Platform.pathSeparator}$fileName$tempSuffix');

  bool get hasSavedBoard => file.existsSync();

  /// Loads the board, falling back to the backup and then to [seed].
  ///
  /// Never throws. A failure to read must leave the user with a working board,
  /// because the board is their only means of communicating.
  Future<BoardLoadResult> load({Board seed = Board.kyleStarter}) async {
    final List<String> problems = <String>[];

    final BoardDecodeResult? primary = await _tryRead(file, problems, 'board');

    if (primary != null && primary.succeeded) {
      return BoardLoadResult(
        board: primary.board!,
        wasRestored: true,
        usedBackup: false,
        problems: <String>[...problems, ...primary.problems],
      );
    }

    final BoardDecodeResult? backup = await _tryRead(
      backupFile,
      problems,
      'backup',
    );

    if (backup != null && backup.succeeded) {
      problems.add(
        'The main board file was unusable; the backup was restored.',
      );

      return BoardLoadResult(
        board: backup.board!,
        wasRestored: true,
        usedBackup: true,
        problems: <String>[...problems, ...backup.problems],
      );
    }

    return BoardLoadResult(
      board: seed,
      wasRestored: false,
      usedBackup: false,
      problems: problems,
    );
  }

  /// Saves the board atomically, keeping the previous file as a backup.
  ///
  /// Returns an empty string on success, or a human-readable failure reason.
  Future<String> save(Board? board) async {
    if (board == null) {
      return 'There is no board to save.';
    }

    if (board.isValid == false) {
      return 'The board has no usable grid and was not saved.';
    }

    try {
      if (directory.existsSync() == false) {
        directory.createSync(recursive: true);
      }

      // Keep the last good file before touching anything.
      if (file.existsSync()) {
        try {
          await file.copy(backupFile.path);
        } catch (e) {
          // A failed backup is not a reason to refuse the save; the atomic
          // rename below still protects the file being written.
          return await _writeAtomically(board, warning: 'Backup failed: $e');
        }
      }

      return await _writeAtomically(board);
    } catch (e) {
      return 'Could not save the board: $e';
    }
  }

  Future<String> _writeAtomically(Board board, {String warning = ''}) async {
    final String encoded = BoardCodec.encode(board);

    // Write, flush to disk, then rename over the target. The rename is the only
    // step that makes the new content visible, and it cannot half-happen.
    final RandomAccessFile handle = await tempFile.open(mode: FileMode.write);

    try {
      await handle.writeString(encoded);
      await handle.flush();
    } finally {
      await handle.close();
    }

    await tempFile.rename(file.path);

    return warning;
  }

  /// Deletes every stored file. Used by tests and by an explicit reset.
  Future<void> deleteAll() async {
    for (final File f in <File>[file, backupFile, tempFile]) {
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {
          // Nothing useful to do: the caller is discarding this data anyway.
        }
      }
    }
  }

  Future<BoardDecodeResult?> _tryRead(
    File target,
    List<String> problems,
    String description,
  ) async {
    if (target.existsSync() == false) {
      return null;
    }

    try {
      final String text = await target.readAsString();
      return BoardCodec.decode(text);
    } catch (e) {
      problems.add('Could not read the $description file: $e');
      return null;
    }
  }
}
