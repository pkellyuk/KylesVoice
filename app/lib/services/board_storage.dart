import 'dart:io';

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:path_provider/path_provider.dart';

import '../log.dart';

/// Finds a place to keep the board and hands it to the platform-free
/// [BoardRepository].
///
/// The repository itself takes a directory rather than discovering one, so it
/// stays testable with no Flutter dependency. Locating that directory is the
/// only part that needs the platform, and it lives here.
class BoardStorage {
  BoardRepository? _repository;

  bool get isReady => _repository != null;

  /// Prepares storage. Safe to call more than once.
  ///
  /// Never throws: if no directory can be found the app still runs, it simply
  /// cannot persist. A board that works but forgets is far better than an app
  /// that will not start.
  Future<String> initialise() async {
    Log.enter('BoardStorage.initialise');

    if (_repository != null) {
      Log.exit('BoardStorage.initialise', 'already ready');
      return '';
    }

    try {
      final Directory directory = await getApplicationDocumentsDirectory();

      if (directory.existsSync() == false) {
        directory.createSync(recursive: true);
      }

      _repository = BoardRepository(directory: directory);

      Log.exit('BoardStorage.initialise', 'ready at ${directory.path}');
      return '';
    } catch (e, stack) {
      Log.error('BoardStorage.initialise', 'could not open storage', e, stack);
      Log.exit('BoardStorage.initialise', 'not ready');
      return 'Storage unavailable: $e';
    }
  }

  /// Loads the saved board, or the seed if nothing has been saved yet.
  Future<BoardLoadResult> load() async {
    Log.enter('BoardStorage.load');

    final BoardRepository? repository = _repository;

    if (repository == null) {
      Log.warn('BoardStorage.load', 'storage not ready, using seed');
      Log.exit('BoardStorage.load', 'seed');
      return const BoardLoadResult(
        board: Board.kyleStarter,
        wasRestored: false,
        usedBackup: false,
        problems: <String>[
          'Storage was not available; using the starter board.',
        ],
      );
    }

    final BoardLoadResult result = await repository.load();

    Log.step(
      'BoardStorage.load',
      'restored=${result.wasRestored} usedBackup=${result.usedBackup} '
          'cards=${result.board.cards.length} problems=${result.problems.length}',
    );

    for (final String problem in result.problems) {
      Log.warn('BoardStorage.load', problem);
    }

    Log.exit('BoardStorage.load', 'board=${result.board}');
    return result;
  }

  /// Saves the board immediately.
  ///
  /// Called on every edit rather than on leaving the editor. The device is
  /// sometimes thrown, so there is no safe moment to be holding unsaved changes.
  Future<String> save(Board? board) async {
    Log.enter('BoardStorage.save', 'board=$board');

    final BoardRepository? repository = _repository;

    if (repository == null) {
      Log.warn('BoardStorage.save', 'storage not ready, edit not persisted');
      Log.exit('BoardStorage.save', 'failed');
      return 'Changes could not be saved: storage is unavailable.';
    }

    final String failure = await repository.save(board);

    if (failure.isNotEmpty) {
      Log.warn('BoardStorage.save', failure);
    }

    Log.exit('BoardStorage.save', failure.isEmpty ? 'saved' : 'failed');
    return failure;
  }
}
