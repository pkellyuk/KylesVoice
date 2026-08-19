"""Generates the 1024x500 Play Store feature graphic.

Run from the repository root:

    python3 tools/generate_feature_graphic.py

Generated rather than designed by hand for the same reasons as the icon: it is
reproducible, it stays in step with the app's palette, and a contributor can
change the wording without image-editing software.

Play crops this differently across surfaces and may overlay controls near the
centre, so the artwork sits left, the text sits right, and nothing important goes
within about 40px of any edge.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 1024
HEIGHT = 500
SUPERSAMPLE = 2

BACKGROUND = (14, 18, 22)
CARD_IDLE = (42, 51, 61)
CARD_LIT = (79, 163, 209)
CARD_WARM = (107, 163, 104)
CARD_TEAL = (79, 179, 168)

TITLE = (255, 255, 255)
SUBTITLE = (200, 210, 220)
FOOTNOTE = (120, 132, 145)

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT = REPO_ROOT / "docs" / "store" / "feature-graphic-1024x500.png"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/segoeui.ttf",
    "C:/Windows/Fonts/arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

REGULAR_CANDIDATES = [
    "C:/Windows/Fonts/segoeui.ttf",
    "C:/Windows/Fonts/arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def load_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)

    raise SystemExit(
        "No usable TrueType font found. Add one to FONT_CANDIDATES."
    )


def draw_board(draw: ImageDraw.ImageDraw, left: int, top: int, size: int) -> None:
    """Draws the board motif: three by two, with two cards lit."""
    columns = 3
    rows = 2
    gutter = size * 0.055
    radius = size * 0.06

    cell = (size - gutter * (columns - 1)) / columns
    lit = {(0, 0): CARD_LIT, (1, 2): CARD_WARM, (1, 0): CARD_TEAL}

    for row in range(rows):
        for column in range(columns):
            x = left + column * (cell + gutter)
            y = top + row * (cell + gutter)

            draw.rounded_rectangle(
                [x, y, x + cell, y + cell],
                radius=radius,
                fill=lit.get((row, column), CARD_IDLE),
            )


def main() -> None:
    scale = SUPERSAMPLE
    image = Image.new("RGB", (WIDTH * scale, HEIGHT * scale), BACKGROUND)
    draw = ImageDraw.Draw(image)

    title_font = load_font(FONT_CANDIDATES, 76 * scale)
    subtitle_font = load_font(REGULAR_CANDIDATES, 34 * scale)
    footnote_font = load_font(REGULAR_CANDIDATES, 24 * scale)

    # Artwork on the left, comfortably inside the safe area.
    board_size = 300 * scale
    draw_board(
        draw,
        left=72 * scale,
        top=(HEIGHT * scale - (board_size / 3 * 2 + board_size * 0.055)) / 2,
        size=board_size,
    )

    text_left = 452 * scale
    draw.text((text_left, 168 * scale), "Kyle's Voice", font=title_font, fill=TITLE)
    draw.text(
        (text_left, 262 * scale),
        "Picture cards that speak",
        font=subtitle_font,
        fill=SUBTITLE,
    )
    draw.text(
        (text_left, 316 * scale),
        "Free. No ads. No accounts. Open source.",
        font=footnote_font,
        fill=FOOTNOTE,
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.resize((WIDTH, HEIGHT), Image.LANCZOS).save(OUTPUT)
    print(f"wrote {OUTPUT.relative_to(REPO_ROOT)} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
