#!/usr/bin/env python3
"""Recorta y escala capturas del panel a 1280×800 / 2560×1600 sin marco exterior."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "app-store-screenshots"
SOURCE_DIR = OUT / "source"

NAMES = [
    "01-panel-principal.png",
    "02-slot-peek.png",
    "03-historial-imagen.png",
]

SIZES = [
    ("1280x800", 1280, 800),
    ("2560x1600", 2560, 1600),
]


def _corner_background_rgb(image: Image.Image) -> tuple[int, int, int]:
    w, h = image.size
    points = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    rgb = image.convert("RGB")
    samples = [rgb.getpixel(point) for point in points]
    return (
        sum(sample[0] for sample in samples) // 4,
        sum(sample[1] for sample in samples) // 4,
        sum(sample[2] for sample in samples) // 4,
    )


def trim_border(image: Image.Image, threshold: int = 28) -> Image.Image:
    """Elimina el fondo oscuro alrededor del panel."""
    rgba = image.convert("RGBA")
    bg = _corner_background_rgb(rgba)
    width, height = rgba.size
    mask = Image.new("L", (width, height), 0)
    pixels = rgba.load()
    mask_pixels = mask.load()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 20:
                continue
            distance = abs(red - bg[0]) + abs(green - bg[1]) + abs(blue - bg[2])
            if distance > threshold:
                mask_pixels[x, y] = 255

    bbox = mask.getbbox()
    if not bbox:
        return rgba
    return rgba.crop(bbox)


def scale_cover(image: Image.Image, target_width: int, target_height: int) -> Image.Image:
    """Escala para llenar el canvas (sin bandas ni marco)."""
    scale = max(target_width / image.width, target_height / image.height)
    resized = image.resize(
        (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - target_width) // 2
    top = (resized.height - target_height) // 2
    cropped = resized.crop((left, top, left + target_width, top + target_height))
    return cropped.convert("RGB")


def export_sizes(source: Path) -> None:
    trimmed = trim_border(Image.open(source))
    for folder, width, height in SIZES:
        out_dir = OUT / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / source.name
        scale_cover(trimmed, width, height).save(out_path, "PNG", optimize=True)
        print(f"Wrote {out_path}")


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"Missing source folder: {SOURCE_DIR}")

    for name in NAMES:
        source = SOURCE_DIR / name
        if not source.exists():
            raise SystemExit(f"Missing screenshot source: {source}")
        export_sizes(source)


if __name__ == "__main__":
    main()
