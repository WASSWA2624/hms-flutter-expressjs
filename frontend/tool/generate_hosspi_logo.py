"""Import repo-root logo.png into Flutter web/app logo assets.

In-app logo keeps the natural aspect (no letterboxing) so AppLogo height
matches the visible artwork. Favicons/PWA icons stay square; favicons get
rounded corners with transparent outside.

Near-white baked plates are knocked out (edge flood-fill) so the in-app /
splash mark stays transparent on any theme background.
"""

from __future__ import annotations

from collections import deque
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


def _is_near_white_plate(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a < 8:
        return False
    if r < 220 or g < 220 or b < 220:
        return False
    return max(r, g, b) - min(r, g, b) <= 18


def _knockout_near_white_bg(img: Image.Image) -> Image.Image:
    """Clear connected near-white plate from edges; keep logo highlights."""
    out = img.convert("RGBA")
    w, h = out.size
    corners = (
        out.getpixel((0, 0)),
        out.getpixel((w - 1, 0)),
        out.getpixel((0, h - 1)),
        out.getpixel((w - 1, h - 1)),
    )
    if not any(_is_near_white_plate(c) for c in corners):
        return out

    px = out.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def try_seed(x: int, y: int) -> None:
        if visited[y][x]:
            return
        if _is_near_white_plate(px[x, y]):
            visited[y][x] = True
            q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        try_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                if _is_near_white_plate(px[nx, ny]):
                    visited[ny][nx] = True
                    q.append((nx, ny))

    # Soften light AA fringe next to cleared plate.
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            brightness = (r + g + b) / 3.0
            chroma = max(r, g, b) - min(r, g, b)
            if brightness < 200 or chroma > 40:
                continue
            if not any(
                0 <= nx < w
                and 0 <= ny < h
                and px[nx, ny][3] == 0
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            ):
                continue
            t = (brightness - 200) / 55.0
            px[x, y] = (r, g, b, int(max(0, min(255, 255 * (1 - t * 0.85)))))

    print("knocked out near-white background plate")
    return out


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

    cropped = _knockout_near_white_bg(Image.open(src_path).convert("RGBA"))
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
