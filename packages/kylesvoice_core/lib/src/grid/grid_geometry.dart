import '../geometry/primitives.dart';

/// A cell's fixed address on the board.
///
/// Position is identity. Two cells with the same row and column are the same
/// cell, and a card's coordinates never change once chosen, because the user
/// learns the motor path to a word rather than the picture on it.
class CellAddress {
  final int row;
  final int col;

  const CellAddress({required this.row, required this.col});

  @override
  String toString() => 'r$row.c$col';

  @override
  bool operator ==(Object other) =>
      other is CellAddress && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// A cell together with the rectangle it occupies on screen.
class PositionedCell {
  final CellAddress address;
  final Rect2 rect;

  /// How many rows and columns the cell spans. Spans let one card be made
  /// physically larger without disturbing any other card's position.
  final int rowSpan;
  final int colSpan;

  const PositionedCell({
    required this.address,
    required this.rect,
    this.rowSpan = 1,
    this.colSpan = 1,
  });

  @override
  String toString() => 'PositionedCell($address, $rect)';
}

/// Maps a board's fixed row/column grid onto the physical screen.
///
/// The grid's dimensions belong to the board set, never to the device. A phone
/// and a tablet showing the same board have identical rows and columns and
/// differently sized cells, which preserves the relative motor plan across
/// devices. See DESIGN.md section 13.2 for the trade-off this implies on small
/// screens.
class GridGeometry {
  final int rows;
  final int cols;
  final Rect2 bounds;

  /// Dead space between cells, belonging to no cell. In point mode this reduces
  /// mis-hits on shared edges; in palm mode gutters contribute no overlap area
  /// to any cell, which simply reduces noise.
  final double gutter;

  GridGeometry({
    required this.rows,
    required this.cols,
    required this.bounds,
    this.gutter = 8,
  });

  bool get isValid => rows > 0 && cols > 0 && bounds.area > 0;

  double get cellWidth {
    if (isValid == false) {
      return 0;
    }

    return bounds.width / cols;
  }

  double get cellHeight {
    if (isValid == false) {
      return 0;
    }

    return bounds.height / rows;
  }

  /// The physical width of a cell in millimetres, given the display's true dpi.
  ///
  /// This is the figure that decides whether contact-area resolution can work at
  /// all: a cell smaller than the contact patch cannot be distinguished from its
  /// neighbours, no matter how good the arithmetic.
  double cellWidthMillimetres({
    required double xdpi,
    required double devicePixelRatio,
  }) {
    if (xdpi <= 0) {
      return 0;
    }

    return cellWidth * devicePixelRatio / xdpi * 25.4;
  }

  double cellHeightMillimetres({
    required double ydpi,
    required double devicePixelRatio,
  }) {
    if (ydpi <= 0) {
      return 0;
    }

    return cellHeight * devicePixelRatio / ydpi * 25.4;
  }

  /// The rectangle for a cell, inset by half the gutter on each side.
  ///
  /// Returns null for an out-of-range address rather than throwing, so a stale
  /// board reference cannot crash the communication path.
  Rect2? rectFor(CellAddress? address, {int rowSpan = 1, int colSpan = 1}) {
    if (address == null) {
      return null;
    }

    if (isValid == false) {
      return null;
    }

    if (address.row < 0 || address.row >= rows) {
      return null;
    }

    if (address.col < 0 || address.col >= cols) {
      return null;
    }

    final int safeRowSpan = rowSpan < 1 ? 1 : rowSpan;
    final int safeColSpan = colSpan < 1 ? 1 : colSpan;

    final int clampedRowSpan = address.row + safeRowSpan > rows
        ? rows - address.row
        : safeRowSpan;
    final int clampedColSpan = address.col + safeColSpan > cols
        ? cols - address.col
        : safeColSpan;

    final Rect2 outer = Rect2(
      left: bounds.left + address.col * cellWidth,
      top: bounds.top + address.row * cellHeight,
      width: cellWidth * clampedColSpan,
      height: cellHeight * clampedRowSpan,
    );

    return outer.deflate(gutter / 2);
  }

  /// Every cell in the grid, row-major.
  ///
  /// Empty cells are included: a board never collapses gaps, so an unoccupied
  /// position still exists and still occupies space.
  List<PositionedCell> allCells() {
    if (isValid == false) {
      return <PositionedCell>[];
    }

    final List<PositionedCell> cells = <PositionedCell>[];

    for (int row = 0; row < rows; row = row + 1) {
      for (int col = 0; col < cols; col = col + 1) {
        final CellAddress address = CellAddress(row: row, col: col);
        final Rect2? rect = rectFor(address);

        if (rect == null) {
          continue;
        }

        cells.add(PositionedCell(address: address, rect: rect));
      }
    }

    return cells;
  }

  /// The cell containing [point], ignoring contact size. This is point mode, and
  /// returns null when the point lands in a gutter.
  CellAddress? cellAt(Point2? point) {
    if (point == null) {
      return null;
    }

    if (isValid == false) {
      return null;
    }

    for (final PositionedCell cell in allCells()) {
      if (cell.rect.contains(point)) {
        return cell.address;
      }
    }

    return null;
  }

  @override
  String toString() => 'GridGeometry(${rows}x$cols, $bounds, gutter: $gutter)';
}
