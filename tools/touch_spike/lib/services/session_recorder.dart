import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../log.dart';
import '../models/touch_sample.dart';

/// Summary statistics for a capture session.
///
/// These are the numbers the spike exists to produce: they decide whether
/// contact-area resolution is viable on the target hardware, and they seed the
/// resolver's calibration constants.
class SessionStats {
  final int totalEvents;
  final int downCount;
  final int moveCount;
  final int upCount;
  final int cancelCount;

  /// True if any event reported a non-zero contact radius. If this is false on
  /// the target device, palm mode as designed cannot work and needs rethinking.
  final bool anyRadiusReported;

  /// True if every reported radius was identical. Some drivers report a
  /// constant placeholder, which is just as useless as reporting nothing.
  final bool radiusIsConstant;

  final double radiusMajorMin;
  final double radiusMajorMax;
  final double radiusMajorMean;

  final double pressureMin;
  final double pressureMax;

  final double sizeMin;
  final double sizeMax;

  /// Highest number of pointers down simultaneously. A palm slap typically
  /// registers several.
  final int maxConcurrentPointers;

  /// Gaps between consecutive down events, in milliseconds. Short gaps are
  /// bounce, and set the post-activation lockout.
  final List<int> downToDownGapsMillis;

  /// How long each contact lasted, in milliseconds. Informs dwell settings.
  final List<int> contactDurationsMillis;

  const SessionStats({
    required this.totalEvents,
    required this.downCount,
    required this.moveCount,
    required this.upCount,
    required this.cancelCount,
    required this.anyRadiusReported,
    required this.radiusIsConstant,
    required this.radiusMajorMin,
    required this.radiusMajorMax,
    required this.radiusMajorMean,
    required this.pressureMin,
    required this.pressureMax,
    required this.sizeMin,
    required this.sizeMax,
    required this.maxConcurrentPointers,
    required this.downToDownGapsMillis,
    required this.contactDurationsMillis,
  });

  static const SessionStats empty = SessionStats(
    totalEvents: 0,
    downCount: 0,
    moveCount: 0,
    upCount: 0,
    cancelCount: 0,
    anyRadiusReported: false,
    radiusIsConstant: false,
    radiusMajorMin: 0,
    radiusMajorMax: 0,
    radiusMajorMean: 0,
    pressureMin: 0,
    pressureMax: 0,
    sizeMin: 0,
    sizeMax: 0,
    maxConcurrentPointers: 0,
    downToDownGapsMillis: <int>[],
    contactDurationsMillis: <int>[],
  );

  /// The headline verdict, in plain language, for whoever is holding the
  /// tablet rather than reading the CSV.
  String get verdict {
    if (totalEvents == 0) {
      return 'No touches captured yet.';
    }

    if (anyRadiusReported == false) {
      return 'PROBLEM: this device reports no contact radius at all. '
          'Palm mode needs a different approach on this hardware.';
    }

    if (radiusIsConstant == true) {
      return 'PROBLEM: contact radius is reported but never varies '
          '(always ${radiusMajorMax.toStringAsFixed(2)}). It is a placeholder, '
          'not a measurement.';
    }

    return 'Looks usable: radius varies from '
        '${radiusMajorMin.toStringAsFixed(2)} to '
        '${radiusMajorMax.toStringAsFixed(2)}.';
  }
}

/// Accumulates pointer events for one capture session and derives statistics.
///
/// Deliberately holds everything in memory: a session is a few thousand rows at
/// most, and keeping the capture path free of I/O avoids perturbing the timing
/// measurements.
class SessionRecorder {
  final String sessionId;
  final String label;
  final DateTime startedAt;

  final List<TouchSample> _samples = <TouchSample>[];
  final Stopwatch _clock = Stopwatch();

  /// Pointer id to the millisecond offset at which it went down. Used to derive
  /// contact durations and concurrency.
  final Map<int, int> _activePointers = <int, int>{};

  int _sequence = 0;
  int _maxConcurrentPointers = 0;
  int? _lastDownMillis;
  final List<int> _downToDownGaps = <int>[];
  final List<int> _contactDurations = <int>[];

  SessionRecorder({required this.sessionId, required this.label})
    : startedAt = DateTime.now() {
    Log.enter('SessionRecorder.ctor', 'sessionId=$sessionId label=$label');
    _clock.start();
    Log.exit('SessionRecorder.ctor', 'clock started at $startedAt');
  }

  List<TouchSample> get samples => List<TouchSample>.unmodifiable(_samples);

  int get sampleCount => _samples.length;

  /// Pointer ids currently down, for live visualisation.
  Iterable<int> get activePointerIds => _activePointers.keys;

