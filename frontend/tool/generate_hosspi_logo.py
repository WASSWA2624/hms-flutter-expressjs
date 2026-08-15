"""Import repo-root logo.png into transparent Flutter/web logo assets.

The source is cleaned before export: near-white plates are knocked out,
isolated dark specks are repaired, and the alpha edge is supersampled for a
smooth silhouette. Every generated asset uses transparent padding so the mark
works on light, dark, and custom theme surfaces.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

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


def _is_dark_spot(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    # Any near-black visible pixel reads as damage on a light theme, including
    # blue-tinted black produced by resampling a dark shadow.
    return a >= 16 and max(r, g, b) < 72


def _average_nearby_color(
    px: object,
    x: int,
    y: int,
    w: int,
    h: int,
    *,
    radius: int = 3,
) -> tuple[int, int, int] | None:
    colors: list[tuple[int, int, int]] = []
    for ny in range(max(0, y - radius), min(h, y + radius + 1)):
        for nx in range(max(0, x - radius), min(w, x + radius + 1)):
            candidate = px[nx, ny]
            if candidate[3] < 96 or _is_dark_spot(candidate):
                continue
            colors.append(candidate[:3])
    if not colors:
        return None
    count = len(colors)
    return tuple(sum(color[channel] for color in colors) // count for channel in range(3))


def _repair_dark_spots(img: Image.Image) -> Image.Image:
    """Remove isolated black specks without erasing deliberate 3D shading."""
    out = img.convert("RGBA")
    w, h = out.size
    px = out.load()
    dark = {
        (x, y)
        for y in range(h)
        for x in range(w)
        if _is_dark_spot(px[x, y])
    }
    repaired = 0

    while dark:
        seed = dark.pop()
        component = [seed]
        q: deque[tuple[int, int]] = deque([seed])
        while q:
            x, y = q.popleft()
            for ny in range(max(0, y - 1), min(h, y + 2)):
                for nx in range(max(0, x - 1), min(w, x + 2)):
                    neighbor = (nx, ny)
                    if neighbor in dark:
                        dark.remove(neighbor)
                        component.append(neighbor)
                        q.append(neighbor)

        center_x = sum(point[0] for point in component) / len(component)
        center_y = sum(point[1] for point in component) / len(component)
        is_book_detail = center_x >= w * 0.55 and center_y <= h * 0.58

        for x, y in component:
            _, _, _, alpha = px[x, y]
            if is_book_detail:
                # Keep page separation visible, but use warm ink instead of
                # harsh black pixels that look like raster damage.
                px[x, y] = (112, 82, 52, alpha)
            elif len(component) <= 32:
                replacement = _average_nearby_color(px, x, y, w, h)
                if replacement is not None:
                    px[x, y] = (*replacement, alpha)
            repaired += 1

    if repaired:
        print(f"repaired {repaired} dark pixels")
    return out


def _smooth_alpha_edges(img: Image.Image) -> Image.Image:
    """Supersample the alpha edge and extend clean RGB into the AA fringe."""
    out = img.convert("RGBA")
    w, h = out.size
    alpha = out.getchannel("A")

    aa = 4
    smooth_alpha = alpha.resize(
        (w * aa, h * aa),
        Image.Resampling.LANCZOS,
    ).filter(
        ImageFilter.GaussianBlur(radius=1.8),
    ).resize(
        (w, h),
        Image.Resampling.LANCZOS,
    ).point(lambda value: 0 if value < 5 else (255 if value > 250 else value))

    # The smoothed mask extends by a fraction of a pixel. Supply real logo
    # color there rather than transparent black, which otherwise creates a
    # dark halo on light themes.
    rgb = out.convert("RGB")
    expanded_rgb = Image.merge(
        "RGB",
        tuple(channel.filter(ImageFilter.MaxFilter(5)) for channel in rgb.split()),
    )
    edge_fill_mask = ImageChops.invert(alpha)
    clean_rgb = Image.composite(expanded_rgb, rgb, edge_fill_mask)

    result = Image.merge("RGBA", (*clean_rgb.split(), smooth_alpha))
    visible_mask = smooth_alpha.point(lambda value: 255 if value else 0)
    transparent_rgb = Image.new("RGB", (w, h), (0, 0, 0))
    normalized_rgb = Image.composite(clean_rgb, transparent_rgb, visible_mask)
    return Image.merge("RGBA", (*normalized_rgb.split(), smooth_alpha))


def _clean_logo(img: Image.Image) -> Image.Image:
    cleaned = _repair_dark_spots(_knockout_near_white_bg(img))
    return _repair_dark_spots(_smooth_alpha_edges(cleaned))


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


def _fit_natural(img: Image.Image, height: int) -> Image.Image:
    aspect = img.size[0] / img.size[1]
    w = max(1, int(round(height * aspect)))
    return img.resize((w, height), Image.Resampling.LANCZOS)


def _favicon(img: Image.Image, size: int = 1024) -> Image.Image:
    return _fit_square(img, size, pad_ratio=0.05)


def main() -> None:
    src_path = next((p for p in SRC_CANDIDATES if p.exists()), None)
    if src_path is None:
        raise SystemExit(
            f"Missing source logo. Place logo.png at {ROOT / 'logo.png'}."
        )

    cropped = _clean_logo(Image.open(src_path).convert("RGBA"))
    bbox = cropped.getbbox()
    if bbox:
        cropped = cropped.crop(bbox)

    cw, ch = cropped.size
    aspect = cw / ch
    print(f"source {src_path.name} content {cw}x{ch} aspect={aspect:.4f}")

    OUT.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)

    # Keep the repo-root source clean and transparent as well.
    cropped.save(ROOT / "logo.png", "PNG", optimize=True)

    # Bake the in-app mark at master resolution. AppLogo decodes via
    # device-pixel cacheWidth/cacheHeight so web/high-DPI stays sharp.
    master = _repair_dark_spots(_fit_natural(cropped, 2048))
    logo = master.copy()

    favicon = _repair_dark_spots(_favicon(cropped, 1024))

    # web/favicon.png is intentionally not written here: the browser tab mark
    # needs an opaque plate to survive dark tab strips, so it is baked by
    # tool/generate_platform_icons.py along with the Android launcher icons.
    for path, img in {
        OUT / "logo.png": logo,
        OUT / "favicon.png": favicon,
        OUT / "splash.png": logo.copy(),
        OUT / "logo_master.png": master,
    }.items():
        img.save(path, "PNG", optimize=True)
        print(f"wrote {path.name} {img.size}")

    for size in (192, 512):
        _repair_dark_spots(_fit_square(cropped, size, pad_ratio=0.05)).save(
            ICONS / f"Icon-{size}.png", "PNG", optimize=True
        )
        # Retain the legacy filenames, but keep them transparent too. They are
        # no longer declared as maskable because maskable icons require an
        # opaque plate and would violate the theme-neutral logo requirement.
        maskable = _repair_dark_spots(
            _fit_square(cropped, size, pad_ratio=0.12),
        )
        maskable.save(ICONS / f"Icon-maskable-{size}.png", "PNG", optimize=True)
        print(f"wrote Icon-{size}.png + transparent legacy icon")

    print(f"APP_LOGO_ASPECT={aspect:.4f}")


if __name__ == "__main__":
    main()
