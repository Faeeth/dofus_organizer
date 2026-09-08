"""Derives the application icons from the source logo.

Run from the repository root: `python tool/generate_icons.py`.
"""

from PIL import Image

SOURCE = "assets/logo.png"

# Square icon, cropped on the egg and the F1 key. The full logo carries the
# "Organizer" wordmark, which turns to mush below 48 pixels; the crop stays
# readable down to the 16 pixel notification area icon.
CROP = (250, 25, 1030, 805)

SQUARE_PNG = "assets/icon.png"
SQUARE_SIZE = 512

ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ICO_TARGETS = ["assets/tray_icon.ico", "windows/runner/resources/app_icon.ico"]


def main() -> None:
    logo = Image.open(SOURCE).convert("RGBA")
    square = logo.crop(CROP)

    square.resize((SQUARE_SIZE, SQUARE_SIZE), Image.LANCZOS).save(SQUARE_PNG)
    print(f"ecrit {SQUARE_PNG}")

    largest = square.resize((ICO_SIZES[-1], ICO_SIZES[-1]), Image.LANCZOS)
    for target in ICO_TARGETS:
        largest.save(target, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
        print(f"ecrit {target}")


if __name__ == "__main__":
    main()
