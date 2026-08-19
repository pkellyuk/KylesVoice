import 'package:flutter/gestures.dart';

import '../log.dart';

/// The lifecycle phase of a captured pointer event.
enum TouchPhase { down, move, up, cancel }

/// A single captured pointer event, with every geometry field the Flutter
/// engine exposes.
///
/// This is deliberately a flat, dumb record. The whole point of the spike is to
/// see the raw numbers, so nothing is normalised, clamped or interpreted here.
class TouchSample {
  final int sequence;
  final int millisSinceSessionStart;
  final int engineTimeStampMicros;
  final int pointerId;
  final TouchPhase phase;
  final String deviceKind;

  /// Position in logical pixels, local to the capture surface.
  final double x;
  final double y;

  /// Contact geometry as reported by the engine.
  ///
  /// On Android these originate from `MotionEvent`. Whether they arrive in
  /// logical or physical pixels, and whether the underlying source is
  /// `getToolMajor` or `getTouchMajor`, is precisely what this spike is
  /// measuring: do not assume.
  final double radiusMajor;
  final double radiusMinor;
  final double radiusMin;
  final double radiusMax;

  /// `MotionEvent.getSize()` equivalent: a normalised contact size, 0..1 on
  /// most Android drivers.
  final double size;

  final double pressure;
  final double pressureMin;
  final double pressureMax;

  final double orientation;
  final double tilt;
  final int buttons;
  final bool synthesized;

  const TouchSample({
    required this.sequence,
    required this.millisSinceSessionStart,
    required this.engineTimeStampMicros,
    required this.pointerId,
    required this.phase,
    required this.deviceKind,
    required this.x,
    required this.y,
    required this.radiusMajor,
    required this.radiusMinor,
    required this.radiusMin,
    required this.radiusMax,
    required this.size,
    required this.pressure,
    required this.pressureMin,
    required this.pressureMax,
    required this.orientation,
    required this.tilt,
    required this.buttons,
    required this.synthesized,
  });

  /// Builds a sample from a raw [PointerEvent].
  ///
  /// Returns null if [event] is null or the phase is not one we record.
  static TouchSample? fromEvent({
    required PointerEvent? event,
    required int sequence,
    required int millisSinceSessionStart,
  }) {
    if (event == null) {
      Log.warn('TouchSample.fromEvent', 'null event, skipping');
      return null;
    }

    final TouchPhase? phase = _phaseOf(event);

    if (phase == null) {
      Log.hot(
        'TouchSample.fromEvent',
        'unhandled event type ${event.runtimeType}, skipping',
      );
      return null;
    }

    return TouchSample(
      sequence: sequence,
      millisSinceSessionStart: millisSinceSessionStart,
      engineTimeStampMicros: event.timeStamp.inMicroseconds,
      pointerId: event.pointer,
      phase: phase,
      deviceKind: event.kind.name,
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
      radiusMin: event.radiusMin,
      radiusMax: event.radiusMax,
      size: event.size,
      pressure: event.pressure,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
      orientation: event.orientation,
      tilt: event.tilt,
      buttons: event.buttons,
      synthesized: event.synthesized,
    );
  }

  static TouchPhase? _phaseOf(PointerEvent event) {
    if (event is PointerDownEvent) {
      return TouchPhase.down;
    }

    if (event is PointerMoveEvent) {
      return TouchPhase.move;
    }

    if (event is PointerUpEvent) {
      return TouchPhase.up;
    }

    if (event is PointerCancelEvent) {
      return TouchPhase.cancel;
    }

    return null;
  }

  /// CSV header. Must stay in lockstep with [toCsvRow].
  static const String csvHeader =
      'session_id,session_label,sequence,ms_since_start,engine_ts_us,pointer_id,'
      'phase,device_kind,x_logical,y_logical,radius_major,radius_minor,'
      'radius_min,radius_max,size,pressure,pressure_min,pressure_max,'
      'orientation,tilt,buttons,synthesized,device_pixel_ratio,xdpi,ydpi,'
      'radius_major_mm_assuming_logical,radius_major_mm_assuming_physical';

  /// Renders this sample as a CSV row.
  ///
  /// Both millimetre interpretations are emitted deliberately. Until we know
  /// whether the engine hands us logical or physical pixels, recording both
  /// lets the calibration be settled from the data rather than from an
  /// assumption baked in at capture time.
  String toCsvRow({
    required String sessionId,
    required String sessionLabel,
    required double devicePixelRatio,
    required double xdpi,
    required double ydpi,
  }) {
    final double mmAssumingLogical = _toMillimetres(
      value: radiusMajor * devicePixelRatio,
      dpi: xdpi,
    );

    final double mmAssumingPhysical = _toMillimetres(
      value: radiusMajor,
      dpi: xdpi,
    );

    final List<String> fields = <String>[
      _escape(sessionId),
      _escape(sessionLabel),
      '$sequence',
      '$millisSinceSessionStart',
      '$engineTimeStampMicros',
      '$pointerId',
      phase.name,
      _escape(deviceKind),
      _num(x),
      _num(y),
      _num(radiusMajor),
      _num(radiusMinor),
      _num(radiusMin),
      _num(radiusMax),
      _num(size),
      _num(pressure),
      _num(pressureMin),
      _num(pressureMax),
      _num(orientation),
      _num(tilt),
      '$buttons',
      '$synthesized',
      _num(devicePixelRatio),
      _num(xdpi),
      _num(ydpi),
      _num(mmAssumingLogical),
      _num(mmAssumingPhysical),
    ];

    return fields.join(',');
  }

  static double _toMillimetres({required double value, required double dpi}) {
    if (dpi <= 0) {
      return 0;
    }

    return value / dpi * 25.4;
  }

  static String _num(double value) {
    if (value.isNaN) {
      return '';
    }

    if (value.isInfinite) {
      return '';
    }

    return value.toStringAsFixed(4);
  }

  static String _escape(String value) {
    if (value.contains(',') == false && value.contains('"') == false) {
      return value;
    }

    return '"${value.replaceAll('"', '""')}"';
  }
}
