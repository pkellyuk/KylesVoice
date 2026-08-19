import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../board/board_surface.dart';
import '../log.dart';
import '../services/board_storage.dart';
import '../services/speech_service.dart';
import 'editor_screen.dart';
import 'parent_gate.dart';

/// The board, full screen, with an optional diagnostics overlay.
///
/// Everything the child sees is the board. The editor and diagnostics are
/// reached by a deliberate long press in a corner followed by an arithmetic
/// challenge, rather than by a visible control, so neither can be found by
/// accident.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final SpeechService _speech = SpeechService();
  final BoardStorage _storage = BoardStorage();
  final ResolverConfig _config = ResolverConfig.kyle;

  Board _board = Board.kyleStarter;

  bool _loading = true;
  bool _showDiagnostics = false;
  ActivationReport? _lastReport;
  String _spokenText = '';
  List<String> _loadProblems = <String>[];

  @override
  void initState() {
    Log.enter('_BoardScreenState.initState');
    super.initState();

    _speech.initialise();
    _restore();

    Log.exit('_BoardScreenState.initState');
  }

  /// Loads the saved board before showing anything.
  ///
  /// Showing the seed board first and swapping it for the real one a moment
  /// later would mean cards visibly moving under the user's hand, which is
  /// exactly what the motor-planning rule forbids.
  Future<void> _restore() async {
    Log.enter('_BoardScreenState._restore');

    await _storage.initialise();
    final BoardLoadResult result = await _storage.load();

    if (mounted == false) {
      Log.exit('_BoardScreenState._restore', 'unmounted');
      return;
    }

    setState(() {
      _board = result.board;
      _loading = false;
      _loadProblems = result.problems;
    });

    Log.exit(
      '_BoardScreenState._restore',
      'restored=${result.wasRestored} cards=${result.board.cards.length}',
    );
  }

  void _onActivated(BoardCard card) {
    Log.enter('_BoardScreenState._onActivated', 'card=${card.label}');

    _speech.speak(card.effectiveSpeech);

    setState(() {
      _spokenText = card.effectiveSpeech;
    });

    Log.exit(
      '_BoardScreenState._onActivated',
      'spoke "${card.effectiveSpeech}"',
    );
  }

  void _onResolved(ActivationReport report) {
    if (_showDiagnostics == false) {
      return;
    }

    setState(() {
      _lastReport = report;
    });
  }

  /// The parent gate. Long press, then arithmetic, then a choice.
  Future<void> _openParentArea() async {
    Log.enter('_BoardScreenState._openParentArea');

    final bool passed = await showParentGate(context);

    if (passed == false) {
      Log.exit('_BoardScreenState._openParentArea', 'gate not passed');
      return;
    }

    if (mounted == false) {
      return;
    }

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        backgroundColor: const Color(0xFF1C2228),
        title: const Text(
          'Grown-up options',
          style: TextStyle(color: Colors.white),
        ),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('edit'),
            child: const ListTile(
              leading: Icon(Icons.edit, color: Colors.white70),
              title: Text(
                'Edit the board',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Add, change or remove cards',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('diagnostics'),
            child: ListTile(
              leading: const Icon(Icons.insights, color: Colors.white70),
              title: Text(
                _showDiagnostics ? 'Hide diagnostics' : 'Show diagnostics',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'How each touch was resolved',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == 'diagnostics') {
      setState(() {
        _showDiagnostics = _showDiagnostics == false;
      });
      Log.exit(
        '_BoardScreenState._openParentArea',
        'diagnostics=$_showDiagnostics',
      );
      return;
    }

    if (choice == 'edit') {
      await _openEditor();
      Log.exit('_BoardScreenState._openParentArea', 'editor closed');
      return;
    }

    Log.exit('_BoardScreenState._openParentArea', 'dismissed');
  }

  Future<void> _openEditor() async {
    Log.enter('_BoardScreenState._openEditor');

    final Board? edited = await Navigator.of(context).push<Board>(
      MaterialPageRoute<Board>(
        builder: (BuildContext context) =>
            EditorScreen(board: _board, onSave: _storage.save),
      ),
    );

    if (edited == null) {
      // The editor saves as it goes, so a back-button exit still needs the
      // latest board rather than the one we handed in.
      await _restore();
      Log.exit('_BoardScreenState._openEditor', 'reloaded after back');
      return;
    }

    if (mounted == false) {
      return;
    }

    setState(() {
      _board = edited;
    });

    Log.exit('_BoardScreenState._openEditor', 'board=$edited');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1216),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1216),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(10),
              child: BoardSurface(
                board: _board,
                config: _config,
                onActivated: _onActivated,
                onResolved: _onResolved,
                showGridLines: _showDiagnostics,
              ),
            ),
            // The parent gate lives in a corner with no visible affordance, so
            // the child cannot wander into it.
            Positioned(
              left: 0,
              top: 0,
              width: 64,
              height: 64,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _openParentArea,
              ),
            ),
            if (_showDiagnostics)
              Positioned(right: 8, top: 8, child: _buildDiagnostics()),
            if (_loadProblems.isNotEmpty)
              Positioned(left: 8, bottom: 8, right: 8, child: _buildProblems()),
          ],
        ),
      ),
    );
  }

  /// Surfaces anything that went wrong restoring the board.
  ///
  /// Shown to whoever is holding the device rather than swallowed, because a
  /// board that silently lost cards is worse than one that says so.
  Widget _buildProblems() {
    return GestureDetector(
      onTap: () => setState(() => _loadProblems = <String>[]),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE6402020),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'The board did not load cleanly (tap to dismiss)',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            ..._loadProblems.map(
              (String p) => Text(
                p,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnostics() {
    final ActivationReport? report = _lastReport;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE6161B21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'DIAGNOSTICS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _row('Board', '${_board.name} (${_board.cards.length} cards)'),
          _row('Grid', '${_board.rows} x ${_board.cols}'),
          _row('Touch mode', _config.mode.name),
          _row('Coalesce', '${_config.coalesceWindowMillis} ms'),
          _row('Lockout', '${_config.lockoutMillis} ms'),
          _row('Storage', _storage.isReady ? 'ready' : 'unavailable'),
          _row('Speech', _speech.isReady ? 'ready' : 'not ready'),
          if (_speech.lastFailure.isNotEmpty)
            _row('Speech error', _speech.lastFailure),
          const Divider(color: Colors.white24, height: 16),
          if (report == null)
            const Text(
              'Touch the board to see how it resolved.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          if (report != null) ...<Widget>[
            _row('Contacts', '${report.composite.contactCount}'),
            _row('Span', '${report.composite.spanMillis} ms'),
            _row(
              'Footprint',
              '${report.composite.footprint.width.toStringAsFixed(0)} x '
                  '${report.composite.footprint.height.toStringAsFixed(0)} px',
            ),
            _row('Cell', '${report.resolution.cell ?? "none"}'),
            _row('Method', report.resolution.method.name),
            _row('Rejected', report.resolution.rejection.name),
            _row('Ambiguous', '${report.resolution.wasAmbiguous}'),
            _row('Card', report.card?.label ?? 'empty'),
          ],
          const Divider(color: Colors.white24, height: 16),
          _row('Last spoken', _spokenText.isEmpty ? '-' : _spokenText),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
