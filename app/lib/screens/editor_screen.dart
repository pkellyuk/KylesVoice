import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../board/card_tile.dart';
import '../log.dart';
import 'card_editor.dart';

/// The parent and therapist view of the board.
///
/// Shows the same fixed grid the child sees, but every cell is tappable and
/// nothing speaks. Edits are saved the moment they are made rather than on
/// leaving: the device is sometimes thrown, so there is no safe point at which
/// to be holding unsaved changes.
class EditorScreen extends StatefulWidget {
  final Board board;

  /// Persists the board. Returns an empty string on success, or a reason.
  final Future<String> Function(Board board) onSave;

  const EditorScreen({super.key, required this.board, required this.onSave});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Board _board;

  /// The board as it was before the most recent change.
  ///
  /// One level of undo, kept because the realistic disaster is a parent
  /// deleting the wrong card late at night, and that needs to be recoverable
  /// immediately rather than through a backup file.
  Board? _undo;

  String _status = '';

  @override
  void initState() {
    Log.enter('_EditorScreenState.initState');
    super.initState();

    _board = widget.board;

    Log.exit('_EditorScreenState.initState', 'board=$_board');
  }

  Future<void> _apply(Board next, String description) async {
    Log.enter('_EditorScreenState._apply', description);

    final Board previous = _board;

    setState(() {
      _undo = previous;
      _board = next;
      _status = description;
    });

    final String failure = await widget.onSave(next);

    if (mounted == false) {
      Log.exit('_EditorScreenState._apply', 'unmounted');
      return;
    }

    if (failure.isNotEmpty) {
      setState(() {
        _status = failure;
      });
    }

    Log.exit(
      '_EditorScreenState._apply',
      failure.isEmpty ? 'saved' : 'save failed: $failure',
    );
  }

  Future<void> _undoLast() async {
    Log.enter('_EditorScreenState._undoLast');

    final Board? previous = _undo;

    if (previous == null) {
      Log.exit('_EditorScreenState._undoLast', 'nothing to undo');
      return;
    }

    setState(() {
      _board = previous;
      _undo = null;
      _status = 'Undone.';
    });

    await widget.onSave(previous);

    Log.exit('_EditorScreenState._undoLast', 'restored');
  }

  Future<void> _editCell(CellAddress address) async {
    Log.enter('_EditorScreenState._editCell', 'address=$address');

    final BoardCard? existing = _board.cardAt(address);

    final CardEditResult? result = await Navigator.of(context)
        .push<CardEditResult>(
          MaterialPageRoute<CardEditResult>(
            builder: (BuildContext context) =>
                CardEditor(address: address, existing: existing),
          ),
        );

    if (result == null) {
      Log.exit('_EditorScreenState._editCell', 'cancelled');
      return;
    }

    if (result.action == CardEditAction.delete) {
      await _apply(
        _board.withoutCard(address),
        'Removed "${existing?.label ?? ''}". The cell keeps its place.',
      );
      Log.exit('_EditorScreenState._editCell', 'deleted');
      return;
    }

    if (result.action == CardEditAction.save && result.card != null) {
      await _apply(
        _board.withCard(result.card),
        existing == null
            ? 'Added "${result.card!.label}".'
            : 'Updated "${result.card!.label}".',
      );
      Log.exit('_EditorScreenState._editCell', 'saved');
      return;
    }

    Log.exit('_EditorScreenState._editCell', 'no change');
  }

