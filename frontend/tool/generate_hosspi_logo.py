"""Import repo-root logo.png into Flutter web/app logo assets.

Source: <repo>/logo.png
Outputs: assets/logos/*, web/favicon.png, web/icons/*
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]  # repo root (hms/)
FRONTEND = Path(__file__).resolve().parents[1]
SRC = ROOT / "logo.png"
OUT = FRONTEND / "assets" / "logos"
WEB = FRONTEND / "web"
ICONS = WEB / "icons"


def _fit_square(img: Image.Image, size: int, pad_ratio: float = 0.03) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    max_side = int(size * (1 - 2 * pad_ratio))
    scale = min(max_side / img.size[0], max_side / img.size[1])
    nw = max(1, int(round(img.size[0] * scale)))
    nh = max(1, int(round(img.size[1] * scale)))
    scaled = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source logo: {SRC}")

    cropped = Image.open(SRC).convert("RGBA")
    bbox = cropped.getbbox()
    if bbox:
        cropped = cropped.crop(bbox)

    cw, ch = cropped.size
    print(f"source content {cw}x{ch} aspect={cw / ch:.3f}")

    OUT.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)

    logo_1024 = _fit_square(cropped, 1024)
    logo_2048 = _fit_square(cropped, 2048)

    for path, img in {
        OUT / "logo.png": logo_1024,
        OUT / "favicon.png": logo_1024.copy(),
        OUT / "splash.png": logo_1024.copy(),
        OUT / "logo_master.png": logo_2048,
        WEB / "favicon.png": logo_1024.copy(),
    }.items():
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path}")

    for size in (192, 512):
        _fit_square(cropped, size, pad_ratio=0.04).save(
            ICONS / f"Icon-{size}.png", "PNG", optimize=True
        )
        maskable = Image.new("RGBA", (size, size), (244, 249, 254, 255))
        pad = int(size * 0.10)
        inner = size - 2 * pad
        maskable.alpha_composite(_fit_square(cropped, inner, pad_ratio=0.02), (pad, pad))
        maskable.save(ICONS / f"Icon-maskable-{size}.png", "PNG", optimize=True)
        print(f"wrote Icon-{size}.png + maskable")


if __name__ == "__main__":
    main()
