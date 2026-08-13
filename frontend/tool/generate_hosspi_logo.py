"""Generate HOSSPI HMS logo: sharp + in a square rounded frame, full-bleed."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "logos"
WEB = ROOT / "web"
WEB_ICONS = WEB / "icons"

# High-resolution master; UI/web assets are derived from this.
MASTER = 2048
SCALE = 4
S = MASTER * SCALE  # supersample for clean edges

# Brighter brand blues (AppLightThemePalette azure400 / azure500)
AZURE_400 = (107, 166, 224, 255)  # #6BA6E0 — frame
AZURE_500 = (59, 135, 212, 255)  # #3B87D4 — plus


def _rect(
    draw: ImageDraw.ImageDraw,
    xy: list[float],
    fill: tuple[int, int, int, int],
) -> None:
    draw.rectangle(xy, fill=fill)


def _draw_plus_sharp(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    arm: float,
    thickness: float,
    fill: tuple[int, int, int, int],
) -> None:
    """Plus mark with square ends (no corner radii)."""
    half_arm = arm / 2
    half_t = thickness / 2
    _rect(draw, [cx - half_arm, cy - half_t, cx + half_arm, cy + half_t], fill)
    _rect(draw, [cx - half_t, cy - half_arm, cx + half_t, cy + half_arm], fill)


def _fit_to_square(mark: Image.Image, size: int, fill: float = 0.98) -> Image.Image:
    """Crop to ink and scale so the mark nearly fills the square canvas."""
    bbox = mark.getbbox()
    assert bbox is not None
    cropped = mark.crop(bbox)
    cw, ch = cropped.size
    target = int(size * fill)
    scale = min(target / cw, target / ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    scaled = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((size - new_w) // 2, (size - new_h) // 2))
    return canvas


def make_logo_master() -> Image.Image:
    """
    Square badge:
      ┌───────┐
      │   +   │
      └───────┘
    Transparent fill, brand-blue stroke and plus. Fully fitted.
    """
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Near full-bleed square frame
    inset = int(S * 0.02)
    stroke = max(48, int(S * 0.055))
    corner = int(S * 0.12)

    box = [inset, inset, S - inset, S - inset]
    draw.rounded_rectangle(
        box,
        radius=corner,
        outline=AZURE_400,
        width=stroke,
    )

    cx = cy = S / 2
    # Plus sized to sit boldly inside the frame — long arms, still clear of stroke
    inner = S - 2 * inset - 2 * stroke
    plus_arm = inner * 0.82
    plus_thickness = plus_arm * 0.22
    _draw_plus_sharp(draw, cx, cy, plus_arm, plus_thickness, AZURE_500)

    # Downsample supersampled master → MASTER px with AA
    down = layer.resize((MASTER * 2, MASTER * 2), Image.Resampling.LANCZOS)
    down = down.resize((MASTER, MASTER), Image.Resampling.LANCZOS)
    return _fit_to_square(down, MASTER, fill=0.995)


def _scale(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _save_web_icon(
    logo: Image.Image, path: Path, size: int, *, maskable: bool
) -> None:
    if maskable:
        canvas = Image.new("RGBA", (size, size), (244, 249, 254, 255))
        pad = int(size * 0.10)
        inner = size - pad * 2
        scaled = _scale(logo, inner)
        canvas.alpha_composite(scaled, (pad, pad))
    else:
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(_scale(logo, size), (0, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, "PNG", optimize=True)
    print(f"wrote {path}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WEB_ICONS.mkdir(parents=True, exist_ok=True)

    master = make_logo_master()
    # App assets at 1024 for Flutter; master kept sharpness when downscaling
    logo = _scale(master, 1024)
    splash = _scale(master, 1024)
    favicon = _scale(master, 1024)

    targets = {
        OUT / "logo.png": logo,
        OUT / "favicon.png": favicon,
        OUT / "splash.png": splash,
        WEB / "favicon.png": favicon.copy(),
    }

    for path, img in targets.items():
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path} size={img.size} bbox={img.getbbox()}")

    # Also keep a 2048 master for future exports
    master_path = OUT / "logo_master.png"
    master.save(master_path, "PNG", optimize=True)
    print(f"wrote {master_path} size={master.size}")

    _save_web_icon(master, WEB_ICONS / "Icon-192.png", 192, maskable=False)
    _save_web_icon(master, WEB_ICONS / "Icon-512.png", 512, maskable=False)
    _save_web_icon(master, WEB_ICONS / "Icon-maskable-192.png", 192, maskable=True)
    _save_web_icon(master, WEB_ICONS / "Icon-maskable-512.png", 512, maskable=True)

    for legacy in OUT.glob("*_legacy.png"):
        legacy.unlink()
        print(f"removed {legacy.name}")


if __name__ == "__main__":
    main()
