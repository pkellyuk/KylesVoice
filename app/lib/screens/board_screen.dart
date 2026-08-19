import 'dart:async';

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
  const BoardScreen({super.key, this.storage});

  /// Supplied by tests; production uses the app documents directory.
  final BoardStorage? storage;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final SpeechService _speech = SpeechService();
  late final BoardStorage _storage = widget.storage ?? BoardStorage();
  final ResolverConfig _config = ResolverConfig.kyle;

  Board _board = Board.kyleStarter;

  int _page = 0;

  /// Briefly false after a page change, so a hand still travelling from the
  /// gesture that turned the page cannot immediately fire a card on the new one.
  bool _surfaceEnabled = true;
  Timer? _reenableTimer;

  bool _loading = true;
  bool _startupTipOffered = false;
  bool _showParentAreaTip = false;
  Timer? _parentAreaTipTimer;
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
    bool showParentAreaTip = false;

    // `_restore` also runs after leaving the editor. Offer the hint only once
    // for this app process, never on navigation or recomposition.
    if (_startupTipOffered == false) {
      _startupTipOffered = true;
      showParentAreaTip = true;
    }

    if (mounted == false) {
      Log.exit('_BoardScreenState._restore', 'unmounted');
      return;
    }

    setState(() {
      _board = result.board;
      _page = result.board.clampPage(_page);
      _loading = false;
      _loadProblems = result.problems;
      _showParentAreaTip = showParentAreaTip;
    });

    if (showParentAreaTip) {
      _parentAreaTipTimer?.cancel();
      _parentAreaTipTimer = Timer(
        const Duration(seconds: 7),
        _dismissParentAreaTip,
      );
    }

    Log.exit(
      '_BoardScreenState._restore',
      'restored=${result.wasRestored} cards=${result.board.totalCards}',
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

  /// Moves to another page.
  ///
  /// The board is deaf for a moment afterwards: whatever turned the page, the
  /// hand is still moving, and a card firing under it would be a word the user
  /// did not choose.
  void _goToPage(int index) {
    Log.enter('_BoardScreenState._goToPage', 'from=$_page to=$index');

    final int target = _board.clampPage(index);

    if (target == _page) {
      Log.exit('_BoardScreenState._goToPage', 'already there');
      return;
    }

    _reenableTimer?.cancel();

    setState(() {
      _page = target;
      _surfaceEnabled = false;
    });

    _reenableTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted == false) {
        return;
      }

      setState(() {
        _surfaceEnabled = true;
      });
    });

    Log.exit(
      '_BoardScreenState._goToPage',
      'page=$_page of ${_board.pageCount}',
    );
  }

  void _onSwipe(DragEndDetails details) {
    if (_config.swipeToChangePage == false) {
      return;
    }

    final double velocity = details.primaryVelocity ?? 0;

    // A deliberate flick, not a drift. The threshold is high on purpose.
    if (velocity.abs() < 600) {
      return;
    }

    Log.step('_BoardScreenState._onSwipe', 'velocity=$velocity');

    _goToPage(velocity < 0 ? _page + 1 : _page - 1);
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

    _dismissParentAreaTip();

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
        builder: (BuildContext context) => EditorScreen(
          board: _board,
          onSave: _storage.save,
          media: _storage.media,
          mediaDirectory: _storage.mediaDirectory,
        ),
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
  void dispose() {
    _reenableTimer?.cancel();
    _parentAreaTipTimer?.cancel();
    super.dispose();
  }

  void _dismissParentAreaTip() {
    _parentAreaTipTimer?.cancel();

    if (mounted && _showParentAreaTip) {
      setState(() => _showParentAreaTip = false);
    }
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
            _buildBoardArea(),
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
            if (_showParentAreaTip) _buildParentAreaTip(),
            if (_showDiagnostics)
              Positioned(right: 8, top: 8, child: _buildDiagnostics()),
            if (_loadProblems.isNotEmpty)
              Positioned(left: 8, bottom: 8, right: 8, child: _buildProblems()),
          ],
        ),
      ),
    );
  }

  /// A short-lived, non-intercepting hint for the otherwise invisible parent
  /// area. It sits above the board but lets every touch pass through unchanged.
  Widget _buildParentAreaTip() {
    return Positioned(
      left: 8,
      top: 8,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: 'Press and hold the top-left corner for grown-up options',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x334FA3D1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7BC4EA), width: 2),
                ),
                child: const Icon(
                  Icons.touch_app_outlined,
                  color: Color(0xFFE4F5FD),
                  size: 26,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF21C2228),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x997BC4EA)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Press and hold for grown-up options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The board, with a reserved strip either side for the page arrows.
  ///
  /// The strips are always present, even on a one-page board where the arrows
  /// do nothing. That is deliberate: if they appeared only when a second page
  /// was added, adding a page would narrow the grid and shift every card, which
  /// is precisely the motor-planning failure the whole design exists to
  /// prevent. The space is reserved from the first day so nothing ever moves.
  Widget _buildBoardArea() {
    final Widget board = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: BoardSurface(
        board: _board,
        pageIndex: _page,
        enabled: _surfaceEnabled,
        config: _config,
        onActivated: _onActivated,
        onResolved: _onResolved,
        showGridLines: _showDiagnostics,
        mediaDirectory: _storage.mediaDirectory,
      ),
    );

    return Row(
      children: <Widget>[
        _buildPageArrow(forward: false),
        Expanded(
          child: _config.swipeToChangePage
              ? GestureDetector(
                  onHorizontalDragEnd: _onSwipe,
                  behavior: HitTestBehavior.translucent,
                  child: board,
                )
              : board,
        ),
        _buildPageArrow(forward: true),
      ],
    );
  }

  Widget _buildPageArrow({required bool forward}) {
    final bool canGo = forward ? _page < _board.pageCount - 1 : _page > 0;

    return SizedBox(
      width: 58,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: IconButton(
                iconSize: 34,
                onPressed: canGo
                    ? () => _goToPage(forward ? _page + 1 : _page - 1)
                    : null,
                icon: Icon(forward ? Icons.chevron_right : Icons.chevron_left),
                color: Colors.white70,
                disabledColor: const Color(0x14FFFFFF),
                tooltip: forward ? 'Next page' : 'Previous page',
              ),
            ),
          ),
          // The page number sits in the left strip, which is already reserved,
          // rather than in a bar of its own that would cost more board height.
          if (forward == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${_page + 1}/${_board.pageCount}',
                style: TextStyle(
                  color: _board.pageCount > 1
                      ? Colors.white54
                      : const Color(0x22FFFFFF),
                  fontSize: 12,
                ),
              ),
            ),
          if (forward) const SizedBox(height: 32),
        ],
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
          _row('Board', '${_board.name} (${_board.totalCards} cards)'),
          _row('Grid', '${_board.rows} x ${_board.cols}'),
          _row('Page', '${_page + 1} of ${_board.pageCount}'),
          _row('Swipe paging', _config.swipeToChangePage ? 'on' : 'off'),
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
