import '../geometry/contact_ellipse.dart';
import '../geometry/ellipse_overlap.dart';
import '../grid/grid_geometry.dart';
import 'resolver_config.dart';

/// Why a resolution produced no activation.
enum RejectionReason {
  none,
  lockout,
  multiTouch,
  dwellNotMet,
  noOverlap,
  ambiguous,
  invalidGrid,
}

/// How a cell was arrived at, recorded so that we can later measure whether
/// palm mode is actually helping rather than assuming it.
enum ResolutionMethod { point, palmOverlap, fallbackRadius, none }

/// The outcome of resolving one contact against the grid.
class TouchResolution {
  final CellAddress? cell;
  final ResolutionMethod method;
  final RejectionReason rejection;

  /// Overlap area in square logical pixels for the winning cell.
  final double winningOverlap;

  /// Overlap area for the runner-up, used to judge ambiguity.
  final double runnerUpOverlap;

  final CellAddress? runnerUpCell;

  /// True when the winner and runner-up were within the configured threshold,
  /// whether or not the policy chose to activate anyway.
  final bool wasAmbiguous;

  const TouchResolution({
    required this.cell,
    required this.method,
    required this.rejection,
    required this.winningOverlap,
    required this.runnerUpOverlap,
    required this.runnerUpCell,
    required this.wasAmbiguous,
  });

  bool get activated => cell != null;

  static const TouchResolution none = TouchResolution(
    cell: null,
    method: ResolutionMethod.none,
    rejection: RejectionReason.none,
    winningOverlap: 0,
    runnerUpOverlap: 0,
    runnerUpCell: null,
    wasAmbiguous: false,
  );

  TouchResolution rejectedBecause(RejectionReason reason) {
    return TouchResolution(
      cell: null,
      method: method,
      rejection: reason,
      winningOverlap: winningOverlap,
      runnerUpOverlap: runnerUpOverlap,
      runnerUpCell: runnerUpCell,
      wasAmbiguous: wasAmbiguous,
    );
  }

  @override
  String toString() =>
      'TouchResolution(cell: $cell, method: ${method.name}, '
      'rejection: ${rejection.name}, overlap: ${winningOverlap.toStringAsFixed(1)}, '
      'runnerUp: ${runnerUpOverlap.toStringAsFixed(1)}, ambiguous: $wasAmbiguous)';
}

/// Decides which cell a contact activates.
///
/// Stateful only in the small ways it must be: it remembers when the last
/// activation happened, to enforce the post-activation lockout, and which
/// pointer is currently authoritative, to ignore the extra contacts a palm slap
/// produces. Everything else is a pure function of the contact and the grid,
/// which is what makes it exhaustively testable without a device.
class TouchResolver {
  ResolverConfig config;

  int? _lastActivationMillis;
  int? _authoritativePointer;
  int? _authoritativeDownMillis;

  TouchResolver({ResolverConfig? config})
    : config = config ?? const ResolverConfig();

  /// Clears lockout and pointer tracking. Call when the board changes.
  void reset() {
    _lastActivationMillis = null;
    _authoritativePointer = null;
    _authoritativeDownMillis = null;
  }

  /// Records that a pointer went down, returning false if it should be ignored.
  ///
  /// The first pointer down is authoritative; while it remains down, later
  /// pointers are ignored under [ResolverConfig.multiTouchLockout], because a
  /// slap lands several fingers within milliseconds and only one of them
  /// represents the intended target.
  bool onPointerDown({required int pointerId, required int timestampMillis}) {
    if (config.multiTouchLockout == false) {
      _authoritativeDownMillis = timestampMillis;
      return true;
    }

    if (_authoritativePointer == null) {
      _authoritativePointer = pointerId;
      _authoritativeDownMillis = timestampMillis;
      return true;
    }

    return _authoritativePointer == pointerId;
  }

  /// Records that a pointer lifted.
  void onPointerUp({required int pointerId}) {
    if (_authoritativePointer != pointerId) {
      return;
    }

    _authoritativePointer = null;
    _authoritativeDownMillis = null;
  }

  /// Resolves [contact] against [grid].
  ///
  /// [timestampMillis] drives lockout and dwell. [pointerId] is checked against
  /// the authoritative pointer. Pass [commit] false to evaluate without starting
  /// the lockout, which the diagnostic UI uses to preview resolution live.
  TouchResolution resolve({
    required ContactEllipse? contact,
    required GridGeometry? grid,
    required int timestampMillis,
    int? pointerId,
    bool commit = true,
  }) {
    if (contact == null) {
      return TouchResolution.none;
    }

    if (grid == null || grid.isValid == false) {
      return TouchResolution.none.rejectedBecause(RejectionReason.invalidGrid);
    }

    if (pointerId != null && config.multiTouchLockout == true) {
      if (_authoritativePointer != null && _authoritativePointer != pointerId) {
        return TouchResolution.none.rejectedBecause(RejectionReason.multiTouch);
      }
    }

    if (_isLockedOut(timestampMillis)) {
      return TouchResolution.none.rejectedBecause(RejectionReason.lockout);
    }

    if (_isDwellUnmet(timestampMillis)) {
      return TouchResolution.none.rejectedBecause(RejectionReason.dwellNotMet);
    }

    final TouchResolution candidate = _resolveGeometry(
      contact: contact,
      grid: grid,
    );

    if (candidate.activated == false) {
      return candidate;
    }

    if (candidate.wasAmbiguous &&
        config.ambiguityPolicy == AmbiguityPolicy.ignore) {
      return candidate.rejectedBecause(RejectionReason.ambiguous);
    }

    if (commit) {
      _lastActivationMillis = timestampMillis;
    }

    return candidate;
  }

