from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


SOURCE_DIR = Path(r"C:\Users\caiha\AppData\Local\Temp")
OUTPUT_DIR = Path(__file__).parent / "inventory_icon_adjusted"
SOURCES = {
    "kei_inventory_normal_deepened_blue.png": SOURCE_DIR / "codex-clipboard-177c725b-8a32-421f-842f-8b6f63e95b0c.png",
    "kei_inventory_closed_eye_deepened_blue.png": SOURCE_DIR / "codex-clipboard-0328f6bf-7f1a-493c-b69c-b67f754f6f6a.png",
}


def deepen_and_thicken(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    rgb = image.convert("RGB")

    # Keep the highlight structure, while making the small icon legible in DST's dark UI.
    rgb = ImageEnhance.Brightness(rgb).enhance(0.94)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.16)
    rgb = ImageEnhance.Color(rgb).enhance(1.10)

    # Identify original dark ink/hair lines, expand them by one pixel, and apply only inside
    # the existing non-transparent silhouette so the alpha outline remains unchanged.
    luma = rgb.convert("L")
    ink = luma.point(lambda value: 255 if value < 60 else 0)
    opaque = alpha.point(lambda value: 255 if value > 80 else 0)
    expanded = ink.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(expanded, ink)
    ring = ImageChops.multiply(ring, opaque).point(lambda value: int(value * 0.24))
    ink = ImageChops.multiply(ink, opaque).point(lambda value: int(value * 0.10))

    outline = Image.new("RGB", image.size, (18, 22, 42))
    rgb = Image.composite(outline, rgb, ring)
    rgb = Image.composite(outline, rgb, ink)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=0.7, percent=90, threshold=3))

    foreground = Image.merge("RGBA", (*rgb.split(), alpha))
    result = make_rounded_background(foreground.size)
    result.alpha_composite(foreground)
    result.save(destination)


def make_rounded_background(size: tuple[int, int]) -> Image.Image:
    """Create a clean pale-blue inventory-tile background with antialiased 9px corners."""
    factor = 4
    width, height = size
    canvas = Image.new("RGBA", (width * factor, height * factor), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    box = (0, 0, width * factor - 1, height * factor - 1)
    radius = 9 * factor
    draw.rounded_rectangle(box, radius=radius, fill=(188, 216, 237, 255))
    draw.rounded_rectangle(box, radius=radius, outline=(108, 151, 185, 255), width=factor)
    draw.rounded_rectangle(
        (factor, factor, width * factor - 1 - factor, height * factor - 1 - factor),
        radius=8 * factor,
        outline=(225, 240, 249, 180),
        width=factor,
    )
    return canvas.resize(size, Image.Resampling.LANCZOS)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for output_name, source in SOURCES.items():
        deepen_and_thicken(source, OUTPUT_DIR / output_name)


if __name__ == "__main__":
    main()
