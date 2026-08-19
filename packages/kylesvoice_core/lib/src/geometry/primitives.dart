import 'dart:math' as math;

/// A point in logical pixels.
///
/// Defined here rather than reusing `dart:ui`'s `Offset` so this package stays
/// free of any Flutter dependency and can be tested headlessly.
class Point2 {
  final double x;
  final double y;

  const Point2(this.x, this.y);

  static const Point2 zero = Point2(0, 0);

  Point2 operator +(Point2 other) => Point2(x + other.x, y + other.y);

  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);

  Point2 operator *(double scale) => Point2(x * scale, y * scale);

  double get length => math.sqrt(x * x + y * y);

  double distanceTo(Point2 other) => (this - other).length;

  /// Rotates about the origin by [radians].
  Point2 rotated(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);

    return Point2(x * c - y * s, x * s + y * c);
  }

  /// Divides each axis independently. Used to turn an ellipse into a unit
  /// circle; [sx] and [sy] must be non-zero.
  Point2 scaledBy({required double sx, required double sy}) {
    if (sx == 0 || sy == 0) {
      return this;
    }

    return Point2(x / sx, y / sy);
  }

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      other is Point2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// An axis-aligned rectangle in logical pixels.
class Rect2 {
  final double left;
  final double top;
  final double width;
  final double height;

  const Rect2({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;

  double get bottom => top + height;

  double get area => width <= 0 || height <= 0 ? 0 : width * height;

  Point2 get centre => Point2(left + width / 2, top + height / 2);

  /// The four corners, counter-clockwise in screen coordinates.
  List<Point2> get corners => <Point2>[
    Point2(left, top),
    Point2(right, top),
    Point2(right, bottom),
    Point2(left, bottom),
  ];

  bool contains(Point2 p) {
    if (p.x < left || p.x > right) {
      return false;
    }

    if (p.y < top || p.y > bottom) {
      return false;
    }

    return true;
  }

  /// Shrinks the rectangle by [amount] on every side, clamped at zero size.
  Rect2 deflate(double amount) {
    final double newWidth = width - amount * 2;
    final double newHeight = height - amount * 2;

    if (newWidth <= 0 || newHeight <= 0) {
      return Rect2(
        left: left + width / 2,
        top: top + height / 2,
        width: 0,
        height: 0,
      );
    }

    return Rect2(
      left: left + amount,
      top: top + amount,
      width: newWidth,
      height: newHeight,
    );
  }

  @override
  String toString() =>
      'Rect2(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${width.toStringAsFixed(1)} x ${height.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      other is Rect2 &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}
