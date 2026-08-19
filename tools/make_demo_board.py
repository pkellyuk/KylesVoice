"""Builds the demo board used for the Play Store screenshots.

Run from the repository root:

    python3 tools/make_demo_board.py

Writes tools/demo_board.json, which can then be pushed onto a device running a
debug build:

    adb shell run-as io.github.pkellyuk.kylesvoice mkdir -p app_flutter
    adb push tools/demo_board.json /data/local/tmp/board.json
    adb shell run-as io.github.pkellyuk.kylesvoice \
        cp /data/local/tmp/board.json app_flutter/board.json

The board is a plausible first vocabulary rather than a showcase of every
feature. Store screenshots should look like the thing a parent would actually
end up with. Every symbol named here is checked against the bundled index, so a
renamed or removed symbol fails loudly rather than showing a blank card.
"""

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SYMBOL_INDEX = REPO_ROOT / "app" / "assets" / "symbols" / "index.json"
OUTPUT = REPO_ROOT / "tools" / "demo_board.json"

# The app's card palette, from lib/screens/card_editor.dart.
BLUE = 0xFF4FA3D1
RED = 0xFFD96C6C
GREEN = 0xFF6BA368
AMBER = 0xFFC08A3E
PURPLE = 0xFF9B7EC4
TEAL = 0xFF4FB3A8
PINK = 0xFFD98CB3

# row, column, label, spoken phrase, symbol file, colour
PAGE_ONE = [
    (0, 0, "drink", "I want a drink", "drink.svg", BLUE),
    (0, 1, "food", "I want something to eat", "food.svg", RED),
    (0, 2, "more", "more please", "more.svg", GREEN),
    (1, 0, "toilet", "I need the toilet", "toilet.svg", TEAL),
    (1, 1, "help", "help me", "help_,_to.svg", PURPLE),
    (1, 2, "finished", "all done", "finish.svg", AMBER),
    (2, 0, "music", "I want music", "music.svg", PINK),
    (2, 1, "outside", "I want to go outside", "outside.svg", BLUE),
]

PAGE_TWO = [
    (0, 0, "car", "let's go in the car", "car.svg", BLUE),
    (0, 1, "park", "I want to go to the park", "park_,_to.svg", GREEN),
    (0, 2, "ball", "I want the ball", "ball.svg", AMBER),
]


def load_known_symbols() -> set[str]:
    data = json.loads(SYMBOL_INDEX.read_text(encoding="utf-8"))
    return {entry["file"] for entry in data["symbols"]}


def build_page(rows, known: set[str]) -> dict:
    cards = []

    for row, column, label, speech, symbol, colour in rows:
        if symbol not in known:
            raise SystemExit(
                f'Symbol "{symbol}" is not in the bundled set. '
                "Re-run tools/import_symbols.dart or pick another."
            )

        cards.append(
            {
                "row": row,
                "col": column,
                "label": label,
                "speech": speech,
                "glyph": "",
                "symbolFile": symbol,
                "colourArgb": colour,
                "photoFile": "",
                "imageMode": "symbol",
                "blend": 0,
                "kind": "speak",
                "rowSpan": 1,
                "colSpan": 1,
                "hidden": False,
            }
        )

    return {"cards": cards}


def main() -> None:
    known = load_known_symbols()

    board = {
        "schemaVersion": 2,
        "name": "Demo",
        "rows": 3,
        "cols": 3,
        "pages": [build_page(PAGE_ONE, known), build_page(PAGE_TWO, known)],
    }

    OUTPUT.write_text(json.dumps(board, indent=2), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)}")
    print(f"{len(PAGE_ONE)} cards on page one, {len(PAGE_TWO)} on page two")


if __name__ == "__main__":
    main()
