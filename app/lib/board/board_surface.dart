import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';
import 'card_tile.dart';

/// Everything the diagnostics overlay needs to explain one activation.
class ActivationReport {
  final TouchResolution resolution;
  final CompositeContact composite;
  final BoardCard? card;

  const ActivationReport({
    required this.resolution,
    required this.composite,
    required this.card,
  });
}

/// The board itself: a fixed grid of cards that resolves real touches.
///
/// A [Listener] rather than a [GestureDetector], because gesture recognisers
/// arbitrate and discard the raw pointer geometry that resolution depends on,
/// and because arbitration delay is latency a child would feel.
///
/// Pointer handling follows the model measured in `docs/FINDINGS-TOUCH.md`: a
/// hand landing on the glass produces several contacts, so contacts are
/// coalesced into one composite act before being resolved, rather than each
/// firing its own card.
class BoardSurface extends StatefulWidget {
  final Board board;
  final ResolverConfig config;

  /// Called when a card is activated, with the phrase to speak.
  final void Function(BoardCard card) onActivated;

  /// Called for every resolution attempt, including refusals, so a diagnostics
  /// overlay can show why nothing happened.
  final void Function(ActivationReport report)? onResolved;

  final bool showGridLines;

  const BoardSurface({
    super.key,
    required this.board,
    required this.config,
    required this.onActivated,
    this.onResolved,
    this.showGridLines = false,
  });

  @override
  State<BoardSurface> createState() => _BoardSurfaceState();
}

class _BoardSurfaceState extends State<BoardSurface> {
  /// How long an activated card stays highlighted.
  static const Duration _flashDuration = Duration(milliseconds: 260);

  late ContactCoalescer _coalescer;
  late TouchResolver _resolver;

  Timer? _coalesceTimer;
  Timer? _flashTimer;

  CellAddress? _flashing;
  GridGeometry? _grid;

  @override
  void initState() {
    Log.enter('_BoardSurfaceState.initState');
    super.initState();

    _coalescer = ContactCoalescer(
      windowMillis: widget.config.coalesceWindowMillis,
    );
    _resolver = TouchResolver(config: widget.config);

    Log.exit(
      '_BoardSurfaceState.initState',
      'grid=${widget.board.rows}x${widget.board.cols} '
          'coalesceWindow=${widget.config.coalesceWindowMillis}ms '
          'lockout=${widget.config.lockoutMillis}ms',
    );
  }

  @override
  void didUpdateWidget(BoardSurface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config != widget.config) {
      Log.step('_BoardSurfaceState.didUpdateWidget', 'config replaced');
      _resolver.config = widget.config;
      _coalescer = ContactCoalescer(
        windowMillis: widget.config.coalesceWindowMillis,
      );
    }

