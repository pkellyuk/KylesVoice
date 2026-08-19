import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import 'package:kylesvoice/screens/editor_screen.dart';

/// Pumps the editor, capturing every board it tries to save.
Future<List<Board>> _pumpEditor(WidgetTester tester, {Board? board}) async {
  final List<Board> saved = <Board>[];

  await tester.pumpWidget(
    MaterialApp(
      home: EditorScreen(
        board: board ?? Board.kyleStarter,
        onSave: (Board b) async {
          saved.add(b);
          return '';
        },
      ),
    ),
  );

  await tester.pumpAndSettle();

  return saved;
}

void main() {
  testWidgets('the editor shows every cell, including the empty ones', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester);

    // Four cards plus two empty cells, each offering an add affordance.
    expect(find.text('drink'), findsOneWidget);
    expect(find.text('eat'), findsOneWidget);
    expect(find.text('more'), findsOneWidget);
    expect(find.text('finished'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(2));
  });

  testWidgets('adding a card to an empty cell saves immediately', (
    WidgetTester tester,
  ) async {
    final List<Board> saved = await _pumpEditor(tester);

    // Row 1, column 1 is the empty cell in the middle of the bottom row.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Word on the card'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Word on the card'),
      'help',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What it says out loud'),
      'I need help',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();

    // Saved as soon as the edit was made, not on leaving the editor: the device
    // gets thrown, so there is no safe moment to hold unsaved changes.
    expect(saved.length, 1);
    expect(saved.single.totalCards, 5);
    expect(
      saved.single.pages.single.cards.any((BoardCard c) => c.label == 'help'),
      isTrue,
    );
  });

  testWidgets('a card with no word and no phrase is refused', (
    WidgetTester tester,
  ) async {
    final List<Board> saved = await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check).first);
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.textContaining('before saving'), findsOneWidget);
  });

  testWidgets('removing a card leaves its cell empty and in place', (
    WidgetTester tester,
  ) async {
    final List<Board> saved = await _pumpEditor(tester);

    await tester.tap(find.text('drink'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(saved.length, 1);

    final Board result = saved.single;

    // The card is gone, but the grid has not shrunk and nothing has shuffled
    // into the gap. Every other card is exactly where it was.
    expect(
      result.cardAt(page: 0, address: const CellAddress(row: 0, col: 0)),
      isNull,
    );
    expect(result.rows, 2);
    expect(result.cols, 3);
    expect(
      result.cardAt(page: 0, address: const CellAddress(row: 0, col: 1))!.label,
      'eat',
    );
    expect(
      result.cardAt(page: 0, address: const CellAddress(row: 1, col: 0))!.label,
      'more',
    );
    expect(
      result.cardAt(page: 0, address: const CellAddress(row: 1, col: 2))!.label,
      'finished',
    );
  });

  testWidgets('undo restores the board after a deletion', (
    WidgetTester tester,
  ) async {
    final List<Board> saved = await _pumpEditor(tester);

    await tester.tap(find.text('drink'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(saved.length, 2);
    expect(
      saved.last
          .cardAt(page: 0, address: const CellAddress(row: 0, col: 0))!
          .label,
      'drink',
    );
  });

  testWidgets('shrinking the grid names the cards it would remove', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();

    // Drop from three columns to two, which orphans "finished" at column 2.
    await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The parent must be told exactly what a resize costs before it happens.
    expect(find.textContaining('learn again'), findsOneWidget);
    expect(find.text('finished'), findsWidgets);
  });

  testWidgets('declining a grid change leaves the board untouched', (
    WidgetTester tester,
  ) async {
    final List<Board> saved = await _pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave it alone'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
  });
}
