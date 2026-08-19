import 'dart:io';

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

/// Real capture from a Galaxy S24, committed at docs/captures/. See
/// docs/FINDINGS-TOUCH.md for how it was gathered and what it showed.
const String _slapCapture =
    '../../docs/captures/touch_20260819_155848_slap.csv';
const String _pointCapture =
    '../../docs/captures/touch_20260819_155644_point.csv';

/// True physical values for the capture device, from the file's metadata line.
const double _xdpi = 415.636;
const double _devicePixelRatio = 3.0;

class _Down {
  final int millis;
  final int pointerId;
  final ContactEllipse ellipse;

  const _Down({
    required this.millis,
    required this.pointerId,
    required this.ellipse,
  });
}

/// Reads the down events out of a capture file.
///
/// Replaying real hardware output is the only way to be sure the model matches
/// what devices actually do rather than what we assumed they would do. The
/// original single-ellipse design passed every synthetic test and was still
/// wrong.
List<_Down> _readDowns(String path) {
  final File file = File(path);

  if (file.existsSync() == false) {
    throw StateError('Capture fixture missing: $path');
  }

  final List<String> lines = file.readAsLinesSync();
  final List<_Down> downs = <_Down>[];
  List<String>? header;

  for (final String line in lines) {
    if (line.startsWith('#')) {
      continue;
    }

    if (line.trim().isEmpty) {
      continue;
    }

    final List<String> fields = line.split(',');

    if (header == null) {
      header = fields;
      continue;
    }

    int index(String name) => header!.indexOf(name);

    if (fields[index('phase')] != 'down') {
      continue;
    }

    downs.add(
      _Down(
        millis: int.parse(fields[index('ms_since_start')]),
        pointerId: int.parse(fields[index('pointer_id')]),
        ellipse: ContactEllipse.fromPlatform(
          centre: Point2(
            double.parse(fields[index('x_logical')]),
            double.parse(fields[index('y_logical')]),
          ),
          reportedMajor: double.parse(fields[index('radius_major')]),
          reportedMinor: double.parse(fields[index('radius_minor')]),
          fallbackRadius: 48,
        ),
      ),
    );
  }

  return downs;
}

/// Runs a capture through the coalescer and returns the composites it produced.
List<CompositeContact> _coalesce(List<_Down> downs, {int windowMillis = 50}) {
  final ContactCoalescer coalescer = ContactCoalescer(
    windowMillis: windowMillis,
  );
  final List<CompositeContact> composites = <CompositeContact>[];

  for (final _Down down in downs) {
    final CompositeContact? completed = coalescer.add(
      contact: down.ellipse,
      pointerId: down.pointerId,
      timestampMillis: down.millis,
    );

    if (completed != null) {
      composites.add(completed);
    }
  }

  final CompositeContact? last = coalescer.flush();

  if (last != null) {
    composites.add(last);
  }

  return composites;
}

GridGeometry _grid({double gutter = 0}) {
  return GridGeometry(
    rows: 2,
    cols: 3,
    bounds: const Rect2(left: 0, top: 0, width: 780, height: 360),
    gutter: gutter,
  );
}

ContactEllipse _at(double x, double y, double r) {
  return ContactEllipse.circular(centre: Point2(x, y), radius: r);
}

