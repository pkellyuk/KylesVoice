"""Pads device screenshots to a Play-compliant aspect ratio.

Run from the repository root:

    python3 tools/pad_screenshots.py <source-dir> <name>=<file> ...

Google Play rejects a screenshot whose long edge is more than twice its short
edge. A modern phone is taller than 2:1 — a Pixel 6 is 2400 x 1080, or 2.22:1 —
so a landscape screenshot straight off the device is refused even though it is
exactly what the user sees.

Padding rather than cropping is the honest fix: nothing is hidden, and the bars
are the app's own background colour, so they read as part of the board rather
than as letterboxing. Output is 24-bit RGB PNG, which is what Play asks for;
screencap produces RGBA, which it does not.
"""

import sys
from pathlib import Path

from PIL import Image

# The board's background, sampled from the app rather than guessed.
BACKGROUND = (14, 18, 22)

# Play's limit is exactly 2.0. Sitting on the boundary invites a rounding
# argument with a submission checker, so leave visible headroom.
MAX_RATIO = 1.9

REPO_ROOT = Path(__file__).resolve().parent.parent
DESTINATION = REPO_ROOT / "docs" / "store"


def pad(source, destination):
    """Writes source to destination, padded to at most MAX_RATIO and 24-bit."""
    if source is None:
        raise ValueError("source is required")

    if destination is None:
        raise ValueError("destination is required")

    image = Image.open(source).convert("RGB")
    width, height = image.size

    long_edge = max(width, height)
    short_edge = min(width, height)

    if short_edge <= 0:
        raise ValueError(f"{source} has a zero dimension")

    ratio = long_edge / short_edge

    if ratio <= MAX_RATIO:
        image.save(destination)
        print(f"{destination.name}: {width}x{height} already {ratio:.2f}:1")
        return

    # Grow the short edge. Never shrink the long one: cropping a screenshot
    # loses the very content it is meant to show.
    needed = int(round(long_edge / MAX_RATIO))

    if width >= height:
        padded = Image.new("RGB", (width, needed), BACKGROUND)
        padded.paste(image, (0, (needed - height) // 2))
    else:
        padded = Image.new("RGB", (needed, height), BACKGROUND)
        padded.paste(image, ((needed - width) // 2, 0))

    padded.save(destination)
    print(
        f"{destination.name}: {width}x{height} ({ratio:.2f}:1) "
        f"-> {padded.size[0]}x{padded.size[1]} ({MAX_RATIO}:1 max)"
    )


def main(argv):
    if argv is None:
        raise ValueError("argv is required")

    if len(argv) < 2:
        print(__doc__)
        return 1

    for pair in argv[1:]:
        if "=" not in pair:
            print(f"expected <name>=<file>, got {pair}")
            return 1

        name, _, path = pair.partition("=")
        source = Path(path)

        if source.exists() is False:
            print(f"no such file: {source}")
            return 1

        pad(source, DESTINATION / f"{name}.png")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
