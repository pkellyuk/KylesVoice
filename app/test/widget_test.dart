import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import 'package:kylesvoice/board/board_surface.dart';

/// Counter giving each pumped board a distinct key.
///
/// Without it Flutter reuses the existing State across pumpWidget calls, so the
/// resolver's post-activation lockout would carry over between cases and
/// silently suppress later taps.
int _boardInstance = 0;

/// Pumps the board at a fixed size so cell rectangles are predictable.
Future<List<BoardCard>> _pumpAndTap(
  WidgetTester tester, {
  required List<Offset> contacts,
  ResolverConfig? config,
  Duration betweenContacts = const Duration(milliseconds: 4),
}) async {
  final List<BoardCard> activated = <BoardCard>[];
  _boardInstance = _boardInstance + 1;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BoardSurface(
            key: ValueKey<int>(_boardInstance),
            board: Board.kyleStarter,
            config: config ?? ResolverConfig.kyle,
            onActivated: activated.add,
          ),
        ),
      ),
    ),
  );

  int pointer = 1;

  for (final Offset contact in contacts) {
    final TestGesture gesture = await tester.startGesture(
      contact,
      pointer: pointer,
      kind: PointerDeviceKind.touch,
    );
    await gesture.up();
    pointer = pointer + 1;
    await tester.pump(betweenContacts);
  }

  // Let the coalescing window close and the flash timer run out.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));

  return activated;
}

void main() {
  testWidgets('a single tap on a card speaks that card', (
    WidgetTester tester,
  ) async {
    // Cell (0,0) occupies the top-left sixth of a 600x400 board.
    final List<BoardCard> activated = await _pumpAndTap(
      tester,
      contacts: <Offset>[const Offset(100, 100)],
    );

    expect(activated.length, 1);
    expect(activated.first.label, 'drink');
    expect(activated.first.speech, 'I want a drink');
  });

  testWidgets(
    'a tap on an empty cell speaks nothing and does not fire a neighbour',
    (WidgetTester tester) async {
      // Cell (1,1) is deliberately unoccupied in Kyle's starter board. Silence is
      // the correct outcome; firing an adjacent card would be far worse.
      final List<BoardCard> activated = await _pumpAndTap(
        tester,
        contacts: <Offset>[const Offset(300, 300)],
      );

      expect(activated, isEmpty);
    },
  );

  testWidgets('a many-fingered slap speaks once, not once per finger', (
    WidgetTester tester,
  ) async {
    // Six contacts inside the coalescing window, clustered over cell (0,0),
    // mirroring the shape of a real slap from docs/captures/.
    final List<BoardCard> activated = await _pumpAndTap(
      tester,
      contacts: <Offset>[
        const Offset(60, 60),
        const Offset(110, 80),
        const Offset(150, 70),
        const Offset(90, 130),
        const Offset(130, 140),
        const Offset(70, 100),
      ],
      betweenContacts: const Duration(milliseconds: 3),
    );

    expect(activated.length, 1, reason: 'one hand landing is one word');
    expect(activated.first.label, 'drink');
  });

  testWidgets('every cell keeps its position when cards are absent', (
    WidgetTester tester,
  ) async {
    // The board has six cells and four cards. Tapping each populated cell must
    // return that cell's own card, proving empty cells hold their place rather
    // than the grid collapsing around them.
    for (final (Offset where, String expected) in <(Offset, String)>[
      (const Offset(100, 100), 'drink'),
      (const Offset(300, 100), 'eat'),
      (const Offset(100, 300), 'more'),
      (const Offset(500, 300), 'finished'),
    ]) {
      final List<BoardCard> activated = await _pumpAndTap(
        tester,
        contacts: <Offset>[where],
      );

      expect(activated.length, 1, reason: 'at $where');
      expect(activated.first.label, expected, reason: 'at $where');
    }
  });
}
