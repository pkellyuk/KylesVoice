import 'dart:math' as math;

import '../geometry/contact_ellipse.dart';
import '../geometry/primitives.dart';

/// One contact within a composite, with the pointer that produced it.
class ClusteredContact {
  final ContactEllipse ellipse;
  final int pointerId;
  final int timestampMillis;

  const ClusteredContact({
    required this.ellipse,
    required this.pointerId,
    required this.timestampMillis,
  });

  @override
  String toString() =>
      'ClusteredContact(p$pointerId @${timestampMillis}ms, $ellipse)';
}

/// Everything one hand landing on the glass produced, treated as a single act.
///
/// This model comes directly from measurement rather than assumption. See
/// `docs/FINDINGS-TOUCH.md`: a palm slap does not register as one large contact
/// ellipse. Every captured slap arrived as six separate simultaneous contacts —
/// fingers, knuckles and the heel of the hand each landing as their own pointer
/// — scattered across roughly 42 x 46 mm. Half of those individual contacts are
/// indistinguishable from a deliberate fingertip tap, because they are
/// fingertips.
///
/// Resolving each pointer separately therefore cannot work, and picking the
/// first pointer to arrive is worse: in two of three measured slaps the first
/// contact was not the largest, so first-wins aims at an arbitrary fingertip
/// rather than the heel of the hand.
class CompositeContact {
  final List<ClusteredContact> contacts;

  const CompositeContact({required this.contacts});

  bool get isEmpty => contacts.isEmpty;

  /// Number of simultaneous contacts.
  ///
  /// This is the single most reliable palm indicator found in the capture data:
  /// six contacts inside 16 ms was unambiguously a slap, where deliberate
  /// tapping produced one. It is a better signal than any individual contact's
  /// radius, which varied by a factor of nine within a single slap.
  int get contactCount => contacts.length;

  /// Milliseconds between the first and last contact landing.
  int get spanMillis {
    if (contacts.isEmpty) {
      return 0;
    }

    int earliest = contacts.first.timestampMillis;
    int latest = contacts.first.timestampMillis;

    for (final ClusteredContact c in contacts) {
      earliest = math.min(earliest, c.timestampMillis);
      latest = math.max(latest, c.timestampMillis);
    }

    return latest - earliest;
  }

  int get firstTimestampMillis {
    if (contacts.isEmpty) {
      return 0;
    }

    return contacts
        .map((ClusteredContact c) => c.timestampMillis)
        .reduce(math.min);
  }

  /// Combined area of every contact, in square logical pixels.
  double get totalArea {
    double total = 0;

    for (final ClusteredContact c in contacts) {
      total = total + c.ellipse.area;
    }

    return total;
  }

  /// The largest single contact, which for a slap is typically the heel of the
  /// hand. Null only when the composite is empty.
  ClusteredContact? get largest {
    if (contacts.isEmpty) {
      return null;
    }

    ClusteredContact biggest = contacts.first;

    for (final ClusteredContact c in contacts) {
      if (c.ellipse.area > biggest.ellipse.area) {
        biggest = c;
      }
    }

    return biggest;
  }

  /// Centroid of the contacts, weighted by contact area, so the heel of the hand
  /// pulls the result toward itself more than a grazing fingertip does.
  Point2 get areaWeightedCentroid {
    if (contacts.isEmpty) {
      return Point2.zero;
    }

    double weightSum = 0;
    double x = 0;
    double y = 0;

    for (final ClusteredContact c in contacts) {
      final double weight = c.ellipse.area;

      if (weight <= 0) {
        continue;
      }

      weightSum = weightSum + weight;
      x = x + c.ellipse.centre.x * weight;
      y = y + c.ellipse.centre.y * weight;
    }

    if (weightSum <= 0) {
      // Every contact had zero area: fall back to an unweighted mean rather
      // than reporting the origin.
      double sx = 0;
      double sy = 0;

      for (final ClusteredContact c in contacts) {
        sx = sx + c.ellipse.centre.x;
        sy = sy + c.ellipse.centre.y;
      }

      return Point2(sx / contacts.length, sy / contacts.length);
    }

    return Point2(x / weightSum, y / weightSum);
  }

  /// Axis-aligned box enclosing every contact centre. This is the hand's
  /// footprint, and is what should be compared against cell size when deciding
  /// whether a grid is too fine for the user.
  Rect2 get footprint {
    if (contacts.isEmpty) {
      return const Rect2(left: 0, top: 0, width: 0, height: 0);
    }

    double minX = contacts.first.ellipse.centre.x;
    double maxX = minX;
    double minY = contacts.first.ellipse.centre.y;
    double maxY = minY;

    for (final ClusteredContact c in contacts) {
      minX = math.min(minX, c.ellipse.centre.x);
      maxX = math.max(maxX, c.ellipse.centre.x);
      minY = math.min(minY, c.ellipse.centre.y);
      maxY = math.max(maxY, c.ellipse.centre.y);
    }

    return Rect2(
      left: minX,
      top: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Footprint diagonal in millimetres, for comparison against the measured
  /// 42 x 46 mm adult slap.
  double footprintWidthMillimetres({
    required double xdpi,
    required double devicePixelRatio,
  }) {
    if (xdpi <= 0) {
      return 0;
    }

    return footprint.width * devicePixelRatio / xdpi * 25.4;
  }

  /// Builds a composite from a single contact, for the ordinary one-finger case.
  static CompositeContact single({
    required ContactEllipse ellipse,
    required int pointerId,
    required int timestampMillis,
  }) {
    return CompositeContact(
      contacts: <ClusteredContact>[
        ClusteredContact(
          ellipse: ellipse,
          pointerId: pointerId,
          timestampMillis: timestampMillis,
        ),
      ],
    );
  }

  static const CompositeContact empty = CompositeContact(
    contacts: <ClusteredContact>[],
  );

  @override
  String toString() =>
      'CompositeContact($contactCount contacts over ${spanMillis}ms, '
      'footprint ${footprint.width.toStringAsFixed(0)}x'
      '${footprint.height.toStringAsFixed(0)})';
}
