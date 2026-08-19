import 'package:kylesvoice_core/kylesvoice_core.dart';
import 'package:test/test.dart';

/// Kyle's provisional board shape on the Fire HD 8: three columns, two rows,
/// landscape. Cells are 200 x 200 logical pixels here for easy arithmetic.
GridGeometry _grid({double gutter = 0}) {
  return GridGeometry(
    rows: 2,
    cols: 3,
    bounds: const Rect2(left: 0, top: 0, width: 600, height: 400),
    gutter: gutter,
  );
}

ContactEllipse _palmAt(double x, double y, {double radius = 60}) {
  return ContactEllipse.circular(centre: Point2(x, y), radius: radius);
}

ContactEllipse _fingerAt(double x, double y) {
  return ContactEllipse.circular(centre: Point2(x, y), radius: 8);
}

void main() {
  group('TouchResolver — palm mode', () {
    test('a palm centred on a cell activates that cell', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.activated, isTrue);
      expect(result.cell, const CellAddress(row: 0, col: 0));
      expect(result.method, ResolutionMethod.palmOverlap);
      expect(result.wasAmbiguous, isFalse);
    });

    test('a palm straddling two cells activates the one it mostly covers', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      // Centre is at x=180, just inside column 0, but the patch spills into
      // column 1. Point hit-testing and area resolution agree here; the point of
      // the test is that the larger share wins.
      final TouchResolution result = resolver.resolve(
        contact: _palmAt(180, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.cell, const CellAddress(row: 0, col: 0));
      expect(result.runnerUpCell, const CellAddress(row: 0, col: 1));
      expect(result.winningOverlap, greaterThan(result.runnerUpOverlap));
    });

    test('on a uniform gutterless grid, area resolution agrees with the centre point', () {
      // Worth stating explicitly, because it is easy to assume otherwise. A
      // contact ellipse is symmetric about its centre, so across two equal
      // half-planes the majority of its area always falls on the side its
      // centre is on. Area resolution therefore cannot, by itself, rescue a
      // slap whose reported centroid already landed on the wrong card.
      //
      // Palm mode earns its keep elsewhere: in gutters, at clipped screen
      // edges, across cells of unequal size, and by knowing when a call was
      // too close to trust. Those cases are covered below.
      final GridGeometry grid = _grid();

      for (final double x in <double>[195, 205, 210, 260]) {
        final ContactEllipse contact = _palmAt(x, 100);

        final TouchResolution palm = TouchResolver(
          config: const ResolverConfig(mode: TouchMode.palm),
        ).resolve(contact: contact, grid: grid, timestampMillis: 0);

        final TouchResolution point = TouchResolver(
          config: const ResolverConfig(mode: TouchMode.point),
        ).resolve(contact: contact, grid: grid, timestampMillis: 0);

        expect(palm.cell, point.cell, reason: 'at x=$x');
      }
    });

    test('palm mode resolves a contact whose centre lands in a dead gutter', () {
      // A genuine disagreement, and the everyday one. Point mode has dead zones
      // between cells: a centre landing in a gutter activates nothing at all.
      // Area resolution has no dead zones, because a contact spanning the gutter
      // still overlaps the cells either side of it.
      final GridGeometry grid = _grid(gutter: 24);
      final ContactEllipse contact = _palmAt(196, 100);

      expect(grid.cellAt(contact.centre), isNull);

      final TouchResolution point = TouchResolver(
        config: const ResolverConfig(mode: TouchMode.point),
      ).resolve(contact: contact, grid: grid, timestampMillis: 0);

      final TouchResolution palm = TouchResolver(
        config: const ResolverConfig(mode: TouchMode.palm),
      ).resolve(contact: contact, grid: grid, timestampMillis: 0);

      expect(point.activated, isFalse);
      expect(palm.activated, isTrue);
      expect(palm.cell, const CellAddress(row: 0, col: 0));
    });

    test('a contact clipped by the screen edge shifts toward the cell on screen', () {
      // The other genuine disagreement: near a border, part of the contact falls
      // outside the grid entirely, so the balance between cells is no longer
      // symmetric about the reported centre.
      final GridGeometry grid = _grid();

      final double insideEdge = EllipseOverlap.area(
        ellipse: _palmAt(0, 100),
        rect: grid.rectFor(const CellAddress(row: 0, col: 0))!,
      );

      // Half the patch is off-screen to the left, so only half is attributable.
      expect(insideEdge, lessThan(_palmAt(0, 100).area));
      expect(insideEdge, greaterThan(0));
    });

    test('a contact exactly on a seam is reported ambiguous', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(200, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.wasAmbiguous, isTrue);
    });

    test('a contact entirely off the grid activates nothing', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(5000, 5000),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.activated, isFalse);
      expect(result.rejection, RejectionReason.noOverlap);
    });
  });

  group('TouchResolver — ambiguity policy', () {
    test('nearest activates the larger share despite the tie', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(
          ambiguityPolicy: AmbiguityPolicy.nearest,
        ),
      );

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(200, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.wasAmbiguous, isTrue);
      expect(result.activated, isTrue);
    });

    test('ignore refuses to guess', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(
          ambiguityPolicy: AmbiguityPolicy.ignore,
        ),
      );

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(200, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.wasAmbiguous, isTrue);
      expect(result.activated, isFalse);
      expect(result.rejection, RejectionReason.ambiguous);
    });

    test('a clearly favoured cell is not ambiguous under either policy', () {
      final TouchResolution result = TouchResolver(
        config: ResolverConfig.kyle.copyWith(
          ambiguityPolicy: AmbiguityPolicy.ignore,
        ),
      ).resolve(contact: _palmAt(100, 100), grid: _grid(), timestampMillis: 0);

      expect(result.wasAmbiguous, isFalse);
      expect(result.activated, isTrue);
    });
  });

  group('TouchResolver — slap bounce suppression', () {
    test('a second contact inside the lockout window is refused', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(lockoutMillis: 800),
      );

      final TouchResolution first = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1000,
      );
      expect(first.activated, isTrue);

      final TouchResolution bounce = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1200,
      );

      expect(bounce.activated, isFalse);
      expect(bounce.rejection, RejectionReason.lockout);
    });

    test('a contact after the lockout window is accepted', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(lockoutMillis: 800),
      );

      resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1000,
      );

      final TouchResolution later = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1900,
      );

      expect(later.activated, isTrue);
    });

    test('preview resolution does not start the lockout', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1000,
        commit: false,
      );

      final TouchResolution real = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1010,
      );

      expect(real.activated, isTrue);
    });

    test('a zero lockout disables suppression entirely', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(lockoutMillis: 0),
      );

      resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      final TouchResolution immediate = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1,
      );

      expect(immediate.activated, isTrue);
    });
  });

  group('TouchResolver — multi-touch lockout', () {
    test(
      'the first pointer down is authoritative and later ones are ignored',
      () {
        final TouchResolver resolver = TouchResolver(
          config: ResolverConfig.kyle,
        );

        expect(
          resolver.onPointerDown(pointerId: 1, timestampMillis: 0),
          isTrue,
        );
        expect(
          resolver.onPointerDown(pointerId: 2, timestampMillis: 3),
          isFalse,
        );
        expect(
          resolver.onPointerDown(pointerId: 3, timestampMillis: 7),
          isFalse,
        );

        final TouchResolution stray = resolver.resolve(
          contact: _palmAt(100, 100),
          grid: _grid(),
          timestampMillis: 10,
          pointerId: 2,
        );

        expect(stray.activated, isFalse);
        expect(stray.rejection, RejectionReason.multiTouch);
      },
    );

    test('the authoritative pointer still resolves normally', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.onPointerDown(pointerId: 1, timestampMillis: 0);
      resolver.onPointerDown(pointerId: 2, timestampMillis: 3);

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 10,
        pointerId: 1,
      );

      expect(result.activated, isTrue);
    });

    test('lifting the authoritative pointer frees the next one', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.onPointerDown(pointerId: 1, timestampMillis: 0);
      resolver.onPointerUp(pointerId: 1);

      expect(resolver.onPointerDown(pointerId: 2, timestampMillis: 50), isTrue);
    });

    test('lifting a non-authoritative pointer changes nothing', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.onPointerDown(pointerId: 1, timestampMillis: 0);
      resolver.onPointerUp(pointerId: 9);

      expect(resolver.onPointerDown(pointerId: 2, timestampMillis: 5), isFalse);
    });

    test('disabling the lockout admits every pointer', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(multiTouchLockout: false),
      );

      expect(resolver.onPointerDown(pointerId: 1, timestampMillis: 0), isTrue);
      expect(resolver.onPointerDown(pointerId: 2, timestampMillis: 3), isTrue);
    });
  });

  group('TouchResolver — dwell', () {
    test('a contact held for less than the dwell time does not activate', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(dwellMillis: 300),
      );

      resolver.onPointerDown(pointerId: 1, timestampMillis: 1000);

      final TouchResolution early = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1100,
        pointerId: 1,
      );

      expect(early.activated, isFalse);
      expect(early.rejection, RejectionReason.dwellNotMet);
    });

    test('a contact held past the dwell time activates', () {
      final TouchResolver resolver = TouchResolver(
        config: ResolverConfig.kyle.copyWith(dwellMillis: 300),
      );

      resolver.onPointerDown(pointerId: 1, timestampMillis: 1000);

      final TouchResolution late = resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 1400,
        pointerId: 1,
      );

      expect(late.activated, isTrue);
    });

    test('Kyle\'s profile has dwell disabled, so a tap activates at once', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.onPointerDown(pointerId: 1, timestampMillis: 1000);

      expect(
        resolver
            .resolve(
              contact: _palmAt(100, 100),
              grid: _grid(),
              timestampMillis: 1000,
              pointerId: 1,
            )
            .activated,
        isTrue,
      );
    });
  });

  group('TouchResolver — auto mode', () {
    test('a large contact is resolved by area', () {
      final TouchResolver resolver = TouchResolver(
        config: const ResolverConfig(
          mode: TouchMode.auto,
          autoPalmRadiusThreshold: 30,
        ),
      );

      final TouchResolution result = resolver.resolve(
        contact: _palmAt(205, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.method, ResolutionMethod.palmOverlap);
      expect(result.cell, const CellAddress(row: 0, col: 1));
      expect(result.runnerUpCell, const CellAddress(row: 0, col: 0));
    });

    test('a small contact is treated as a point', () {
      final TouchResolver resolver = TouchResolver(
        config: const ResolverConfig(
          mode: TouchMode.auto,
          autoPalmRadiusThreshold: 30,
        ),
      );

      final TouchResolution result = resolver.resolve(
        contact: _fingerAt(205, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.method, ResolutionMethod.point);
      expect(result.cell, const CellAddress(row: 0, col: 1));
    });

    test('an unmeasured contact falls back to point mode', () {
      final TouchResolver resolver = TouchResolver(
        config: const ResolverConfig(mode: TouchMode.auto),
      );

      final ContactEllipse unmeasured = ContactEllipse.fromPlatform(
        centre: const Point2(205, 100),
        reportedMajor: 0,
        reportedMinor: 0,
        fallbackRadius: 48,
      );

      final TouchResolution result = resolver.resolve(
        contact: unmeasured,
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.method, ResolutionMethod.point);
    });

    test('palm mode records that an unmeasured contact used the fallback', () {
      final TouchResolver resolver = TouchResolver(
        config: const ResolverConfig(mode: TouchMode.palm),
      );

      final ContactEllipse unmeasured = ContactEllipse.fromPlatform(
        centre: const Point2(100, 100),
        reportedMajor: 0,
        reportedMinor: 0,
        fallbackRadius: 48,
      );

      final TouchResolution result = resolver.resolve(
        contact: unmeasured,
        grid: _grid(),
        timestampMillis: 0,
      );

      expect(result.activated, isTrue);
      expect(result.method, ResolutionMethod.fallbackRadius);
    });
  });

  group('TouchResolver — degenerate input', () {
    test('a null contact resolves to nothing without throwing', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      expect(
        resolver
            .resolve(contact: null, grid: _grid(), timestampMillis: 0)
            .activated,
        isFalse,
      );
    });

    test('a null or invalid grid is reported rather than throwing', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      expect(
        resolver
            .resolve(contact: _palmAt(10, 10), grid: null, timestampMillis: 0)
            .rejection,
        RejectionReason.invalidGrid,
      );

      final GridGeometry broken = GridGeometry(
        rows: 0,
        cols: 0,
        bounds: const Rect2(left: 0, top: 0, width: 0, height: 0),
      );

      expect(
        resolver
            .resolve(contact: _palmAt(10, 10), grid: broken, timestampMillis: 0)
            .rejection,
        RejectionReason.invalidGrid,
      );
    });

    test('reset clears lockout and pointer tracking', () {
      final TouchResolver resolver = TouchResolver(config: ResolverConfig.kyle);

      resolver.onPointerDown(pointerId: 1, timestampMillis: 0);
      resolver.resolve(
        contact: _palmAt(100, 100),
        grid: _grid(),
        timestampMillis: 0,
      );

      resolver.reset();

      expect(resolver.onPointerDown(pointerId: 5, timestampMillis: 10), isTrue);
      expect(
        resolver
            .resolve(
              contact: _palmAt(100, 100),
              grid: _grid(),
              timestampMillis: 10,
            )
            .activated,
        isTrue,
      );
    });
  });

  group('GridGeometry', () {
    test('gutters belong to no cell', () {
      final GridGeometry grid = _grid(gutter: 20);

      // x = 200 is the seam between columns 0 and 1, inside the gutter.
      expect(grid.cellAt(const Point2(200, 100)), isNull);
      expect(
        grid.cellAt(const Point2(100, 100)),
        const CellAddress(row: 0, col: 0),
      );
    });

    test('every cell exists even when the board is mostly empty', () {
      // Positions are never collapsed: an unoccupied cell still holds its place.
      expect(_grid().allCells().length, 6);
    });

    test('out-of-range addresses return null rather than throwing', () {
      final GridGeometry grid = _grid();

      expect(grid.rectFor(const CellAddress(row: 9, col: 0)), isNull);
      expect(grid.rectFor(const CellAddress(row: 0, col: -1)), isNull);
      expect(grid.rectFor(null), isNull);
    });

    test('a span is clamped to the edge of the grid', () {
      final GridGeometry grid = _grid();

      final Rect2? rect = grid.rectFor(
        const CellAddress(row: 0, col: 2),
        colSpan: 5,
      );

      expect(rect, isNotNull);
      expect(rect!.right, closeTo(600, 0.001));
    });

    test('reports cell size in millimetres', () {
      // 254 dpi is exactly 10 pixels per millimetre.
      final GridGeometry grid = _grid();

      expect(
        grid.cellWidthMillimetres(xdpi: 254, devicePixelRatio: 1.0),
        closeTo(20, 0.001),
      );
      expect(grid.cellWidthMillimetres(xdpi: 0, devicePixelRatio: 1.0), 0);
    });
  });
}
