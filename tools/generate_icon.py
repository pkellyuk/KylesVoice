"""Generates the Kyle's Voice launcher and store icons.

Run from the repository root:

    python3 tools/generate_icon.py

The icon is generated rather than drawn by hand so it is reproducible, so the
colours stay in step with the app's palette, and so a contributor can change it
without needing image-editing software.

The design is the app itself: a three-by-two board with the top-left card lit,
the way a card looks the instant it is pressed. It is deliberately plain. The
icon has to read at 48px on a cluttered home screen, so there is no gradient, no
shadow and no lettering.
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Straight from the app's card palette in lib/screens/card_editor.dart.
BACKGROUND = (14, 18, 22)
CARD_IDLE = (42, 51, 61)
CARD_LIT = (79, 163, 209)
CARD_WARM = (107, 163, 104)

# Rendered large and downsampled, which gives clean corners without needing
# anti-aliased drawing primitives.
SUPERSAMPLE = 4

REPO_ROOT = Path(__file__).resolve().parent.parent
ANDROID_RES = REPO_ROOT / "app" / "android" / "app" / "src" / "main" / "res"

# Android launcher densities.
LAUNCHER_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Play Store listing icon.
STORE_ICON = REPO_ROOT / "docs" / "store" / "icon-512.png"


def draw_icon(size: int, *, padded: bool) -> Image.Image:
    """Draws the icon at ``size`` pixels square.

    ``padded`` insets the artwork, which the Play Store icon needs because the
    store crops to a rounded square and the launcher does not.
    """
    scale = size * SUPERSAMPLE
    image = Image.new("RGBA", (scale, scale), BACKGROUND)
    draw = ImageDraw.Draw(image)

    margin = scale * (0.16 if padded else 0.10)
    gutter = scale * 0.05
    radius = scale * 0.055

    columns = 3
    rows = 2

    board_width = scale - margin * 2
    cell_width = (board_width - gutter * (columns - 1)) / columns

    # Square cells, so the icon reads as the board rather than as a column of
    # tall tiles. The board is then centred vertically in the square canvas.
    cell_height = cell_width
    board_height = cell_height * rows + gutter * (rows - 1)
    margin_top = (scale - board_height) / 2

    for row in range(rows):
        for column in range(columns):
            left = margin + column * (cell_width + gutter)
            top = margin_top + row * (cell_height + gutter)

            # Top-left is lit, as if just pressed. One warm card keeps the icon
            # from reading as an empty grid.
            if row == 0 and column == 0:
                colour = CARD_LIT
            elif row == 1 and column == 2:
                colour = CARD_WARM
            else:
                colour = CARD_IDLE

            draw.rounded_rectangle(
                [left, top, left + cell_width, top + cell_height],
                radius=radius,
                fill=colour,
            )

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    for directory, size in LAUNCHER_SIZES.items():
        target_dir = ANDROID_RES / directory
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / "ic_launcher.png"

        draw_icon(size, padded=False).save(target)
        print(f"wrote {target.relative_to(REPO_ROOT)} ({size}x{size})")

    STORE_ICON.parent.mkdir(parents=True, exist_ok=True)
    draw_icon(512, padded=True).save(STORE_ICON)
    print(f"wrote {STORE_ICON.relative_to(REPO_ROOT)} (512x512)")


if __name__ == "__main__":
    main()
