import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:touch_spike/models/touch_sample.dart';
import 'package:touch_spike/services/session_recorder.dart';

/// Builds a synthetic pointer-down event with explicit contact geometry.
///
/// This is the capability the whole Android-first, Flutter choice rests on:
/// contact geometry can be fabricated exactly, headlessly, on a development
/// machine with no device attached. The palm-mode resolver in the main app will
/// be developed against tests shaped like these.
PointerDownEvent _down({
  required int pointer,
  required double x,
  required double y,
  required double radiusMajor,
  double radiusMinor = 0,
  double pressure = 1.0,
  double size = 0,
  Duration timeStamp = Duration.zero,
}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset(x, y),
    radiusMajor: radiusMajor,
    radiusMinor: radiusMinor == 0 ? radiusMajor : radiusMinor,
    pressure: pressure,
    size: size,
    timeStamp: timeStamp,
  );
}

PointerUpEvent _up({
  required int pointer,
  required double x,
  required double y,
  Duration timeStamp = Duration.zero,
}) {
  return PointerUpEvent(
    pointer: pointer,
    position: Offset(x, y),
    timeStamp: timeStamp,
  );
}

void main() {
  group('TouchSample', () {
    test('returns null for a null event rather than throwing', () {
      final TouchSample? sample = TouchSample.fromEvent(
        event: null,
        sequence: 0,
        millisSinceSessionStart: 0,
      );

      expect(sample, isNull);
    });

    test('captures contact geometry from a pointer down event', () {
      final TouchSample? sample = TouchSample.fromEvent(
        event: _down(
          pointer: 3,
          x: 120,
          y: 240,
          radiusMajor: 42.5,
          radiusMinor: 30,
        ),
        sequence: 7,
        millisSinceSessionStart: 1234,
      );

      expect(sample, isNotNull);
      expect(sample!.sequence, 7);
      expect(sample.millisSinceSessionStart, 1234);
      expect(sample.pointerId, 3);
      expect(sample.phase, TouchPhase.down);
      expect(sample.x, 120);
      expect(sample.y, 240);
      expect(sample.radiusMajor, 42.5);
      expect(sample.radiusMinor, 30);
    });

    test('CSV row has the same field count as the header', () {
      final TouchSample sample = TouchSample.fromEvent(
        event: _down(pointer: 1, x: 10, y: 20, radiusMajor: 15),
        sequence: 0,
        millisSinceSessionStart: 0,
      )!;

      final String row = sample.toCsvRow(
        sessionId: 'abc',
        sessionLabel: 'slap',
        devicePixelRatio: 2.0,
        xdpi: 254.0,
        ydpi: 254.0,
      );

      expect(row.split(',').length, TouchSample.csvHeader.split(',').length);
    });

    test('emits both millimetre interpretations of the reported radius', () {
      // 254 dpi means exactly 10 pixels per millimetre, chosen so the expected
      // values are obvious by inspection rather than by replicating the maths.
      final TouchSample sample = TouchSample.fromEvent(
        event: _down(pointer: 1, x: 0, y: 0, radiusMajor: 100),
        sequence: 0,
        millisSinceSessionStart: 0,
      )!;

      final List<String> fields = sample
          .toCsvRow(
            sessionId: 's',
            sessionLabel: 'l',
            devicePixelRatio: 2.0,
            xdpi: 254.0,
            ydpi: 254.0,
          )
          .split(',');

      final double assumingLogical = double.parse(fields[fields.length - 2]);
      final double assumingPhysical = double.parse(fields[fields.length - 1]);

      // Logical interpretation scales by devicePixelRatio first: 100 * 2 = 200px
      // = 20mm. Physical interpretation takes the value as-is: 100px = 10mm.
      expect(assumingLogical, closeTo(20.0, 0.001));
      expect(assumingPhysical, closeTo(10.0, 0.001));
    });

    test('escapes commas in session labels so the CSV stays parseable', () {
      final TouchSample sample = TouchSample.fromEvent(
        event: _down(pointer: 1, x: 0, y: 0, radiusMajor: 5),
        sequence: 0,
        millisSinceSessionStart: 0,
      )!;

      final String row = sample.toCsvRow(
        sessionId: 's',
        sessionLabel: 'slap, left hand',
        devicePixelRatio: 1.0,
        xdpi: 100,
        ydpi: 100,
      );

      expect(row, contains('"slap, left hand"'));
      expect(
        row.split(',').length,
        greaterThan(TouchSample.csvHeader.split(',').length),
      );
    });
  });

  group('SessionRecorder', () {
    test('ignores null events without throwing', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      expect(recorder.record(null), isNull);
      expect(recorder.sampleCount, 0);
    });

    test('reports empty stats before anything is captured', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );
      final SessionStats stats = recorder.computeStats();

      expect(stats.totalEvents, 0);
      expect(stats.verdict, contains('No touches captured'));
    });

    test('flags a device that reports no contact radius at all', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 0));
      recorder.record(_up(pointer: 1, x: 10, y: 10));

      final SessionStats stats = recorder.computeStats();

      expect(stats.anyRadiusReported, isFalse);
      expect(stats.verdict, contains('PROBLEM'));
      expect(stats.verdict, contains('no contact radius'));
    });

    test('flags a constant placeholder radius as unusable', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 12));
      recorder.record(_up(pointer: 1, x: 10, y: 10));
      recorder.record(_down(pointer: 2, x: 90, y: 90, radiusMajor: 12));
      recorder.record(_up(pointer: 2, x: 90, y: 90));

      final SessionStats stats = recorder.computeStats();

      expect(stats.anyRadiusReported, isTrue);
      expect(stats.radiusIsConstant, isTrue);
      expect(stats.verdict, contains('never varies'));
    });

    test('accepts a radius that varies between a point and a slap', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 8));
      recorder.record(_up(pointer: 1, x: 10, y: 10));
      recorder.record(_down(pointer: 2, x: 90, y: 90, radiusMajor: 55));
      recorder.record(_up(pointer: 2, x: 90, y: 90));

      final SessionStats stats = recorder.computeStats();

      expect(stats.anyRadiusReported, isTrue);
      expect(stats.radiusIsConstant, isFalse);
      expect(stats.radiusMajorMin, 8);
      expect(stats.radiusMajorMax, 55);
      expect(stats.radiusMajorMean, closeTo(31.5, 0.001));
      expect(stats.verdict, contains('usable'));
    });

    test('counts concurrent pointers, as a palm slap produces', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'slap',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 30));
      recorder.record(_down(pointer: 2, x: 40, y: 12, radiusMajor: 28));
      recorder.record(_down(pointer: 3, x: 70, y: 15, radiusMajor: 33));
      recorder.record(_up(pointer: 2, x: 40, y: 12));
      recorder.record(_up(pointer: 1, x: 10, y: 10));
      recorder.record(_up(pointer: 3, x: 70, y: 15));

      final SessionStats stats = recorder.computeStats();

      expect(stats.maxConcurrentPointers, 3);
      expect(stats.downCount, 3);
      expect(stats.upCount, 3);
    });

    test('records a gap for every down after the first', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'slap',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 30));
      recorder.record(_down(pointer: 2, x: 40, y: 12, radiusMajor: 28));
      recorder.record(_down(pointer: 3, x: 70, y: 15, radiusMajor: 33));

      final SessionStats stats = recorder.computeStats();

      expect(stats.downToDownGapsMillis.length, 2);
    });

    test('does not record a contact duration for an unmatched up event', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_up(pointer: 99, x: 10, y: 10));

      final SessionStats stats = recorder.computeStats();

      expect(stats.contactDurationsMillis, isEmpty);
      expect(stats.upCount, 1);
    });

    test('reset discards everything and restarts the sequence', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 20));
      recorder.record(_up(pointer: 1, x: 10, y: 10));
      expect(recorder.sampleCount, 2);

      recorder.reset();

      expect(recorder.sampleCount, 0);
      expect(recorder.computeStats().totalEvents, 0);
      expect(recorder.activePointerIds, isEmpty);

      final TouchSample? sample = recorder.record(
        _down(pointer: 5, x: 1, y: 1, radiusMajor: 9),
      );

      expect(sample!.sequence, 0);
    });

    test('tracks which pointers are currently down', () {
      final SessionRecorder recorder = SessionRecorder(
        sessionId: 's',
        label: 'test',
      );

      recorder.record(_down(pointer: 1, x: 10, y: 10, radiusMajor: 20));
      recorder.record(_down(pointer: 2, x: 20, y: 20, radiusMajor: 20));
      expect(recorder.activePointerIds.toSet(), <int>{1, 2});

      recorder.record(_up(pointer: 1, x: 10, y: 10));
      expect(recorder.activePointerIds.toSet(), <int>{2});
    });
  });
}
