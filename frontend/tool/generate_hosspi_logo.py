"""Import repo-root logo.png into Flutter web/app logo assets.

In-app logo keeps the natural aspect (no letterboxing) so AppLogo height
matches the visible artwork. Favicons/PWA icons stay square; favicons get
rounded corners with transparent outside.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FRONTEND = Path(__file__).resolve().parents[1]
SRC_CANDIDATES = (
    ROOT / "logo.png",
    FRONTEND / "assets" / "logos" / "logo_master.png",
    FRONTEND / "assets" / "logos" / "logo.png",
)
OUT = FRONTEND / "assets" / "logos"
WEB = FRONTEND / "web"
ICONS = WEB / "icons"

# ~iOS-app-icon corner roundness on the square favicon plate.
_FAVICON_RADIUS_RATIO = 0.22


def _fit_square(
    img: Image.Image,
    size: int,
    pad_ratio: float = 0.02,
    *,
    background: tuple[int, int, int, int] = (0, 0, 0, 0),
) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    max_side = int(size * (1 - 2 * pad_ratio))
    scale = min(max_side / img.size[0], max_side / img.size[1])
    nw = max(1, int(round(img.size[0] * scale)))
    nh = max(1, int(round(img.size[1] * scale)))
    scaled = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def _apply_rounded_corners(
    img: Image.Image,
    radius_ratio: float = _FAVICON_RADIUS_RATIO,
) -> Image.Image:
    """Clip to a rounded rect; corners become transparent (supersampled AA)."""
    w, h = img.size
    radius = max(1, int(round(min(w, h) * radius_ratio)))
    aa = 4
    mask = Image.new("L", (w * aa, h * aa), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, w * aa - 1, h * aa - 1),
        radius=radius * aa,
        fill=255,
    )
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)
    out = img.convert("RGBA")
    r, g, b, a = out.split()
    return Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, mask)))


_WHITE = (255, 255, 255, 255)


def _fit_natural(img: Image.Image, height: int) -> Image.Image:
    aspect = img.size[0] / img.size[1]
    w = max(1, int(round(height * aspect)))
    return img.resize((w, height), Image.Resampling.LANCZOS)


def _favicon(img: Image.Image, size: int = 1024) -> Image.Image:
    return _apply_rounded_corners(
        _fit_square(img, size, background=_WHITE),
    )


def main() -> None:
    src_path = next((p for p in SRC_CANDIDATES if p.exists()), None)
    if src_path is None:
        raise SystemExit(
            f"Missing source logo. Place logo.png at {ROOT / 'logo.png'}."
        )

    cropped = Image.open(src_path).convert("RGBA")
    bbox = cropped.getbbox()
    if bbox:
        cropped = cropped.crop(bbox)

    cw, ch = cropped.size
    aspect = cw / ch
    print(f"source {src_path.name} content {cw}x{ch} aspect={aspect:.4f}")

    OUT.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)

    # Bake the in-app mark at master resolution. AppLogo decodes via
    # device-pixel cacheWidth/cacheHeight so web/high-DPI stays sharp.
    master = _fit_natural(cropped, 2048)
    logo = master.copy()

    favicon = _favicon(cropped, 1024)

    for path, img in {
        OUT / "logo.png": logo,
        OUT / "favicon.png": favicon,
        OUT / "splash.png": logo.copy(),
        OUT / "logo_master.png": master,
        WEB / "favicon.png": favicon,
    }.items():
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path.name} {img.size}")

    for size in (192, 512):
        _fit_square(cropped, size, pad_ratio=0.03, background=_WHITE).save(
            ICONS / f"Icon-{size}.png", "PNG", optimize=True
        )
        maskable = Image.new("RGBA", (size, size), _WHITE)
        pad = int(size * 0.10)
        inner = size - 2 * pad
        maskable.alpha_composite(
            _fit_square(cropped, inner, pad_ratio=0.02), (pad, pad)
        )
        maskable.save(ICONS / f"Icon-maskable-{size}.png", "PNG", optimize=True)
        print(f"wrote Icon-{size}.png + maskable")

    print(f"APP_LOGO_ASPECT={aspect:.4f}")


if __name__ == "__main__":
    main()