  /// Records a pointer event. Returns the stored sample, or null if the event
  /// was null or of an untracked type.
  ///
  /// This is the hot path. It performs no I/O and no allocation beyond the
  /// sample itself, and logs only when [Log.verbose] is enabled.
  TouchSample? record(PointerEvent? event) {
    if (event == null) {
      Log.warn('SessionRecorder.record', 'null event ignored');
      return null;
    }

    final int elapsed = _clock.elapsedMilliseconds;

    final TouchSample? sample = TouchSample.fromEvent(
      event: event,
      sequence: _sequence,
      millisSinceSessionStart: elapsed,
    );

    if (sample == null) {
      return null;
    }

    _sequence = _sequence + 1;
    _samples.add(sample);

    _updateDerivedMetrics(sample: sample, elapsed: elapsed);

    Log.hot(
      'SessionRecorder.record',
      'seq=${sample.sequence} phase=${sample.phase.name} ptr=${sample.pointerId} '
          'pos=(${sample.x.toStringAsFixed(1)},${sample.y.toStringAsFixed(1)}) '
          'rMajor=${sample.radiusMajor.toStringAsFixed(2)} '
          'rMinor=${sample.radiusMinor.toStringAsFixed(2)} '
          'size=${sample.size.toStringAsFixed(3)} '
          'pressure=${sample.pressure.toStringAsFixed(3)}',
    );

    return sample;
  }

  void _updateDerivedMetrics({
    required TouchSample sample,
    required int elapsed,
  }) {
    if (sample.phase == TouchPhase.down) {
      _activePointers[sample.pointerId] = elapsed;

      if (_activePointers.length > _maxConcurrentPointers) {
        _maxConcurrentPointers = _activePointers.length;
      }

      final int? previousDown = _lastDownMillis;

      if (previousDown != null) {
        _downToDownGaps.add(elapsed - previousDown);
      }

      _lastDownMillis = elapsed;
      return;
    }

    if (sample.phase == TouchPhase.up || sample.phase == TouchPhase.cancel) {
      final int? downAt = _activePointers.remove(sample.pointerId);

      if (downAt == null) {
        return;
      }

      _contactDurations.add(elapsed - downAt);
    }
  }

  /// Computes summary statistics over everything captured so far.
  SessionStats computeStats() {
    if (_samples.isEmpty) {
      return SessionStats.empty;
    }

    int downCount = 0;
    int moveCount = 0;
    int upCount = 0;
    int cancelCount = 0;

    double radiusMin = double.infinity;
    double radiusMax = double.negativeInfinity;
    double radiusSum = 0;
    int radiusSamples = 0;
    bool anyRadius = false;

    double pressureMin = double.infinity;
    double pressureMax = double.negativeInfinity;
    double sizeMin = double.infinity;
    double sizeMax = double.negativeInfinity;

    for (final TouchSample sample in _samples) {
      switch (sample.phase) {
        case TouchPhase.down:
          downCount = downCount + 1;
        case TouchPhase.move:
          moveCount = moveCount + 1;
        case TouchPhase.up:
          upCount = upCount + 1;
        case TouchPhase.cancel:
          cancelCount = cancelCount + 1;
      }

      if (sample.radiusMajor > 0) {
        anyRadius = true;
        radiusMin = math.min(radiusMin, sample.radiusMajor);
        radiusMax = math.max(radiusMax, sample.radiusMajor);
        radiusSum = radiusSum + sample.radiusMajor;
        radiusSamples = radiusSamples + 1;
      }

      pressureMin = math.min(pressureMin, sample.pressure);
      pressureMax = math.max(pressureMax, sample.pressure);
      sizeMin = math.min(sizeMin, sample.size);
      sizeMax = math.max(sizeMax, sample.size);
    }

    final double radiusMean = radiusSamples > 0 ? radiusSum / radiusSamples : 0;
    final bool constantRadius =
        anyRadius == true &&
        radiusSamples > 1 &&
        (radiusMax - radiusMin).abs() < 0.0001;

    return SessionStats(
      totalEvents: _samples.length,
      downCount: downCount,
      moveCount: moveCount,
      upCount: upCount,
      cancelCount: cancelCount,
      anyRadiusReported: anyRadius,
      radiusIsConstant: constantRadius,
      radiusMajorMin: anyRadius ? radiusMin : 0,
      radiusMajorMax: anyRadius ? radiusMax : 0,
      radiusMajorMean: radiusMean,
      pressureMin: pressureMin.isFinite ? pressureMin : 0,
      pressureMax: pressureMax.isFinite ? pressureMax : 0,
      sizeMin: sizeMin.isFinite ? sizeMin : 0,
      sizeMax: sizeMax.isFinite ? sizeMax : 0,
      maxConcurrentPointers: _maxConcurrentPointers,
      downToDownGapsMillis: List<int>.unmodifiable(_downToDownGaps),
      contactDurationsMillis: List<int>.unmodifiable(_contactDurations),
    );
  }

  /// Discards all captured data and restarts the session clock.
  void reset() {
    Log.enter('SessionRecorder.reset', 'discarding ${_samples.length} samples');

    _samples.clear();
    _activePointers.clear();
    _downToDownGaps.clear();
    _contactDurations.clear();
    _sequence = 0;
    _maxConcurrentPointers = 0;
    _lastDownMillis = null;
    _clock.reset();
    _clock.start();

    Log.exit('SessionRecorder.reset');
  }
}