    if (oldWidget.board != widget.board) {
      Log.step(
        '_BoardSurfaceState.didUpdateWidget',
        'board replaced, resetting',
      );
      _resolver.reset();
      _coalescer.reset();
    }
  }

  @override
  void dispose() {
    Log.enter('_BoardSurfaceState.dispose');

    _coalesceTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();

    Log.exit('_BoardSurfaceState.dispose');
  }

  /// Hot path. Converts a raw pointer into a platform-free contact and offers it
  /// to the coalescer. Logs only when verbose logging is enabled, because
  /// logging here distorts the timings the resolver depends on.
  void _onPointerDown(PointerDownEvent? event) {
    if (event == null) {
      return;
    }

    final ContactEllipse contact = ContactEllipse.fromPlatform(
      centre: Point2(event.localPosition.dx, event.localPosition.dy),
      reportedMajor: event.radiusMajor,
      reportedMinor: event.radiusMinor,
      orientation: event.orientation,
      calibrationScale: widget.config.calibrationScale,
      fallbackRadius: widget.config.fallbackRadius,
    );

    Log.hot(
      '_BoardSurfaceState._onPointerDown',
      'p${event.pointer} at ${contact.centre} '
          'rMaj=${contact.radiusMajor.toStringAsFixed(2)} '
          'measured=${contact.isMeasured}',
    );

    final CompositeContact? closed = _coalescer.add(
      contact: contact,
      pointerId: event.pointer,
      timestampMillis: event.timeStamp.inMilliseconds,
    );

    // A contact outside the window closes the previous act; resolve it at once
    // rather than waiting for the timer.
    if (closed != null) {
      _resolveComposite(closed);
    }

    _scheduleFlush();
  }

  void _onPointerUp(PointerUpEvent? event) {
    if (event == null) {
      return;
    }

    _resolver.onPointerUp(pointerId: event.pointer);
  }

  /// Arms the timer that closes the current cluster.
  ///
  /// The coalescer holds no timers of its own so that it stays a pure function
  /// of its inputs and fully testable. Owning the clock is the widget's job.
  void _scheduleFlush() {
    if (_coalesceTimer != null && _coalesceTimer!.isActive) {
      return;
    }

    _coalesceTimer = Timer(
      Duration(milliseconds: widget.config.coalesceWindowMillis),
      () {
        final CompositeContact? composite = _coalescer.flush();

        if (composite == null) {
          return;
        }

        _resolveComposite(composite);
      },
    );
  }

  void _resolveComposite(CompositeContact composite) {
    Log.enter(
      '_BoardSurfaceState._resolveComposite',
      'contacts=${composite.contactCount} span=${composite.spanMillis}ms',
    );

    final GridGeometry? grid = _grid;

    if (grid == null) {
      Log.warn('_BoardSurfaceState._resolveComposite', 'no grid yet, ignoring');
      Log.exit('_BoardSurfaceState._resolveComposite', 'aborted');
      return;
    }

    final TouchResolution resolution = _resolver.resolveComposite(
      composite: composite,
      grid: grid,
      timestampMillis: composite.firstTimestampMillis,
    );

    final BoardCard? card = widget.board.cardAt(resolution.cell);

    Log.step(
      '_BoardSurfaceState._resolveComposite',
      'cell=${resolution.cell} method=${resolution.method.name} '
          'rejection=${resolution.rejection.name} '
          'ambiguous=${resolution.wasAmbiguous} '
          'card=${card?.label ?? "none"}',
    );

    widget.onResolved?.call(
      ActivationReport(
        resolution: resolution,
        composite: composite,
        card: card,
      ),
    );

    if (resolution.activated == false) {
      Log.exit('_BoardSurfaceState._resolveComposite', 'no activation');
      return;
    }

    if (card == null) {
      // An empty cell is a legitimate target that simply has nothing to say.
      // Silence here is correct: it must not be treated as an error, and it must
      // not fire a neighbouring card instead.
      Log.exit(
        '_BoardSurfaceState._resolveComposite',
        'empty cell, nothing to speak',
      );
      return;
    }

    _flash(card.address);
    widget.onActivated(card);

    Log.exit('_BoardSurfaceState._resolveComposite', 'spoke "${card.speech}"');
  }

  void _flash(CellAddress address) {
    _flashTimer?.cancel();

    setState(() {
      _flashing = address;
    });

    _flashTimer = Timer(_flashDuration, () {
      if (mounted == false) {
        return;
      }

      setState(() {
        _flashing = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final GridGeometry grid = GridGeometry(
          rows: widget.board.rows,
          cols: widget.board.cols,
          bounds: Rect2(
            left: 0,
            top: 0,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
          gutter: 14,
        );

        _grid = grid;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          child: Stack(children: _buildCells(grid)),
        );
      },
    );
  }

  List<Widget> _buildCells(GridGeometry grid) {
    final List<Widget> children = <Widget>[];

    for (final PositionedCell cell in grid.allCells()) {
      final BoardCard? card = widget.board.cardAt(cell.address);

      children.add(
        Positioned(
          left: cell.rect.left,
          top: cell.rect.top,
          width: cell.rect.width,
          height: cell.rect.height,
          // Cards must never intercept pointers: every touch has to reach the
          // Listener so the resolver sees the whole hand, not one widget's idea
          // of who was hit.
          child: IgnorePointer(
            child: CardTile(
              card: card,
              isFlashing: _flashing == cell.address,
              showOutline: widget.showGridLines,
            ),
          ),
        ),
      );
    }

    return children;
  }
}