  Future<void> _editGridSize() async {
    Log.enter('_EditorScreenState._editGridSize');

    final ({int rows, int cols})? chosen =
        await showDialog<({int rows, int cols})>(
          context: context,
          builder: (BuildContext context) =>
              _GridSizeDialog(rows: _board.rows, cols: _board.cols),
        );

    if (chosen == null) {
      Log.exit('_EditorScreenState._editGridSize', 'cancelled');
      return;
    }

    if (chosen.rows == _board.rows && chosen.cols == _board.cols) {
      Log.exit('_EditorScreenState._editGridSize', 'unchanged');
      return;
    }

    final ({Board board, List<BoardCard> orphaned}) result = _board.resized(
      newRows: chosen.rows,
      newCols: chosen.cols,
    );

    if (mounted == false) {
      return;
    }

    // Changing the grid moves every card the user has learned. Say so plainly,
    // and name what would be lost, before doing it.
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2228),
        title: const Text(
          'Change the grid?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Every card will change size and position on screen. Anyone who '
              'has learned where the words are will have to learn again.\n\n'
              'This is the single most disruptive change you can make. It is '
              'worth doing early and best avoided later.',
              style: TextStyle(color: Colors.white70),
            ),
            if (result.orphaned.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'These ${result.orphaned.length} card(s) fall outside the new '
                'grid and will be removed:',
                style: const TextStyle(
                  color: Color(0xFFE57373),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.orphaned.map((BoardCard c) => c.label).join(', '),
                style: const TextStyle(color: Color(0xFFE57373)),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Leave it alone'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change it'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      Log.exit('_EditorScreenState._editGridSize', 'declined');
      return;
    }

    await _apply(result.board, 'Grid is now ${chosen.rows} x ${chosen.cols}.');

    Log.exit('_EditorScreenState._editGridSize', 'resized');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        Log.step('_EditorScreenState.build', 'leaving editor');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1216),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161B21),
          title: Text('Editing ${_board.name}'),
          actions: <Widget>[
            IconButton(
              onPressed: _undo == null ? null : _undoLast,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last change',
            ),
            IconButton(
              onPressed: _editGridSize,
              icon: const Icon(Icons.grid_view),
              tooltip: 'Grid size',
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(_board),
              icon: const Icon(Icons.check),
              tooltip: 'Done',
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status.isEmpty
                          ? 'Tap any cell to add or change a card. Changes save '
                                'as you make them.'
                          : _status,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _buildGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final GridGeometry grid = GridGeometry(
          rows: _board.rows,
          cols: _board.cols,
          bounds: Rect2(
            left: 0,
            top: 0,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
          gutter: 14,
        );

        return Stack(
          children: grid
              .allCells()
              .map((PositionedCell cell) {
                final BoardCard? card = _board.cardAt(cell.address);

                return Positioned(
                  left: cell.rect.left,
                  top: cell.rect.top,
                  width: cell.rect.width,
                  height: cell.rect.height,
                  child: GestureDetector(
                    onTap: () => _editCell(cell.address),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        CardTile(
                          card: card,
                          isFlashing: false,
                          showOutline: true,
                        ),
                        if (card == null)
                          const Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white24,
                              size: 34,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

/// Picks new grid dimensions.
class _GridSizeDialog extends StatefulWidget {
  final int rows;
  final int cols;

  const _GridSizeDialog({required this.rows, required this.cols});

  @override
  State<_GridSizeDialog> createState() => _GridSizeDialogState();
}

class _GridSizeDialogState extends State<_GridSizeDialog> {
  late int _rows;
  late int _cols;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows;
    _cols = widget.cols;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C2228),
      title: const Text('Grid size', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Choose the size you want to end up with, then leave it alone. '
            'Add words by filling empty cells rather than by making the grid '
            'bigger later.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _stepper(
            label: 'Rows',
            value: _rows,
            onChanged: (int v) => setState(() => _rows = v),
          ),
          const SizedBox(height: 10),
          _stepper(
            label: 'Columns',
            value: _cols,
            onChanged: (int v) => setState(() => _cols = v),
          ),
          const SizedBox(height: 14),
          Text(
            '$_rows x $_cols = ${_rows * _cols} cells',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            'Measured guidance: an adult palm covers about 42 x 46 mm, a '
            "child's roughly 32 x 38 mm. On an 8-inch tablet that is about "
            '3 columns by 2 rows if the user tends to slap rather than point.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((rows: _rows, cols: _cols)),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _stepper({
    required String label,
    required int value,
    required void Function(int) onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        IconButton(
          onPressed: value < 8 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
