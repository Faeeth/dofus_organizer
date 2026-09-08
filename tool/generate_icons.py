"""Generates the application and notification area icons.

Run from the repository root: `python tool/generate_icons.py`.
"""

from PIL import Image, ImageDraw

# Four rounded tiles on a dark plate; the highlighted one stands for the client
# currently in the foreground.
BACKGROUND = (14, 16, 20, 255)
TILE = (86, 96, 112, 255)
ACTIVE_TILE = (217, 164, 65, 255)

SIZES = [16, 24, 32, 48, 64, 128, 256]
TARGETS = ["assets/tray_icon.ico", "windows/runner/resources/app_icon.ico"]


def render(size: int) -> Image.Image:
    """Renders the icon at |size| pixels, supersampled for clean edges."""
    scale = 8
    canvas = size * scale
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        [0, 0, canvas - 1, canvas - 1],
        radius=int(canvas * 0.22),
        fill=BACKGROUND,
    )

    margin = canvas * 0.18
    gap = canvas * 0.07
    tile = (canvas - 2 * margin - gap) / 2
    radius = max(1, int(tile * 0.22))
    for row in range(2):
        for column in range(2):
            x = margin + column * (tile + gap)
            y = margin + row * (tile + gap)
            fill = ACTIVE_TILE if row == 0 and column == 0 else TILE
            draw.rounded_rectangle(
                [x, y, x + tile, y + tile], radius=radius, fill=fill
            )
    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    largest = render(SIZES[-1])
    for target in TARGETS:
        largest.save(target, format="ICO", sizes=[(s, s) for s in SIZES])
        print(f"ecrit {target}")


if __name__ == "__main__":
    main()