void main() {
  group('ContactCoalescer', () {
    test('a lone contact stays pending until flushed', () {
      final ContactCoalescer coalescer = ContactCoalescer(windowMillis: 50);

      expect(
        coalescer.add(
          contact: _at(10, 10, 5),
          pointerId: 1,
          timestampMillis: 0,
        ),
        isNull,
      );
      expect(coalescer.hasPending, isTrue);
      expect(coalescer.readyAtMillis, 50);

      final CompositeContact? flushed = coalescer.flush();

      expect(flushed, isNotNull);
      expect(flushed!.contactCount, 1);
      expect(coalescer.hasPending, isFalse);
    });

    test('contacts inside the window join one composite', () {
      final ContactCoalescer coalescer = ContactCoalescer(windowMillis: 50);

      coalescer.add(contact: _at(10, 10, 5), pointerId: 1, timestampMillis: 0);
      coalescer.add(contact: _at(20, 12, 5), pointerId: 2, timestampMillis: 12);
      coalescer.add(contact: _at(30, 14, 5), pointerId: 3, timestampMillis: 40);

      final CompositeContact? composite = coalescer.flush();

      expect(composite!.contactCount, 3);
      expect(composite.spanMillis, 40);
    });

    test('a contact past the window closes the previous composite', () {
      final ContactCoalescer coalescer = ContactCoalescer(windowMillis: 50);

      coalescer.add(contact: _at(10, 10, 5), pointerId: 1, timestampMillis: 0);
      coalescer.add(contact: _at(20, 12, 5), pointerId: 2, timestampMillis: 10);

      final CompositeContact? closed = coalescer.add(
        contact: _at(90, 90, 5),
        pointerId: 3,
        timestampMillis: 400,
      );

      expect(closed, isNotNull);
      expect(closed!.contactCount, 2);

      // The contact that closed the previous cluster is not dropped.
      expect(coalescer.pendingCount, 1);
    });

    test('flushIfReady respects the window', () {
      final ContactCoalescer coalescer = ContactCoalescer(windowMillis: 50);

      coalescer.add(
        contact: _at(10, 10, 5),
        pointerId: 1,
        timestampMillis: 100,
      );

      expect(coalescer.flushIfReady(120), isNull);
      expect(coalescer.flushIfReady(150), isNotNull);
    });

    test('null contacts are ignored rather than throwing', () {
      final ContactCoalescer coalescer = ContactCoalescer();

      expect(
        coalescer.add(contact: null, pointerId: 1, timestampMillis: 0),
        isNull,
      );
      expect(coalescer.hasPending, isFalse);
    });

    test('flush on an empty coalescer returns null', () {
      expect(ContactCoalescer().flush(), isNull);
    });

    test('reset discards without emitting', () {
      final ContactCoalescer coalescer = ContactCoalescer();

      coalescer.add(contact: _at(1, 1, 5), pointerId: 1, timestampMillis: 0);
      coalescer.reset();

      expect(coalescer.hasPending, isFalse);
      expect(coalescer.flush(), isNull);
    });
  });

  group('CompositeContact', () {
    test('the area-weighted centroid is pulled toward the largest contact', () {
      final CompositeContact composite = CompositeContact(
        contacts: <ClusteredContact>[
          ClusteredContact(
            ellipse: _at(0, 0, 30),
            pointerId: 1,
            timestampMillis: 0,
          ),
          ClusteredContact(
            ellipse: _at(100, 0, 3),
            pointerId: 2,
            timestampMillis: 2,
          ),
        ],
      );

      // The heel of the hand should dominate a grazing fingertip.
      expect(composite.areaWeightedCentroid.x, lessThan(5));
      expect(composite.largest!.pointerId, 1);
    });

    test('the footprint encloses every contact', () {
      final CompositeContact composite = CompositeContact(
        contacts: <ClusteredContact>[
          ClusteredContact(
            ellipse: _at(10, 20, 5),
            pointerId: 1,
            timestampMillis: 0,
          ),
          ClusteredContact(
            ellipse: _at(60, 80, 5),
            pointerId: 2,
            timestampMillis: 2,
          ),
        ],
      );

      expect(composite.footprint.width, 50);
      expect(composite.footprint.height, 60);
    });

    test('an empty composite reports safe values rather than throwing', () {
      expect(CompositeContact.empty.contactCount, 0);
      expect(CompositeContact.empty.largest, isNull);
      expect(CompositeContact.empty.areaWeightedCentroid, Point2.zero);
      expect(CompositeContact.empty.spanMillis, 0);
    });

    test('zero-area contacts fall back to an unweighted centroid', () {
      final CompositeContact composite = CompositeContact(
        contacts: <ClusteredContact>[
          ClusteredContact(
            ellipse: const ContactEllipse(
              centre: Point2(0, 0),
              radiusMajor: 0,
              radiusMinor: 0,
              orientation: 0,
              isMeasured: true,
            ),
            pointerId: 1,
            timestampMillis: 0,
          ),
          ClusteredContact(
            ellipse: const ContactEllipse(
              centre: Point2(100, 50),
              radiusMajor: 0,
              radiusMinor: 0,
              orientation: 0,
              isMeasured: true,
            ),
            pointerId: 2,
            timestampMillis: 0,
          ),
        ],
      );

      expect(composite.areaWeightedCentroid.x, 50);
      expect(composite.areaWeightedCentroid.y, 25);
    });
  });

  group('TouchResolver.resolveComposite', () {
    test('a hand mostly over one cell activates that cell', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      // Four contacts in column 0, one straggler in column 1.
      final CompositeContact composite = CompositeContact(
        contacts: <ClusteredContact>[
          ClusteredContact(
            ellipse: _at(60, 80, 12),
            pointerId: 1,
            timestampMillis: 0,
          ),
          ClusteredContact(
            ellipse: _at(120, 110, 14),
            pointerId: 2,
            timestampMillis: 4,
          ),
          ClusteredContact(
            ellipse: _at(180, 90, 10),
            pointerId: 3,
            timestampMillis: 6,
          ),
          ClusteredContact(
            ellipse: _at(100, 150, 20),
            pointerId: 4,
            timestampMillis: 8,
          ),
          ClusteredContact(
            ellipse: _at(300, 100, 6),
            pointerId: 5,
            timestampMillis: 9,
          ),
        ],
      );

      final TouchResolution result = resolver.resolveComposite(
        composite: composite,
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.activated, isTrue);
      expect(result.cell, const CellAddress(row: 0, col: 0));
      expect(result.method, ResolutionMethod.compositeOverlap);
    });

    test('the largest contact outweighs several small ones', () {
      // Exactly the case first-pointer-wins got wrong: the heel lands late and
      // in a different cell from the fingertips that registered first.
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      final CompositeContact composite = CompositeContact(
        contacts: <ClusteredContact>[
          ClusteredContact(
            ellipse: _at(300, 100, 4),
            pointerId: 1,
            timestampMillis: 0,
          ),
          ClusteredContact(
            ellipse: _at(320, 120, 4),
            pointerId: 2,
            timestampMillis: 2,
          ),
          ClusteredContact(
            ellipse: _at(340, 90, 4),
            pointerId: 3,
            timestampMillis: 3,
          ),
          ClusteredContact(
            ellipse: _at(120, 180, 45),
            pointerId: 4,
            timestampMillis: 9,
          ),
        ],
      );

      final TouchResolution result = resolver.resolveComposite(
        composite: composite,
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.cell, const CellAddress(row: 0, col: 0));
    });

    test('one composite produces one activation, not one per contact', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);
      final GridGeometry grid = _grid();

      final CompositeContact composite = CompositeContact(
        contacts: List<ClusteredContact>.generate(
          6,
          (int i) => ClusteredContact(
            ellipse: _at(60.0 + i * 8, 80.0 + i * 5, 10),
            pointerId: i,
            timestampMillis: i * 3,
          ),
        ),
      );

      expect(
        resolver
            .resolveComposite(
              composite: composite,
              grid: grid,
              timestampMillis: 0,
            )
            .activated,
        isTrue,
      );

      // A second slap arriving inside the lockout is suppressed.
      expect(
        resolver
            .resolveComposite(
              composite: composite,
              grid: grid,
              timestampMillis: 200,
            )
            .rejection,
        RejectionReason.lockout,
      );
    });

    test('a single-contact composite still honours point mode', () {
      final TouchResolver resolver = TouchResolver(
        config: const ResolverConfig(mode: TouchMode.point),
      );

      final TouchResolution result = resolver.resolveComposite(
        composite: CompositeContact.single(
          ellipse: _at(300, 100, 8),
          pointerId: 1,
          timestampMillis: 0,
        ),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.method, ResolutionMethod.point);
      expect(result.cell, const CellAddress(row: 0, col: 1));
    });

    test('null and empty composites resolve to nothing', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      expect(
        resolver
            .resolveComposite(
              composite: null,
              grid: _grid(),
              timestampMillis: 0,
            )
            .activated,
        isFalse,
      );
      expect(
        resolver
            .resolveComposite(
              composite: CompositeContact.empty,
              grid: _grid(),
              timestampMillis: 0,
            )
            .activated,
        isFalse,
      );
    });
  });

  group('Replay of real capture data', () {
    test(
      'the slap capture coalesces into three hand-landings of six contacts',
      () {
        final List<_Down> downs = _readDowns(_slapCapture);
        expect(downs.length, 18);

        final List<CompositeContact> composites = _coalesce(downs);

        expect(
          composites.length,
          3,
          reason: 'three deliberate slaps were performed',
        );

        for (final CompositeContact composite in composites) {
          expect(composite.contactCount, 6);
        }
      },
    );

    test('each real slap footprint measures around 40 to 50 mm across', () {
      final List<CompositeContact> composites = _coalesce(
        _readDowns(_slapCapture),
      );

      for (final CompositeContact composite in composites) {
        final double widthMm = composite.footprintWidthMillimetres(
          xdpi: _xdpi,
          devicePixelRatio: _devicePixelRatio,
        );

        expect(widthMm, greaterThan(35), reason: 'an adult hand is not narrow');
        expect(widthMm, lessThan(60), reason: 'nor is it wider than the panel');
      }
    });

    test('every real slap is classified as a palm', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      for (final CompositeContact composite in _coalesce(
        _readDowns(_slapCapture),
      )) {
        expect(resolver.isPalm(composite), isTrue);
      }
    });

    test('real deliberate taps are not classified as palms', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);
      final List<CompositeContact> composites = _coalesce(
        _readDowns(_pointCapture),
      );

      final int misclassified = composites
          .where((CompositeContact c) => resolver.isPalm(c))
          .length;

      expect(
        misclassified,
        0,
        reason: '58 deliberate taps must not read as palms',
      );
      expect(composites.length, 58);
    });

    test('replaying the slaps yields one activation per slap', () {
      // Lockout disabled here so the test measures coalescing rather than
      // suppression; the interaction between the two is covered below.
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(lockoutMillis: 0),
      );
      final GridGeometry grid = _grid();

      int activations = 0;

      for (final CompositeContact composite in _coalesce(
        _readDowns(_slapCapture),
      )) {
        final TouchResolution result = resolver.resolveComposite(
          composite: composite,
          grid: grid,
          timestampMillis: composite.firstTimestampMillis,
        );

        if (result.activated) {
          activations = activations + 1;
        }
      }

      expect(activations, 3);
    });

    test('an 800 ms lockout merges rapid repeated slaps into one activation', () {
      // Worth pinning down, because it is a genuine trade-off rather than a bug.
      // The three captured slaps fell within 494 ms of each other, so the
      // default lockout treats the second and third as bounce. That is correct
      // for a child whose hand rebounds, and wrong for one deliberately
      // repeating a word. The right value can only be set from Kyle's own data.
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);
      final GridGeometry grid = _grid();

      int activations = 0;

      for (final CompositeContact composite in _coalesce(
        _readDowns(_slapCapture),
      )) {
        final TouchResolution result = resolver.resolveComposite(
          composite: composite,
          grid: grid,
          timestampMillis: composite.firstTimestampMillis,
        );

        if (result.activated) {
          activations = activations + 1;
        }
      }

      expect(activations, 1);
    });
  });
}
