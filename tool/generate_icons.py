"""Derives the application icons from the source logo.

Run from the repository root: `python tool/generate_icons.py`.
"""

from PIL import Image

SOURCE = "assets/logo.png"

SQUARE_PNG = "assets/icon.png"
SQUARE_SIZE = 512

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ICO_TARGETS = ["assets/tray_icon.ico", "windows/runner/resources/app_icon.ico"]


def square_icon(logo: Image.Image) -> Image.Image:
    """Returns the whole logo centered in a square canvas.

    The artwork is nearly square once its transparent margins are trimmed, so
    it needs no cropping: padding to a square keeps every icon size faithful
    to the logo instead of cutting into it.
    """
    content = logo.crop(logo.getbbox())
    side = max(content.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(
        content,
        ((side - content.width) // 2, (side - content.height) // 2),
    )
    return canvas


def main() -> None:
    logo = Image.open(SOURCE).convert("RGBA")
    square = square_icon(logo)

    square.resize((SQUARE_SIZE, SQUARE_SIZE), Image.LANCZOS).save(SQUARE_PNG)
    print(f"ecrit {SQUARE_PNG}")

    largest = square.resize((ICO_SIZES[-1], ICO_SIZES[-1]), Image.LANCZOS)
    for target in ICO_TARGETS:
        largest.save(target, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
        print(f"ecrit {target}")


if __name__ == "__main__":
    main()
