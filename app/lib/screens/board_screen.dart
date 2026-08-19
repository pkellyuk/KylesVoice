import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../board/board_surface.dart';
import '../log.dart';
import '../model/board.dart';
import '../services/speech_service.dart';

/// The board, full screen, with an optional diagnostics overlay.
///
/// Everything the child sees is the board. The diagnostics panel exists for
/// tuning sessions with a parent or therapist and is off by default; it is
/// reached by a deliberate long press in a corner rather than a visible button,
/// so it cannot be found by accident.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final SpeechService _speech = SpeechService();

  final Board _board = Board.kyleStarter;
  final ResolverConfig _config = ResolverConfig.kyle;

  bool _showDiagnostics = false;
  ActivationReport? _lastReport;
  String _spokenText = '';

  @override
  void initState() {
    Log.enter('_BoardScreenState.initState');
    super.initState();

    _speech.initialise();

    Log.exit('_BoardScreenState.initState', 'board=${_board.name}');
  }

  void _onActivated(BoardCard card) {
    Log.enter('_BoardScreenState._onActivated', 'card=${card.label}');

    _speech.speak(card.speech);

    setState(() {
      _spokenText = card.speech;
    });

    Log.exit('_BoardScreenState._onActivated', 'spoke "${card.speech}"');
  }

  void _onResolved(ActivationReport report) {
    if (_showDiagnostics == false) {
      return;
    }

    setState(() {
      _lastReport = report;
    });
  }

  void _toggleDiagnostics() {
    Log.enter('_BoardScreenState._toggleDiagnostics', 'was=$_showDiagnostics');

    setState(() {
      _showDiagnostics = _showDiagnostics == false;
    });

    Log.exit('_BoardScreenState._toggleDiagnostics', 'now=$_showDiagnostics');
  }

  @override
  Widget build(BuildContext context) {
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
            // The parent gate. A long press in a corner, not a visible control,
            // so the child cannot wander into settings.
            Positioned(
              left: 0,
              top: 0,
              width: 64,
              height: 64,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _toggleDiagnostics,
              ),
            ),
            if (_showDiagnostics)
              Positioned(right: 8, top: 8, child: _buildDiagnostics()),
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
          _row('Grid', '${_board.rows} x ${_board.cols}'),
          _row('Touch mode', _config.mode.name),
          _row('Coalesce', '${_config.coalesceWindowMillis} ms'),
          _row('Lockout', '${_config.lockoutMillis} ms'),
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
          const SizedBox(height: 8),
          const Text(
            'Long-press the top-left corner to hide.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
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
