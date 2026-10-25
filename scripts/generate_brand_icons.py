#!/usr/bin/env python3
"""Iconos ⌘ estilo macOS: vidrio gris (Dock) y template en barra de menú."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Instalá Pillow: python3 -m pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "HotSlot/Resources/Assets.xcassets/AppIcon.appiconset"
MENU_ICON_DIR = ROOT / "HotSlot/Resources/Assets.xcassets/MenuBarIcon.imageset"


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Apple Symbols.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _rounded_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    inset = max(0, int(size * 0.04))
    radius = int(size * 0.223)  # ~squircle macOS
    for y in range(inset, size - inset):
        t = (y - inset) / max(size - 2 * inset - 1, 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        draw.line([(inset, y), (size - inset, y)], fill=(*color, 255))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, size - inset, size - inset), radius=radius, fill=255
    )
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, mask=mask)
    return out, draw, inset, radius


def render_app_icon(size: int) -> Image.Image:
    """Dock / Finder: placa gris tipo Liquid Glass + ⌘ oscuro."""
    base, draw, inset, radius = _rounded_gradient(
        size, top=(244, 244, 247), bottom=(210, 210, 218)
    )
    # Brillo superior
    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(gloss)
    gdraw.ellipse(
        (inset, inset, size - inset, int(size * 0.62)),
        fill=(255, 255, 255, 90),
    )
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, size - inset, size - inset), radius=radius, fill=255
    )
    base = Image.alpha_composite(base, Image.composite(gloss, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask))

    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(
        (inset, inset, size - inset, size - inset),
        radius=radius,
        outline=(255, 255, 255, 140),
        width=max(1, size // 128),
    )
    draw.rounded_rectangle(
        (inset, inset, size - inset, size - inset),
        radius=radius,
        outline=(0, 0, 0, 28),
        width=max(1, size // 256),
    )

    font = _font(int(size * 0.46))
    text = "⌘"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        ((size - tw) / 2, (size - th) / 2 - size * 0.035),
        text,
        fill=(58, 58, 60, 255),
        font=font,
    )
    return base


def render_menu_icon(size: int) -> Image.Image:
    """Barra de menú: solo glifo (template → gris del sistema)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    font = _font(int(size * 0.88))
    text = "⌘"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        ((size - tw) / 2, (size - th) / 2 - size * 0.06),
        text,
        fill=(0, 0, 0, 255),
        font=font,
    )
    return img


def save_app_icons() -> None:
    mapping = {
        "icon_16.png": 16,
        "icon_32.png": 32,
        "icon_64.png": 64,
        "icon_128.png": 128,
        "icon_256.png": 256,
        "icon_512.png": 512,
        "icon_1024.png": 1024,
    }
    APP_ICON_DIR.mkdir(parents=True, exist_ok=True)
    for name, px in mapping.items():
        render_app_icon(px).save(APP_ICON_DIR / name)


def save_menu_icons() -> None:
    MENU_ICON_DIR.mkdir(parents=True, exist_ok=True)
    render_menu_icon(18).save(MENU_ICON_DIR / "icon.png")
    render_menu_icon(36).save(MENU_ICON_DIR / "icon_36.png")


def main() -> None:
    save_app_icons()
    save_menu_icons()
    print("✓ Iconos grises (app) + template (menu bar) generados")


if __name__ == "__main__":
    main()
