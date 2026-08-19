import 'dart:math' as math;

import 'primitives.dart';

/// The patch of glass a finger, thumb or palm is actually covering.
///
/// The resolver consumes only this, never raw platform fields. Every
/// platform-specific concern — Android's `MotionEvent` reporting contact size in
/// device-specific units, iOS exposing only `UITouch.majorRadius`, and devices
/// that report nothing usable at all — is dealt with when constructing this, so
/// the resolution logic downstream is platform-free and exactly testable.
///
/// [radiusMajor] lies along the ellipse's local y axis and [radiusMinor] along
/// its local x axis, rotated by [orientation]. This matches the convention used
/// when drawing the contact patch, so the visualisation and the maths cannot
/// silently disagree.
class ContactEllipse {
  final Point2 centre;
  final double radiusMajor;
  final double radiusMinor;
  final double orientation;

  /// False when the platform reported no usable contact size and a fallback
  /// radius was substituted. Recorded so the resolver can widen its ambiguity
  /// threshold, and so usage logging can distinguish measured from assumed.
  final bool isMeasured;

  const ContactEllipse({
    required this.centre,
    required this.radiusMajor,
    required this.radiusMinor,
    required this.orientation,
    required this.isMeasured,
  });

  /// Builds a contact patch from raw platform values.
  ///
  /// [reportedMajor] and [reportedMinor] are whatever the platform gave us, and
  /// may be zero, negative or nonsense. [calibrationScale] converts them into
  /// logical pixels; it is derived per device from captured data, because many
  /// Android touch drivers report in device-specific units rather than pixels.
  /// [fallbackRadius] is used when the platform reports nothing plausible.
  static ContactEllipse fromPlatform({
    required Point2? centre,
    required double reportedMajor,
    required double reportedMinor,
    double orientation = 0,
    double calibrationScale = 1.0,
    required double fallbackRadius,
  }) {
    final Point2 resolvedCentre = centre ?? Point2.zero;
    final double safeFallback = fallbackRadius > 0 ? fallbackRadius : 1.0;

    final double major = _sanitise(reportedMajor) * calibrationScale;
    final double minor = _sanitise(reportedMinor) * calibrationScale;

    if (major <= 0) {
      // Nothing usable reported: assume a circular contact of the configured
      // fallback size. Palm mode degrades to something close to point mode
      // rather than failing.
      return ContactEllipse(
        centre: resolvedCentre,
        radiusMajor: safeFallback,
        radiusMinor: safeFallback,
        orientation: 0,
        isMeasured: false,
      );
    }

    // Some drivers report a major axis but no minor. A circular contact is the
    // right assumption there, not a zero-width sliver.
    final double resolvedMinor = minor > 0 ? minor : major;

    return ContactEllipse(
      centre: resolvedCentre,
      radiusMajor: math.max(major, resolvedMinor),
      radiusMinor: math.min(major, resolvedMinor),
      orientation: orientation.isFinite ? orientation : 0,
      isMeasured: true,
    );
  }

  /// A circular contact, convenient for tests and for point mode.
  static ContactEllipse circular({
    required Point2 centre,
    required double radius,
    bool isMeasured = true,
  }) {
    final double safe = radius > 0 ? radius : 1.0;

    return ContactEllipse(
      centre: centre,
      radiusMajor: safe,
      radiusMinor: safe,
      orientation: 0,
      isMeasured: isMeasured,
    );
  }

  double get area => math.pi * radiusMajor * radiusMinor;

  /// Longest extent across the contact, in logical pixels.
  double get majorDiameter => radiusMajor * 2;

  /// Converts the major diameter to millimetres, given the display's true
  /// physical DPI. Note this must be the panel's real dpi, not a value derived
  /// from `devicePixelRatio`, which is bucketed on Android.
  double majorDiameterMillimetres({
    required double dpi,
    required double devicePixelRatio,
  }) {
    if (dpi <= 0) {
      return 0;
    }

    return majorDiameter * devicePixelRatio / dpi * 25.4;
  }

  @override
  String toString() =>
      'ContactEllipse(centre: $centre, major: ${radiusMajor.toStringAsFixed(1)}, '
      'minor: ${radiusMinor.toStringAsFixed(1)}, '
      'orientation: ${orientation.toStringAsFixed(2)}, measured: $isMeasured)';

  static double _sanitise(double value) {
    if (value.isNaN) {
      return 0;
    }

    if (value.isInfinite) {
      return 0;
    }

    if (value < 0) {
      return 0;
    }

    return value;
  }
}
