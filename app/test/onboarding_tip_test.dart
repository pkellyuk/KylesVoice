import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kylesvoice/screens/board_screen.dart';
import 'package:kylesvoice/services/board_storage.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

class _TipStorage extends BoardStorage {
  @override
  Future<String> initialise() async => '';

  @override
  Future<BoardLoadResult> load() async => const BoardLoadResult(
    board: Board.kyleStarter,
    wasRestored: false,
    usedBackup: false,
    problems: <String>[],
  );
}

void main() {
  testWidgets('tip highlights the live long-press target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(storage: _TipStorage())),
    );
    await tester.pump();

    expect(find.text('Press and hold for grown-up options'), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);

    // The visual cue ignores input, so the real target directly beneath it
    // still receives the gesture and opens the existing parent gate.
    await tester.longPressAt(const Offset(32, 32));
    await tester.pumpAndSettle();

    expect(find.text('For a grown-up'), findsOneWidget);
    expect(find.text('Press and hold for grown-up options'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('tip disappears after seven seconds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(storage: _TipStorage())),
    );
    await tester.pump();
    expect(find.text('Press and hold for grown-up options'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Press and hold for grown-up options'), findsNothing);
  });
}