  bool _isLockedOut(int timestampMillis) {
    final int? last = _lastActivationMillis;

    if (last == null) {
      return false;
    }

    if (config.lockoutMillis <= 0) {
      return false;
    }

    return timestampMillis - last < config.lockoutMillis;
  }

  bool _isDwellUnmet(int timestampMillis) {
    if (config.dwellMillis <= 0) {
      return false;
    }

    final int? downAt = _authoritativeDownMillis;

    if (downAt == null) {
      return false;
    }

    return timestampMillis - downAt < config.dwellMillis;
  }

  TouchResolution _resolveGeometry({
    required ContactEllipse contact,
    required GridGeometry grid,
  }) {
    if (_effectiveMode(contact) == TouchMode.point) {
      return _resolveByPoint(contact: contact, grid: grid);
    }

    return _resolveByOverlap(contact: contact, grid: grid);
  }

  TouchMode _effectiveMode(ContactEllipse contact) {
    if (config.mode != TouchMode.auto) {
      return config.mode;
    }

    // Without a measured contact size there is nothing for area resolution to
    // work with, so auto falls back to point.
    if (contact.isMeasured == false) {
      return TouchMode.point;
    }

    if (contact.radiusMajor >= config.autoPalmRadiusThreshold) {
      return TouchMode.palm;
    }

    return TouchMode.point;
  }

  TouchResolution _resolveByPoint({
    required ContactEllipse contact,
    required GridGeometry grid,
  }) {
    final CellAddress? cell = grid.cellAt(contact.centre);

    if (cell == null) {
      return TouchResolution.none.rejectedBecause(RejectionReason.noOverlap);
    }

    return TouchResolution(
      cell: cell,
      method: ResolutionMethod.point,
      rejection: RejectionReason.none,
      winningOverlap: 0,
      runnerUpOverlap: 0,
      runnerUpCell: null,
      wasAmbiguous: false,
    );
  }

  TouchResolution _resolveByOverlap({
    required ContactEllipse contact,
    required GridGeometry grid,
  }) {
    CellAddress? bestCell;
    CellAddress? secondCell;
    double bestArea = 0;
    double secondArea = 0;

    for (final PositionedCell cell in grid.allCells()) {
      final double overlap = EllipseOverlap.area(
        ellipse: contact,
        rect: cell.rect,
      );

      if (overlap <= 0) {
        continue;
      }

      if (overlap > bestArea) {
        secondArea = bestArea;
        secondCell = bestCell;
        bestArea = overlap;
        bestCell = cell.address;
        continue;
      }

      if (overlap > secondArea) {
        secondArea = overlap;
        secondCell = cell.address;
      }
    }

    if (bestCell == null) {
      return TouchResolution.none.rejectedBecause(RejectionReason.noOverlap);
    }

    if (_isTooSlight(contact: contact, grid: grid, overlap: bestArea)) {
      return TouchResolution.none.rejectedBecause(RejectionReason.noOverlap);
    }

    final bool ambiguous = _isAmbiguous(best: bestArea, second: secondArea);

    return TouchResolution(
      cell: bestCell,
      method: contact.isMeasured
          ? ResolutionMethod.palmOverlap
          : ResolutionMethod.fallbackRadius,
      rejection: RejectionReason.none,
      winningOverlap: bestArea,
      runnerUpOverlap: secondArea,
      runnerUpCell: secondCell,
      wasAmbiguous: ambiguous,
    );
  }

  /// True when the contact barely grazed the cell, by both the cell's measure
  /// and the contact's own. Requiring both avoids rejecting a small fingertip on
  /// a large cell, or a large palm mostly off the edge of the screen.
  bool _isTooSlight({
    required ContactEllipse contact,
    required GridGeometry grid,
    required double overlap,
  }) {
    if (config.minimumOverlapFraction <= 0) {
      return false;
    }

    final double contactArea = contact.area;
    final double cellArea = grid.cellWidth * grid.cellHeight;

    final bool slightForContact =
        contactArea > 0 &&
        overlap / contactArea < config.minimumOverlapFraction;
    final bool slightForCell =
        cellArea > 0 && overlap / cellArea < config.minimumOverlapFraction;

    return slightForContact && slightForCell;
  }

  bool _isAmbiguous({required double best, required double second}) {
    if (second <= 0) {
      return false;
    }

    if (best <= 0) {
      return false;
    }

    return (best - second) / best < config.ambiguityThreshold;
  }
}
