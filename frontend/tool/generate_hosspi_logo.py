"""Generate HOSSPI HMS logo — hospital + simple IT/records, balanced & full-bleed.

Keeps the elegant powder field and clinical azure.
Adds stacked record cards (record-keeping) with light line detail (IT/data),
balanced beside the hospital facade, scaled to fill the squircle.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "logos"
WEB = ROOT / "web"
WEB_ICONS = WEB / "icons"

MASTER = 2048
SCALE = 3
S = MASTER * SCALE

AZURE_50 = (244, 249, 254, 255)
AZURE_100 = (230, 241, 252, 255)
AZURE_200 = (203, 224, 247, 255)
AZURE_600 = (36, 112, 194, 255)
AZURE_700 = (26, 92, 173, 255)
WHITE = (255, 255, 255, 255)


def _lerp(
    a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float
) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
        int(a[3] + (b[3] - a[3]) * t),
    )


def _fit_to_square(mark: Image.Image, size: int, fill: float = 0.998) -> Image.Image:
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
    inset = int(S * 0.018)
    box = [inset, inset, S - inset, S - inset]
    corner = int((S - 2 * inset) * 0.30)

    band = Image.new("RGBA", (1, S))
    for y in range(S):
        t = y / max(1, S - 1)
        band.putpixel((0, y), _lerp(AZURE_50, AZURE_100, t * 0.7))
    field = band.resize((S, S), Image.Resampling.BILINEAR)

    shape_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shape_mask).rounded_rectangle(box, radius=corner, fill=255)
    shape_mask = shape_mask.filter(
        ImageFilter.GaussianBlur(radius=max(1, S // 1300))
    )

    squircle = field.copy()
    squircle.putalpha(shape_mask)

    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle(
        box, radius=corner, outline=AZURE_200, width=max(4, int(S * 0.010))
    )
    ring.putalpha(ImageChops.multiply(ring.getchannel("A"), shape_mask))
    squircle = Image.alpha_composite(squircle, ring)

    # ---- Balanced composition (fills the mark) ----
    # Left: stacked records | Right: hospital + cross
    # Shared baseline, optically centered as one group.
    cx = S / 2
    cy = S / 2
    u = S * 0.82  # fill the mark; less empty field around glyphs

    # Hospital (right side of group)
    body_w = u * 0.46
    body_h = u * 0.34
    tower_w = u * 0.26
    tower_h = u * 0.56
    r = u * 0.04

    # Records stack (left) — sized to balance the hospital mass
    card_w = u * 0.33
    card_h = u * 0.40
    card_r = u * 0.036
    stack_offset = u * 0.038

    group_gap = u * 0.04
    group_w = card_w + group_gap + body_w
    group_left = cx - group_w / 2

    # Shared baseline — optically centered vertically
    baseline = cy + u * 0.22

    # Record cards position
    card_x0 = group_left
    card_y1 = baseline
    card_y0 = card_y1 - card_h

    # Hospital position
    body_left = group_left + card_w + group_gap
    body_right = body_left + body_w
    body_bot = baseline
    body_top = body_bot - body_h
    tower_left = body_left + (body_w - tower_w) / 2
    tower_right = tower_left + tower_w
    tower_top = body_bot - tower_h
    hosp_cx = (body_left + body_right) / 2

    def paint_records(
        draw: ImageDraw.ImageDraw,
        fill_back: tuple[int, int, int, int],
        fill_front: tuple[int, int, int, int],
        line_fill: tuple[int, int, int, int],
        chip_fill: tuple[int, int, int, int] | None = None,
    ) -> None:
        # Back card (offset up-left) — archive depth
        draw.rounded_rectangle(
            [
                card_x0 - stack_offset,
                card_y0 - stack_offset,
                card_x0 - stack_offset + card_w,
                card_y0 - stack_offset + card_h,
            ],
            radius=card_r,
            fill=fill_back,
        )
        # Front card — active electronic record
        draw.rounded_rectangle(
            [card_x0, card_y0, card_x0 + card_w, card_y1],
            radius=card_r,
            fill=fill_front,
        )
        # Record lines (data rows)
        line_h = u * 0.026
        line_x0 = card_x0 + card_w * 0.16
        line_x1 = card_x0 + card_w * 0.78
        for i, ratio in enumerate((0.30, 0.48, 0.66)):
            y = card_y0 + card_h * ratio
            x1 = line_x1 if i != 1 else line_x0 + (line_x1 - line_x0) * 0.58
            draw.rounded_rectangle(
                [line_x0, y, x1, y + line_h],
                radius=line_h / 2,
                fill=line_fill,
            )
        # Small IT chip / digital badge (top-right of front card)
        if chip_fill is not None:
            chip = u * 0.085
            pad = u * 0.06
            cx0 = card_x0 + card_w - pad - chip
            cy0 = card_y0 + pad
            draw.rounded_rectangle(
                [cx0, cy0, cx0 + chip, cy0 + chip],
                radius=chip * 0.22,
                fill=chip_fill,
            )
            # Tiny inner pixel — circuit/IT cue
            inset = chip * 0.28
            draw.rounded_rectangle(
                [cx0 + inset, cy0 + inset, cx0 + chip - inset, cy0 + chip - inset],
                radius=chip * 0.12,
                fill=fill_front,
            )

    def paint_facade(draw: ImageDraw.ImageDraw, fill: tuple[int, int, int, int]) -> None:
        draw.rounded_rectangle(
            [body_left, body_top, body_right, body_bot], radius=r, fill=fill
        )
        draw.rounded_rectangle(
            [tower_left, tower_top, tower_right, body_top + r * 2.5],
            radius=r,
            fill=fill,
        )
        draw.rectangle(
            [tower_left + 1, body_top - 2, tower_right - 1, body_top + r * 3],
            fill=fill,
        )

    # Shadows
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    paint_records(sd, (20, 74, 143, 22), (20, 74, 143, 28), (20, 74, 143, 0), None)
    paint_facade(sd, (20, 74, 143, 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(2, S // 260)))

    # Records — slightly lighter azure so hospital stays primary
    records = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    paint_records(
        ImageDraw.Draw(records),
        AZURE_600,
        AZURE_700,
        WHITE,
        WHITE,  # IT chip
    )

    # Hospital
    hospital = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    paint_facade(ImageDraw.Draw(hospital), AZURE_700)

    # Entrance
    entrance = Image.new("L", (S, S), 255)
    ed = ImageDraw.Draw(entrance)
    door_w = u * 0.11
    door_h = u * 0.13
    ed.rounded_rectangle(
        [
            hosp_cx - door_w / 2,
            body_bot - door_h,
            hosp_cx + door_w / 2,
            body_bot + 2,
        ],
        radius=door_w / 2,
        fill=0,
    )
    entrance = entrance.filter(ImageFilter.GaussianBlur(radius=max(1, S // 1800)))
    hospital.putalpha(ImageChops.multiply(hospital.getchannel("A"), entrance))

    # Medical cross
    cross = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cross)
    cross_cy = tower_top + (body_top - tower_top) * 0.48
    arm = u * 0.175
    thick = u * 0.055
    cd.rounded_rectangle(
        [
            hosp_cx - arm / 2,
            cross_cy - thick / 2,
            hosp_cx + arm / 2,
            cross_cy + thick / 2,
        ],
        radius=thick / 2,
        fill=WHITE,
    )
    cd.rounded_rectangle(
        [
            hosp_cx - thick / 2,
            cross_cy - arm / 2,
            hosp_cx + thick / 2,
            cross_cy + arm / 2,
        ],
        radius=thick / 2,
        fill=WHITE,
    )

    out = Image.alpha_composite(squircle, shadow)
    out = Image.alpha_composite(out, records)
    out = Image.alpha_composite(out, hospital)
    out = Image.alpha_composite(out, cross)

    down = out.resize((MASTER * 2, MASTER * 2), Image.Resampling.LANCZOS)
    down = down.resize((MASTER, MASTER), Image.Resampling.LANCZOS)
    return _fit_to_square(down, MASTER, fill=0.998)


def _scale(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _save_web_icon(
    logo: Image.Image, path: Path, size: int, *, maskable: bool
) -> None:
    if maskable:
        canvas = Image.new("RGBA", (size, size), AZURE_50)
        pad = int(size * 0.08)
        inner = size - pad * 2
        canvas.alpha_composite(_scale(logo, inner), (pad, pad))
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
    logo = _scale(master, 1024)

    for path, img in {
        OUT / "logo.png": logo,
        OUT / "favicon.png": logo.copy(),
        OUT / "splash.png": logo.copy(),
        WEB / "favicon.png": logo.copy(),
    }.items():
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path} size={img.size} bbox={img.getbbox()}")

    master.save(OUT / "logo_master.png", "PNG", optimize=True)
    print(f"wrote {OUT / 'logo_master.png'} size={master.size}")

    _save_web_icon(master, WEB_ICONS / "Icon-192.png", 192, maskable=False)
    _save_web_icon(master, WEB_ICONS / "Icon-512.png", 512, maskable=False)
    _save_web_icon(master, WEB_ICONS / "Icon-maskable-192.png", 192, maskable=True)
    _save_web_icon(master, WEB_ICONS / "Icon-maskable-512.png", 512, maskable=True)


if __name__ == "__main__":
    main()
