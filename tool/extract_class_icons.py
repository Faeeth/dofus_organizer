"""Extracts the class icons used by the character rows.

The artwork comes from the game files, unpacked by the companion project
dtracker. Run from the repository root:

    python tool/extract_class_icons.py [chemin/vers/dtracker]
"""

import os
import sys

from PIL import Image

DEFAULT_SOURCE = r"D:\claude\dtracker\capture\data\images\class\base"
TARGET = "assets/classes"
SIZE = 128

# Breed identifier as the game numbers it, mapped to the slug used for the
# asset name. 19 is unused by the game.
BREEDS = {
    1: "feca",
    2: "osamodas",
    3: "enutrof",
    4: "sram",
    5: "xelor",
    6: "ecaflip",
    7: "eniripsa",
    8: "iop",
    9: "cra",
    10: "sadida",
    11: "sacrieur",
    12: "pandawa",
    13: "roublard",
    14: "zobal",
    15: "steamer",
    16: "eliotrope",
    17: "huppermage",
    18: "ouginak",
    20: "forgelance",
}

GENDERS = {0: "m", 1: "f"}


def square(image: Image.Image) -> Image.Image:
    """Centers the portrait in a transparent square, so the interface can lay
    the icons out on a single grid without per class special cases."""
    trimmed = image.crop(image.getbbox() or image.getbbox())
    side = max(trimmed.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(
        trimmed,
        ((side - trimmed.width) // 2, (side - trimmed.height) // 2),
    )
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not os.path.isdir(source):
        raise SystemExit(f"dossier source introuvable: {source}")
    os.makedirs(TARGET, exist_ok=True)

    written = 0
    for breed, slug in BREEDS.items():
        for gender, suffix in GENDERS.items():
            name = f"Head_{breed}{gender}.png"
            path = os.path.join(source, name)
            if not os.path.isfile(path):
                print(f"absent, ignore: {name}")
                continue
            with Image.open(path) as image:
                square(image.convert("RGBA")).save(
                    os.path.join(TARGET, f"{slug}_{suffix}.png")
                )
            written += 1
    print(f"{written} icones ecrites dans {TARGET}")


if __name__ == "__main__":
    main()
