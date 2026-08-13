"""Generate HOSSPI HMS logo: HOSSPI on top; sharp + and HMS below."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "logos"
WEB = ROOT / "web"
WEB_ICONS = WEB / "icons"
SIZE = 1024
SCALE = 4
S = SIZE * SCALE

AZURE_700 = (26, 92, 173, 255)  # #1A5CAD

FONT_PATH = ROOT / "assets" / "fonts" / "Roboto-Bold.ttf"


def _rect(
    draw: ImageDraw.ImageDraw,
    xy: list[float],
    fill: tuple[int, int, int, int],
) -> None:
    draw.rectangle(xy, fill=fill)


def _rounded_rect(
    draw: ImageDraw.ImageDraw,
    xy: list[float],
    radius: float,
    *,
    fill: tuple[int, int, int, int] | None = None,
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def _draw_plus_sharp(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    arm: float,
    thickness: float,
    fill: tuple[int, int, int, int],
) -> None:
    """Medical/plus mark with square ends (no corner radii)."""
    half_arm = arm / 2
    half_t = thickness / 2
    _rect(draw, [cx - half_arm, cy - half_t, cx + half_arm, cy + half_t], fill)
    _rect(draw, [cx - half_t, cy - half_arm, cx + half_t, cy + half_arm], fill)


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(str(FONT_PATH), size=size)
    except OSError:
        return ImageFont.load_default()


def _measure_text(word: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    probe = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(probe)
    draw.text((S // 2, S // 2), word, font=font, fill=AZURE_700, anchor="mm")
    ink = probe.getbbox()
    assert ink is not None
    return ink[2] - ink[0], ink[3] - ink[1]


def _fit_mark_to_square(mark: Image.Image, fill: float = 0.94) -> Image.Image:
    """Crop to ink and scale up so the badge fills most of the square canvas."""
    bbox = mark.getbbox()
    assert bbox is not None
    cropped = mark.crop(bbox)
    cw, ch = cropped.size
    target = int(SIZE * fill)
    scale = min(target / cw, target / ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    scaled = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((SIZE - new_w) // 2, (SIZE - new_h) // 2))
    return canvas


def make_logo() -> Image.Image:
    """
    Strong stacked badge:
         HOSSPI
        +  HMS
    """
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Tighter padding so the mark reads larger at small UI sizes
    pad_x = int(S * 0.06)
    pad_y = int(S * 0.055)
    stroke = max(22, int(S * 0.034))
    corner = int(S * 0.07)
    gap_row = int(S * 0.045)
    gap_icons = int(S * 0.045)

    title_font = _load_font(int(S * 0.175))
    hms_font = _load_font(int(S * 0.145))
    title = "HOSSPI"
    hms = "HMS"

    title_w, title_h = _measure_text(title, title_font)
    hms_w, hms_h = _measure_text(hms, hms_font)

    plus_arm = int(S * 0.165)
    plus_thickness = max(22, int(plus_arm * 0.40))

    row2_h = max(plus_arm, hms_h)
    row2_w = plus_arm + gap_icons + hms_w

    content_w = max(title_w, row2_w)
    content_h = title_h + gap_row + row2_h

    box_w = content_w + pad_x * 2
    box_h = content_h + pad_y * 2

    box_x0 = (S - box_w) // 2
    box_y0 = (S - box_h) // 2
    box_x1 = box_x0 + box_w
    box_y1 = box_y0 + box_h

    _rounded_rect(
        draw,
        [box_x0, box_y0, box_x1, box_y1],
        corner,
        outline=AZURE_700,
        width=stroke,
    )

    cx = (box_x0 + box_x1) / 2
    content_top = box_y0 + (box_h - content_h) / 2

    title_cy = content_top + title_h / 2
    draw.text((cx, title_cy), title, font=title_font, fill=AZURE_700, anchor="mm")

    row2_cy = content_top + title_h + gap_row + row2_h / 2
    row2_left = cx - row2_w / 2
    plus_cx = row2_left + plus_arm / 2
    hms_left = row2_left + plus_arm + gap_icons

    _draw_plus_sharp(draw, plus_cx, row2_cy, plus_arm, plus_thickness, AZURE_700)
    draw.text((hms_left, row2_cy), hms, font=hms_font, fill=AZURE_700, anchor="lm")

    hi_res = layer
    # Downscale first for AA, then fit tightly into the square
    down = hi_res.resize((SIZE * 2, SIZE * 2), Image.Resampling.LANCZOS)
    down = down.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return _fit_mark_to_square(down, fill=0.96)


def make_splash(logo: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    side = int(SIZE * 0.92)
    scaled = logo.resize((side, side), Image.Resampling.LANCZOS)
    offset = (SIZE - side) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def _save_web_icon(logo: Image.Image, path: Path, size: int, *, maskable: bool) -> None:
    if maskable:
        # Safe-zone padded icon on solid brand-tinted white for installability
        canvas = Image.new("RGBA", (size, size), (244, 249, 254, 255))  # azure50
        pad = int(size * 0.12)
        inner = size - pad * 2
        scaled = logo.resize((inner, inner), Image.Resampling.LANCZOS)
        canvas.alpha_composite(scaled, (pad, pad))
    else:
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        scaled = logo.resize((size, size), Image.Resampling.LANCZOS)
        canvas.alpha_composite(scaled, (0, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, "PNG", optimize=True)
    print(f"wrote {path}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WEB_ICONS.mkdir(parents=True, exist_ok=True)

    logo = make_logo()
    splash = make_splash(logo)

    targets = {
        OUT / "logo.png": logo,
        OUT / "favicon.png": logo.copy(),
        OUT / "splash.png": splash,
        WEB / "favicon.png": logo.copy(),
    }

    for path, img in targets.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path} bbox={img.getbbox()}")

    _save_web_icon(logo, WEB_ICONS / "Icon-192.png", 192, maskable=False)
    _save_web_icon(logo, WEB_ICONS / "Icon-512.png", 512, maskable=False)
    _save_web_icon(logo, WEB_ICONS / "Icon-maskable-192.png", 192, maskable=True)
    _save_web_icon(logo, WEB_ICONS / "Icon-maskable-512.png", 512, maskable=True)

    for legacy in OUT.glob("*_legacy.png"):
        legacy.unlink()
        print(f"removed {legacy.name}")


if __name__ == "__main__":
    main()
