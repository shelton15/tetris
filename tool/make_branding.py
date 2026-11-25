"""Builds the app icon and splash images from assets/branding/cairn_logo.svg.

The source logo is a stack of coloured blocks with the word CAIRN in black
underneath. This script writes, into assets/branding/:

  icon.png            1024x1024 launcher icon: the block stack on the app's
                      light ground (no text; it is unreadable at icon size).
  icon_foreground.png 1024x1024 Android adaptive-icon foreground: the block
                      stack on transparency, inside the 66% safe zone.
  splash.png          Full logo (blocks + word) on transparency, for the
                      light launch screen.
  splash_dark.png     Same with the word recoloured white, for dark mode.

Run:  python3 tool/make_branding.py   (needs rsvg-convert on PATH)
"""

import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "branding"
SOURCE = (OUT / "cairn_logo.svg").read_text()

LIGHT_GROUND = "#F7F7FA"  # matches the app's light scaffold colour
WORD_FILL = 'fill="rgb(0,0,0)"'  # only the letters C, A, I, R, N use pure black

paths = re.findall(r"<path.*?/>", SOURCE, re.S)
block_paths = [p for p in paths if WORD_FILL not in p]
assert len(paths) - len(block_paths) == 5, "expected exactly five letter paths"

# Regions of the 1024-unit source canvas.
MARK_BOX = (352, 319, 300)  # square around the block stack
LOGO_BOX = (105, 326, 660, 476)  # blocks + word


def svg(width, height, body, background=None):
    bg = f'<rect width="100%" height="100%" fill="{background}"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="geometricPrecision">{bg}{body}</svg>'
    )


def placed(content, box, x, y, size):
    """Scales the square source [box] into a size x size square at (x, y)."""
    bx, by, bs = box
    s = size / bs
    return f'<g transform="translate({x},{y}) scale({s}) translate({-bx},{-by})">{content}</g>'


def render(name, document, width):
    svg_file = OUT / f".{name}.svg"
    svg_file.write_text(document)
    subprocess.run(
        ["rsvg-convert", "-w", str(width), "-o", str(OUT / f"{name}.png"), str(svg_file)],
        check=True,
    )
    svg_file.unlink()


blocks = "".join(block_paths)

# Launcher icon: the stack fills ~70% of the tile, so it reads at home-screen size.
render("icon", svg(1024, 1024, placed(blocks, MARK_BOX, 112, 112, 800), LIGHT_GROUND), 1024)

# Adaptive foreground: Android masks the outer third, so keep it inside 66%.
render("icon_foreground", svg(1024, 1024, placed(blocks, MARK_BOX, 262, 262, 500)), 1024)

# Splash: the full logo, cropped to its content.
lx, ly, lw, lh = LOGO_BOX
everything = "".join(paths)
crop = f'<g transform="translate({-lx},{-ly})">{{}}</g>'
render("splash", svg(lw, lh, crop.format(everything)), 960)
render("splash_dark", svg(lw, lh, crop.format(everything.replace(WORD_FILL, 'fill="rgb(255,255,255)"'))), 960)

print("Wrote icon.png, icon_foreground.png, splash.png, splash_dark.png to", OUT)
