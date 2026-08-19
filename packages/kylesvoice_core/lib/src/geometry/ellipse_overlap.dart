import 'dart:math' as math;

import 'contact_ellipse.dart';
import 'primitives.dart';

/// Exact area of intersection between a contact ellipse and a cell rectangle.
///
/// This is the arithmetic the entire palm-mode design rests on: given a contact
/// patch that straddles several cells, the cell with the greatest overlap is the
/// one the hand is mostly covering, and therefore the one to activate.
///
/// The method is exact rather than sampled. An affine transform turns the
/// ellipse into a unit circle at the origin, which turns the axis-aligned
/// rectangle into a parallelogram. Circle-versus-convex-polygon intersection
/// then has a closed form: decompose the polygon into triangles from the
/// circle's centre, and for each triangle add either the triangle, a circular
/// sector, or a combination, depending on where the edge crosses the circle.
/// Undoing the transform's scaling recovers the true area.
///
/// Exactness matters more than it might appear. An approximate result makes
/// near-ties between two cells resolve inconsistently, and a child whose word
/// sometimes lands on the wrong card learns that the system cannot be relied on.
class EllipseOverlap {
  /// Area, in square logical pixels, of the part of [ellipse] lying inside
  /// [rect]. Returns 0 for degenerate input rather than throwing.
  static double area({required ContactEllipse? ellipse, required Rect2? rect}) {
    if (ellipse == null) {
      return 0;
    }

    if (rect == null) {
      return 0;
    }

    if (rect.area <= 0) {
      return 0;
    }

    if (ellipse.radiusMajor <= 0 || ellipse.radiusMinor <= 0) {
      return 0;
    }

    // Map the ellipse to the unit circle at the origin. The rectangle's corners
    // follow the same transform and become a parallelogram, which is still
    // convex, so the closed form below still applies.
    final List<Point2> polygon = rect.corners
        .map(
          (Point2 corner) => (corner - ellipse.centre)
              .rotated(-ellipse.orientation)
              .scaledBy(sx: ellipse.radiusMinor, sy: ellipse.radiusMajor),
        )
        .toList(growable: false);

    final double unitArea = _unitCircleConvexPolygonArea(polygon);

    // The transform divided x by radiusMinor and y by radiusMajor, scaling area
    // by 1 / (minor * major). Multiply back to undo it.
    return unitArea * ellipse.radiusMinor * ellipse.radiusMajor;
  }

  /// Overlap as a fraction of the contact patch's total area, 0..1.
  ///
  /// Useful for deciding whether a contact meaningfully landed on a cell at all,
  /// independently of how large the contact was.
  static double fractionOfContact({
    required ContactEllipse? ellipse,
    required Rect2? rect,
  }) {
    if (ellipse == null) {
      return 0;
    }

    final double total = ellipse.area;

    if (total <= 0) {
      return 0;
    }

    return (area(ellipse: ellipse, rect: rect) / total).clamp(0.0, 1.0);
  }

  /// Area of intersection between the unit circle at the origin and a convex
  /// polygon, whose vertices may be in either winding order.
  static double _unitCircleConvexPolygonArea(List<Point2> polygon) {
    if (polygon.length < 3) {
      return 0;
    }

    double total = 0;

    for (int i = 0; i < polygon.length; i = i + 1) {
      final Point2 a = polygon[i];
      final Point2 b = polygon[(i + 1) % polygon.length];

      total = total + _circleTriangleSignedArea(a, b);
    }

    // Sign depends on winding order, which callers should not have to care about.
    return total.abs();
  }

  /// Signed area of the intersection between the unit circle at the origin and
  /// the triangle (origin, [a], [b]).
  static double _circleTriangleSignedArea(Point2 a, Point2 b) {
    final double distanceA = a.length;
    final double distanceB = b.length;

    // Both vertices inside: the whole triangle counts.
    if (distanceA <= 1.0 && distanceB <= 1.0) {
      return _cross(a, b) / 2;
    }

    final Point2 direction = b - a;
    final double quadA = direction.x * direction.x + direction.y * direction.y;

    // Degenerate edge: no area either way.
    if (quadA <= 0) {
      return 0;
    }

    final double quadB = 2 * (a.x * direction.x + a.y * direction.y);
    final double quadC = a.x * a.x + a.y * a.y - 1.0;
    final double discriminant = quadB * quadB - 4 * quadA * quadC;

    // The edge's infinite line misses the circle entirely, so the intersection
    // is purely the circular sector swept between the two directions.
    if (discriminant <= 0) {
      return _sectorSignedArea(a, b);
    }

    final double root = math.sqrt(discriminant);
    double tEnter = (-quadB - root) / (2 * quadA);
    double tExit = (-quadB + root) / (2 * quadA);

    // The crossing happens outside the segment, so again just a sector.
    if (tExit <= 0 || tEnter >= 1) {
      return _sectorSignedArea(a, b);
    }

    tEnter = tEnter.clamp(0.0, 1.0);
    tExit = tExit.clamp(0.0, 1.0);

    final Point2 enter = a + direction * tEnter;
    final Point2 exit = a + direction * tExit;

    // Outside the circle the region is a sector; the chord between the crossing
    // points bounds a straight-edged triangle.
    return _sectorSignedArea(a, enter) +
        _cross(enter, exit) / 2 +
        _sectorSignedArea(exit, b);
  }

  /// Signed area of the unit-circle sector swept from direction [a] to [b].
  static double _sectorSignedArea(Point2 a, Point2 b) {
    final double angle = math.atan2(_cross(a, b), a.x * b.x + a.y * b.y);

    return angle / 2;
  }

  static double _cross(Point2 a, Point2 b) => a.x * b.y - a.y * b.x;
}
