import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import 'package:kylesvoice/board/card_tile.dart';
import 'package:kylesvoice/screens/card_editor.dart';

/// A one-pixel PNG, so tests can exercise the real image path on disk.
final List<int> _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

BoardCard _card({
  required String photoFile,
  ImageMode mode = ImageMode.photo,
  double blend = 0,
}) {
  return BoardCard(
    address: const CellAddress(row: 0, col: 0),
    label: 'cup',
    speech: 'my cup',
    glyph: 'GLYPH',
    colourArgb: 0xFF112233,
    photoFile: photoFile,
    imageMode: mode,
    blend: blend,
  );
}

Future<void> _pumpTile(
  WidgetTester tester, {
  required BoardCard card,
  String? mediaDirectory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: CardTile(
            card: card,
            isFlashing: false,
            mediaDirectory: mediaDirectory,
          ),
        ),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kylesvoice_widget_media_');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('CardTile artwork', () {
    testWidgets('a card with no photograph shows its symbol', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, card: _card(photoFile: ''));

      expect(find.text('GLYPH'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a photograph is drawn when the file exists', (
      WidgetTester tester,
    ) async {
      final File file = File('${dir.path}${Platform.pathSeparator}cup.png');
      file.writeAsBytesSync(_tinyPng);

      await _pumpTile(
        tester,
        card: _card(photoFile: 'cup.png'),
        mediaDirectory: dir.path,
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a missing photograph falls back to the symbol', (
      WidgetTester tester,
    ) async {
      // A card that still says the right word is far better than one that looks
      // broken to a child who cannot ask why.
      await _pumpTile(
        tester,
        card: _card(photoFile: 'not_there.png'),
        mediaDirectory: dir.path,
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('GLYPH'), findsOneWidget);
    });

    testWidgets('with no media directory the card falls back to the symbol', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, card: _card(photoFile: 'cup.png'));

      expect(find.byType(Image), findsNothing);
      expect(find.text('GLYPH'), findsOneWidget);
    });

    testWidgets('both mode draws the photograph and the symbol together', (
      WidgetTester tester,
    ) async {
      final File file = File('${dir.path}${Platform.pathSeparator}cup.png');
      file.writeAsBytesSync(_tinyPng);

      await _pumpTile(
        tester,
        card: _card(photoFile: 'cup.png', mode: ImageMode.both),
        mediaDirectory: dir.path,
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('GLYPH'), findsOneWidget);
    });
  });

  group('CardEditor photo controls', () {
    testWidgets('offers to take or choose a photograph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CardEditor(
            address: const CellAddress(row: 0, col: 0),
            media: MediaStore(directory: dir),
            mediaDirectory: dir.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose a photo'), findsOneWidget);

      // The blend controls only appear once there is a photograph to blend.
      expect(find.text('Fade'), findsNothing);
    });

    testWidgets('explains itself when storage is unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CardEditor(address: CellAddress(row: 0, col: 0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('storage could not be opened'),
        findsOneWidget,
      );
      expect(find.text('Take a photo'), findsNothing);
    });

    testWidgets('shows the photo and symbol controls for a card with a photo', (
      WidgetTester tester,
    ) async {
      final File file = File('${dir.path}${Platform.pathSeparator}cup.png');
      file.writeAsBytesSync(_tinyPng);

      await tester.pumpWidget(
        MaterialApp(
          home: CardEditor(
            address: const CellAddress(row: 0, col: 0),
            existing: _card(photoFile: 'cup.png', mode: ImageMode.blend),
            media: MediaStore(directory: dir),
            mediaDirectory: dir.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove photo'), findsOneWidget);

      // The mode controls sit further down the form, and a ListView does not
      // build what is off screen.
      await tester.dragUntilVisible(
        find.text('Fade'),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      // "Photo" and "Symbol" each appear several times over — as a mode button,
      // as an end label on the blend slider, and as the glyph field's label — so
      // the assertions here use the unambiguous parts.
      expect(find.byType(SegmentedButton<ImageMode>), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Fade'), findsOneWidget);

      final SegmentedButton<ImageMode> modes = tester
          .widget<SegmentedButton<ImageMode>>(
            find.byType(SegmentedButton<ImageMode>),
          );

      expect(modes.selected, <ImageMode>{ImageMode.blend});
      expect(
        modes.segments.map((ButtonSegment<ImageMode> s) => s.value).toSet(),
        ImageMode.values.toSet(),
      );

      // Fade is selected, so the slider and its guidance are present.
      expect(find.byType(Slider), findsOneWidget);
      expect(find.textContaining('a little at a time'), findsOneWidget);
    });
  });
}
