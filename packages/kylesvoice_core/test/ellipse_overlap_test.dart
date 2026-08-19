import 'dart:math' as math;

import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

/// A rectangle large enough to contain any contact used in these tests.
const Rect2 _big = Rect2(left: 0, top: 0, width: 400, height: 400);

ContactEllipse _circleAt(double x, double y, double r) {
  return ContactEllipse.circular(centre: Point2(x, y), radius: r);
}

void main() {
  group('EllipseOverlap — analytic checks', () {
    // These cases have closed-form answers, so they test the implementation
    // against mathematics rather than against itself.

    test('a circle wholly inside a rectangle contributes its full area', () {
      final ContactEllipse contact = _circleAt(200, 200, 10);

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(math.pi * 100, 0.01),
      );
    });

    test('a circle wholly outside contributes nothing', () {
      final ContactEllipse contact = _circleAt(1000, 1000, 10);

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(0, 0.0001),
      );
    });

    test('a circle centred on an edge contributes exactly half', () {
      final ContactEllipse contact = _circleAt(200, 0, 10);

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(math.pi * 100 / 2, 0.01),
      );
    });

    test('a circle centred on a corner contributes exactly a quarter', () {
      final ContactEllipse contact = _circleAt(0, 0, 10);

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(math.pi * 100 / 4, 0.01),
      );
    });

    test('a circle exactly tangent to an edge contributes nothing', () {
      final ContactEllipse contact = _circleAt(-10, 200, 10);

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(0, 0.01),
      );
    });

    test('an ellipse wholly inside contributes pi * a * b', () {
      const ContactEllipse contact = ContactEllipse(
        centre: Point2(200, 200),
        radiusMajor: 20,
        radiusMinor: 10,
        orientation: 0,
        isMeasured: true,
      );

      expect(
        EllipseOverlap.area(ellipse: contact, rect: _big),
        closeTo(math.pi * 20 * 10, 0.01),
      );
    });

    test('rotating an interior ellipse does not change its area', () {
      double areaAt(double orientation) {
        return EllipseOverlap.area(
          ellipse: ContactEllipse(
            centre: const Point2(200, 200),
            radiusMajor: 30,
            radiusMinor: 12,
            orientation: orientation,
            isMeasured: true,
          ),
          rect: _big,
        );
      }

      final double expected = math.pi * 30 * 12;

      expect(areaAt(0), closeTo(expected, 0.01));
      expect(areaAt(math.pi / 6), closeTo(expected, 0.01));
      expect(areaAt(math.pi / 4), closeTo(expected, 0.01));
      expect(areaAt(math.pi / 2), closeTo(expected, 0.01));
      expect(areaAt(-1.1), closeTo(expected, 0.01));
    });

    test(
      'an ellipse centred on an edge contributes half, whatever its rotation',
      () {
        double areaAt(double orientation) {
          return EllipseOverlap.area(
            ellipse: ContactEllipse(
              centre: const Point2(200, 0),
              radiusMajor: 25,
              radiusMinor: 10,
              orientation: orientation,
              isMeasured: true,
            ),
            rect: _big,
          );
        }

        final double half = math.pi * 25 * 10 / 2;

        expect(areaAt(0), closeTo(half, 0.01));
        expect(areaAt(math.pi / 3), closeTo(half, 0.01));
        expect(areaAt(math.pi / 2), closeTo(half, 0.01));
      },
    );

    test('splitting a rectangle in two splits the contact area in two', () {
      // A contact straddling the seam between two adjoining cells must have its
      // area fully accounted for, with nothing lost or double counted.
      final ContactEllipse contact = _circleAt(200, 200, 40);

      const Rect2 leftHalf = Rect2(left: 0, top: 0, width: 200, height: 400);
      const Rect2 rightHalf = Rect2(left: 200, top: 0, width: 200, height: 400);

      final double a = EllipseOverlap.area(ellipse: contact, rect: leftHalf);
      final double b = EllipseOverlap.area(ellipse: contact, rect: rightHalf);

      expect(a, closeTo(math.pi * 1600 / 2, 0.01));
      expect(b, closeTo(math.pi * 1600 / 2, 0.01));
      expect(a + b, closeTo(math.pi * 1600, 0.01));
    });

    test(
      'an off-centre contact gives the larger share to the cell it favours',
      () {
        final ContactEllipse contact = _circleAt(180, 200, 40);

        const Rect2 leftHalf = Rect2(left: 0, top: 0, width: 200, height: 400);
        const Rect2 rightHalf = Rect2(
          left: 200,
          top: 0,
          width: 200,
          height: 400,
        );

        final double a = EllipseOverlap.area(ellipse: contact, rect: leftHalf);
        final double b = EllipseOverlap.area(ellipse: contact, rect: rightHalf);

        expect(a, greaterThan(b));
        expect(a + b, closeTo(math.pi * 1600, 0.01));
      },
    );

    test('overlaps across a gutterless grid sum to the whole contact', () {
      // The strongest invariant available: partition the plane and confirm the
      // arithmetic conserves area.
      final GridGeometry grid = GridGeometry(
        rows: 3,
        cols: 4,
        bounds: _big,
        gutter: 0,
      );

      final ContactEllipse contact = ContactEllipse(
        centre: const Point2(197, 141),
        radiusMajor: 46,
        radiusMinor: 29,
        orientation: 0.7,
        isMeasured: true,
      );

      double total = 0;

      for (final PositionedCell cell in grid.allCells()) {
        total = total + EllipseOverlap.area(ellipse: contact, rect: cell.rect);
      }

      expect(total, closeTo(contact.area, 0.01));
    });
  });

  group('EllipseOverlap — degenerate input', () {
    test('returns zero rather than throwing for null input', () {
      expect(EllipseOverlap.area(ellipse: null, rect: _big), 0);
      expect(EllipseOverlap.area(ellipse: _circleAt(0, 0, 5), rect: null), 0);
    });

    test('returns zero for a zero-area rectangle', () {
      const Rect2 empty = Rect2(left: 10, top: 10, width: 0, height: 50);

      expect(
        EllipseOverlap.area(ellipse: _circleAt(10, 10, 5), rect: empty),
        0,
      );
    });

    test('fractionOfContact is bounded to 0..1', () {
      final ContactEllipse contact = _circleAt(200, 200, 10);

      expect(
        EllipseOverlap.fractionOfContact(ellipse: contact, rect: _big),
        closeTo(1.0, 0.0001),
      );
      expect(
        EllipseOverlap.fractionOfContact(
          ellipse: _circleAt(0, 0, 10),
          rect: _big,
        ),
        closeTo(0.25, 0.001),
      );
      expect(EllipseOverlap.fractionOfContact(ellipse: null, rect: _big), 0);
    });
  });

  group('ContactEllipse.fromPlatform', () {
    test('substitutes the fallback radius when nothing usable is reported', () {
      final ContactEllipse contact = ContactEllipse.fromPlatform(
        centre: const Point2(10, 10),
        reportedMajor: 0,
        reportedMinor: 0,
        fallbackRadius: 48,
      );

      expect(contact.isMeasured, isFalse);
      expect(contact.radiusMajor, 48);
      expect(contact.radiusMinor, 48);
    });

    test('substitutes the fallback for NaN, infinity and negatives', () {
      for (final double bad in <double>[double.nan, double.infinity, -5]) {
        final ContactEllipse contact = ContactEllipse.fromPlatform(
          centre: const Point2(10, 10),
          reportedMajor: bad,
          reportedMinor: bad,
          fallbackRadius: 30,
        );

        expect(contact.isMeasured, isFalse, reason: 'for input $bad');
        expect(contact.radiusMajor, 30, reason: 'for input $bad');
      }
    });

    test('applies the device calibration scale', () {
      final ContactEllipse contact = ContactEllipse.fromPlatform(
        centre: const Point2(0, 0),
        reportedMajor: 10,
        reportedMinor: 6,
        calibrationScale: 2.5,
        fallbackRadius: 48,
      );

      expect(contact.isMeasured, isTrue);
      expect(contact.radiusMajor, closeTo(25, 0.0001));
      expect(contact.radiusMinor, closeTo(15, 0.0001));
    });

    test('assumes a circular contact when only a major axis is reported', () {
      final ContactEllipse contact = ContactEllipse.fromPlatform(
        centre: const Point2(0, 0),
        reportedMajor: 12,
        reportedMinor: 0,
        fallbackRadius: 48,
      );

      expect(contact.isMeasured, isTrue);
      expect(contact.radiusMajor, 12);
      expect(contact.radiusMinor, 12);
    });

    test('orders the axes so major is never smaller than minor', () {
      final ContactEllipse contact = ContactEllipse.fromPlatform(
        centre: const Point2(0, 0),
        reportedMajor: 5,
        reportedMinor: 20,
        fallbackRadius: 48,
      );

      expect(contact.radiusMajor, 20);
      expect(contact.radiusMinor, 5);
    });

    test('tolerates a null centre', () {
      final ContactEllipse contact = ContactEllipse.fromPlatform(
        centre: null,
        reportedMajor: 10,
        reportedMinor: 10,
        fallbackRadius: 48,
      );

      expect(contact.centre, Point2.zero);
    });

    test('converts the major diameter to millimetres', () {
      // 254 dpi is exactly 10 pixels per millimetre, so the expected value is
      // obvious by inspection rather than a restatement of the formula.
      final ContactEllipse contact = _circleAt(0, 0, 50);

      expect(
        contact.majorDiameterMillimetres(dpi: 254, devicePixelRatio: 1.0),
        closeTo(10, 0.0001),
      );
      expect(
        contact.majorDiameterMillimetres(dpi: 0, devicePixelRatio: 1.0),
        0,
      );
    });
  });
}
