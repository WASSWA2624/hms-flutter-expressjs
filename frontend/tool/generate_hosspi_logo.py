"""Generate HOSSPI HMS logo: HOSSPI on top; sharp + and HMS below."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "assets" / "logos"
WEB_FAVICON = Path(__file__).resolve().parents[1] / "web" / "favicon.png"
SIZE = 1024
SCALE = 4
S = SIZE * SCALE

AZURE_700 = (26, 92, 173, 255)  # #1A5CAD

FONT_PATH = (
    Path(__file__).resolve().parents[1] / "assets" / "fonts" / "Roboto-Bold.ttf"
)


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


def _measure_text(
    word: str, font: ImageFont.ImageFont
) -> tuple[int, int]:
    probe = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(probe)
    draw.text((S // 2, S // 2), word, font=font, fill=AZURE_700, anchor="mm")
    ink = probe.getbbox()
    assert ink is not None
    return ink[2] - ink[0], ink[3] - ink[1]


def make_logo() -> Image.Image:
    """
    Strong stacked badge:
         HOSSPI
        +  HMS
    """
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    pad_x = int(S * 0.09)
    pad_y = int(S * 0.08)
    stroke = max(18, int(S * 0.030))
    corner = int(S * 0.085)
    gap_row = int(S * 0.055)
    gap_icons = int(S * 0.055)

    title_font = _load_font(int(S * 0.145))
    hms_font = _load_font(int(S * 0.12))
    title = "HOSSPI"
    hms = "HMS"

    title_w, title_h = _measure_text(title, title_font)
    hms_w, hms_h = _measure_text(hms, hms_font)

    plus_arm = int(S * 0.145)
    plus_thickness = max(18, int(plus_arm * 0.38))

    row2_h = max(plus_arm, hms_h)
    row2_w = plus_arm + gap_icons + hms_w

    content_w = max(title_w, row2_w)
    content_h = title_h + gap_row + row2_h

    box_w = min(content_w + pad_x * 2, int(S * 0.90))
    box_h = min(content_h + pad_y * 2, int(S * 0.90))

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

    # Row 1: HOSSPI
    title_cy = content_top + title_h / 2
    draw.text((cx, title_cy), title, font=title_font, fill=AZURE_700, anchor="mm")

    # Row 2: sharp + and HMS
    row2_cy = content_top + title_h + gap_row + row2_h / 2
    row2_left = cx - row2_w / 2
    plus_cx = row2_left + plus_arm / 2
    hms_left = row2_left + plus_arm + gap_icons

    _draw_plus_sharp(draw, plus_cx, row2_cy, plus_arm, plus_thickness, AZURE_700)
    draw.text((hms_left, row2_cy), hms, font=hms_font, fill=AZURE_700, anchor="lm")

    out = Image.alpha_composite(base, layer)
    return out.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_splash(logo: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    side = int(SIZE * 0.90)
    scaled = logo.resize((side, side), Image.Resampling.LANCZOS)
    offset = (SIZE - side) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = make_logo()
    splash = make_splash(logo)

    targets = {
        OUT / "logo.png": logo,
        OUT / "favicon.png": logo.copy(),
        OUT / "splash.png": splash,
        WEB_FAVICON: logo.copy(),
    }

    for path, img in targets.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path} bbox={img.getbbox()}")

    # Remove previous logo backups — this mark fully replaces them
    for legacy in OUT.glob("*_legacy.png"):
        legacy.unlink()
        print(f"removed {legacy.name}")


if __name__ == "__main__":
    main()
