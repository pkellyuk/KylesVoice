import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import 'package:kylesvoice/board/board_surface.dart';
import 'package:kylesvoice/screens/editor_screen.dart';

int _instance = 0;

BoardCard _card(int row, int col, String label) {
  return BoardCard(
    address: CellAddress(row: row, col: col),
    label: label,
    speech: '',
    glyph: 'X',
    colourArgb: 0xFF112233,
  );
}

/// Kyle's board plus a second page holding one card.
Board _twoPageBoard() {
  return Board.kyleStarter.withPageAdded().withCard(
    page: 1,
    card: _card(0, 0, 'page two'),
  );
}

Future<List<BoardCard>> _pumpSurface(
  WidgetTester tester, {
  required Board board,
  required int pageIndex,
  bool enabled = true,
}) async {
  final List<BoardCard> activated = <BoardCard>[];
  _instance = _instance + 1;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BoardSurface(
            key: ValueKey<int>(_instance),
            board: board,
            pageIndex: pageIndex,
            enabled: enabled,
            config: ResolverConfig.kyle,
            onActivated: activated.add,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  return activated;
}

Future<void> _tap(WidgetTester tester, Offset where) async {
  final TestGesture gesture = await tester.startGesture(
    where,
    kind: PointerDeviceKind.touch,
  );
  await gesture.up();

  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));
}

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
  group('BoardSurface paging', () {
    testWidgets('shows the cards of the page it was given', (
      WidgetTester tester,
    ) async {
      await _pumpSurface(tester, board: _twoPageBoard(), pageIndex: 0);
      expect(find.text('drink'), findsOneWidget);
      expect(find.text('page two'), findsNothing);

      await _pumpSurface(tester, board: _twoPageBoard(), pageIndex: 1);
      expect(find.text('page two'), findsOneWidget);
      expect(find.text('drink'), findsNothing);
    });

    testWidgets('resolves touches against the page on screen', (
      WidgetTester tester,
    ) async {
      // The same cell on a different page is a different card, and must speak
      // the word that is actually showing.
      final List<BoardCard> activated = await _pumpSurface(
        tester,
        board: _twoPageBoard(),
        pageIndex: 1,
      );

      await _tap(tester, const Offset(100, 100));

      expect(activated.single.label, 'page two');
    });

    testWidgets('a disabled surface ignores touches entirely', (
      WidgetTester tester,
    ) async {
      // The board is deaf for a moment after a page turn, so a hand still
      // travelling cannot fire a word the user did not choose.
      final List<BoardCard> activated = await _pumpSurface(
        tester,
        board: Board.kyleStarter,
        pageIndex: 0,
        enabled: false,
      );

      await _tap(tester, const Offset(100, 100));

      expect(activated, isEmpty);
    });

    testWidgets('an out-of-range page shows nothing rather than throwing', (
      WidgetTester tester,
    ) async {
      await _pumpSurface(tester, board: Board.kyleStarter, pageIndex: 7);

      expect(find.text('drink'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Editor paging', () {
    testWidgets('a one-page board offers to add a page', (
      WidgetTester tester,
    ) async {
      final List<Board> saved = await _pumpEditor(tester);

      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a page'));
      await tester.pumpAndSettle();

      expect(saved.single.pageCount, 2);

      // Nothing already placed moved.
      for (final BoardCard original in Board.kyleStarter.pages.single.cards) {
        expect(
          saved.single.cardAt(page: 0, address: original.address),
          original,
        );
      }
    });

    testWidgets('the editor edits the page it is showing', (
      WidgetTester tester,
    ) async {
      final List<Board> saved = await _pumpEditor(
        tester,
        board: _twoPageBoard(),
      );

      expect(find.text('drink'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('page two'), findsOneWidget);
      expect(find.text('drink'), findsNothing);

      // Five empty cells on page two, each offering an add affordance.
      expect(find.byIcon(Icons.add), findsNWidgets(5));

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Word on the card'),
        'added here',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check).first);
      await tester.pumpAndSettle();

      // The new card landed on page two, and page one is untouched.
      expect(saved.last.pageAt(1)!.cardCount, 2);
      expect(saved.last.pageAt(0)!.cardCount, 4);
    });

    testWidgets('paging arrows stop at the ends', (WidgetTester tester) async {
      await _pumpEditor(tester, board: _twoPageBoard());

      final IconButton back = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(back.onPressed, isNull, reason: 'already on the first page');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      final IconButton forward = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(forward.onPressed, isNull, reason: 'already on the last page');
    });

    testWidgets('removing a page names the cards that go with it', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, board: _twoPageBoard());

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove page 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('page two'), findsWidgets);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('the last page cannot be removed', (WidgetTester tester) async {
      await _pumpEditor(tester);

      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();

      final PopupMenuItem<String> remove = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Remove page 1'),
      );

      expect(remove.enabled, isFalse);
    });
  });
}
