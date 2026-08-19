import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/touch_sample.dart';

/// Draws the live contact patches and a fading trail of recent touch-down
/// points.
///
/// The ellipse is the whole point of the visualisation: it shows, at a glance
/// and on the device itself, whether the reported contact geometry actually
/// tracks the size of what is touching the screen. A palm should draw a
/// visibly larger ellipse than a fingertip. If it does not, the hardware is
/// not giving us what palm mode needs, and that is visible immediately without
/// waiting to analyse a CSV.
class ContactPainter extends CustomPainter {
  /// Currently active contacts, keyed by pointer id.
  final List<TouchSample> live;

  /// Recent touch-down positions, oldest first.
  final List<TouchSample> trail;

  /// Fallback radius in logical pixels, drawn as a dashed reference circle when
  /// the device reports no usable radius.
  final double fallbackRadius;

  ContactPainter({
    required this.live,
    required this.trail,
    required this.fallbackRadius,
  });

  static const List<Color> _pointerColours = <Color>[
    Color(0xFF4FC3F7),
    Color(0xFFFFB74D),
    Color(0xFF81C784),
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFFDCE775),
    Color(0xFFF06292),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrail(canvas);
    _paintLiveContacts(canvas);
  }

  void _paintTrail(Canvas canvas) {
    if (trail.isEmpty) {
      return;
    }

    final int count = trail.length;

    for (int i = 0; i < count; i = i + 1) {
      final TouchSample sample = trail[i];

      // Oldest entries fade out; newest is close to fully opaque.
      final double age = (i + 1) / count;
      final Paint paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + 0.22 * age)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(sample.x, sample.y), 6, paint);
    }
  }

  void _paintLiveContacts(Canvas canvas) {
    if (live.isEmpty) {
      return;
    }

    for (final TouchSample sample in live) {
      final Color colour =
          _pointerColours[sample.pointerId % _pointerColours.length];
      final Offset centre = Offset(sample.x, sample.y);

      final bool hasRadius = sample.radiusMajor > 0;
      final double major = hasRadius ? sample.radiusMajor : fallbackRadius;
      final double minor = sample.radiusMinor > 0 ? sample.radiusMinor : major;

      _paintEllipse(
        canvas: canvas,
        centre: centre,
        major: major,
        minor: minor,
        orientation: sample.orientation,
        colour: colour,
        isMeasured: hasRadius,
      );

      _paintCrosshair(canvas: canvas, centre: centre, colour: colour);
      _paintLabel(
        canvas: canvas,
        sample: sample,
        colour: colour,
        radius: major,
      );
    }
  }

  void _paintEllipse({
    required Canvas canvas,
    required Offset centre,
    required double major,
    required double minor,
    required double orientation,
    required Color colour,
    required bool isMeasured,
  }) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(orientation);

    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: math.max(minor, 2) * 2,
      height: math.max(major, 2) * 2,
    );

    final Paint fill = Paint()
      ..color = colour.withValues(alpha: isMeasured ? 0.22 : 0.08)
      ..style = PaintingStyle.fill;

    final Paint stroke = Paint()
      ..color = colour.withValues(alpha: isMeasured ? 0.95 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMeasured ? 2.5 : 1.5;

    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
    canvas.restore();
  }

  void _paintCrosshair({
    required Canvas canvas,
    required Offset centre,
    required Color colour,
  }) {
    final Paint paint = Paint()
      ..color = colour
      ..strokeWidth = 1.5;

    canvas.drawLine(centre.translate(-14, 0), centre.translate(14, 0), paint);
    canvas.drawLine(centre.translate(0, -14), centre.translate(0, 14), paint);
  }

  void _paintLabel({
    required Canvas canvas,
    required TouchSample sample,
    required Color colour,
    required double radius,
  }) {
    final String text = sample.radiusMajor > 0
        ? 'p${sample.pointerId}  r=${sample.radiusMajor.toStringAsFixed(1)}'
        : 'p${sample.pointerId}  r=none';

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colour,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: const <Shadow>[Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
    painter.paint(canvas, Offset(sample.x + radius + 8, sample.y - 8));
  }

  @override
  bool shouldRepaint(covariant ContactPainter oldDelegate) {
    // Repaint on every frame the parent rebuilds: contacts change continuously
    // and comparing sample lists costs more than repainting.
    return true;
  }
}
