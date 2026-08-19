"""Generate the opaque platform icons from the cleaned transparent logo.

Two surfaces need a baked background plate; every other icon in the repo stays
transparent and is produced by ``generate_hosspi_logo.py``:

* ``web/favicon.png`` - the browser tab mark. Tab strips paint their own
  chrome (often dark), so the transparent wordmark disappears there. Only this
  file gets the plate; ``web/icons/*`` (PWA / apple-touch) stay transparent.
* ``android/app/src/main/res/mipmap-*`` - the installed launcher icon. Android
  composites the icon over the user's wallpaper and masks it to the device
  shape, so both the legacy bitmap and the adaptive foreground are baked here.

Run with: python tool/generate_platform_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

FRONTEND = Path(__file__).resolve().parents[1]
SRC = FRONTEND / "assets" / "logos" / "logo.png"
WEB = FRONTEND / "web"
ANDROID_RES = FRONTEND / "android" / "app" / "src" / "main" / "res"

PLATE = (255, 255, 255, 255)

# Browser tabs render the favicon at 16-32 px; 256 keeps retina taps sharp
# without shipping a large file.
FAVICON_SIZE = 256
# Rounded plate reads as an app tile rather than a pasted-on white square, and
# the inset keeps the wordmark off the corners.
FAVICON_CORNER_RATIO = 0.22
FAVICON_CONTENT_RATIO = 0.68

# Legacy square launcher bitmap (pre-API 26 and Play Store fallbacks).
LEGACY_LAUNCHER_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive foreground canvas is 108dp; only the inner 66dp is guaranteed
# visible after the launcher applies its mask.
ADAPTIVE_FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
ADAPTIVE_SAFE_ZONE = 66 / 108

ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

LAUNCHER_BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Plate behind the adaptive launcher icon. The logo mark is drawn in
         brand blue/red, so it needs a light plate to stay legible over any
         wallpaper. -->
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""


def _fit_square(
    logo: Image.Image,
    size: int,
    *,
    content_ratio: float,
    background: tuple[int, int, int, int],
) -> Image.Image:
    """Center [logo] on a [size] square, scaled to fill [content_ratio] of it."""
    canvas = Image.new("RGBA", (size, size), background)
    max_side = max(1, int(round(size * content_ratio)))
    scale = min(max_side / logo.size[0], max_side / logo.size[1])
    width = max(1, int(round(logo.size[0] * scale)))
    height = max(1, int(round(logo.size[1] * scale)))
    scaled = logo.resize((width, height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled, ((size - width) // 2, (size - height) // 2))
    return canvas


def _rounded_plate(size: int, corner_ratio: float) -> Image.Image:
    """Opaque plate with rounded corners, supersampled for a clean edge."""
    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1),
        radius=int(round(size * scale * corner_ratio)),
        fill=255,
    )
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    plate = Image.new("RGBA", (size, size), PLATE)
    plate.putalpha(mask)
    return plate


def _write(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(FRONTEND)} {image.size}")


def main() -> None:
    if not SRC.exists():
        raise SystemExit(
            f"Missing {SRC}. Run tool/generate_hosspi_logo.py first."
        )

    logo = Image.open(SRC).convert("RGBA")
    bbox = logo.getbbox()
    if bbox:
        logo = logo.crop(bbox)
    print(f"source {SRC.name} content {logo.size[0]}x{logo.size[1]}")

    # Web tab favicon: rounded white plate so the mark reads on dark tab strips.
    favicon = _rounded_plate(FAVICON_SIZE, FAVICON_CORNER_RATIO)
    favicon.alpha_composite(
        _fit_square(
            logo,
            FAVICON_SIZE,
            content_ratio=FAVICON_CONTENT_RATIO,
            background=(0, 0, 0, 0),
        ),
    )
    _write(WEB / "favicon.png", favicon)

    # Legacy launcher bitmap: full-bleed plate, launcher applies its own mask.
    for directory, size in LEGACY_LAUNCHER_SIZES.items():
        _write(
            ANDROID_RES / directory / "ic_launcher.png",
            _fit_square(logo, size, content_ratio=0.84, background=PLATE),
        )

    # Adaptive foreground: transparent, mark kept inside the 66dp safe zone.
    for directory, size in ADAPTIVE_FOREGROUND_SIZES.items():
        _write(
            ANDROID_RES / directory / "ic_launcher_foreground.png",
            _fit_square(
                logo,
                size,
                content_ratio=ADAPTIVE_SAFE_ZONE * 0.92,
                background=(0, 0, 0, 0),
            ),
        )

    adaptive_xml = ANDROID_RES / "mipmap-anydpi-v26" / "ic_launcher.xml"
    adaptive_xml.parent.mkdir(parents=True, exist_ok=True)
    adaptive_xml.write_text(ADAPTIVE_ICON_XML, encoding="utf-8")
    print(f"wrote {adaptive_xml.relative_to(FRONTEND)}")

    background_xml = ANDROID_RES / "values" / "ic_launcher_background.xml"
    background_xml.parent.mkdir(parents=True, exist_ok=True)
    background_xml.write_text(LAUNCHER_BACKGROUND_XML, encoding="utf-8")
    print(f"wrote {background_xml.relative_to(FRONTEND)}")


if __name__ == "__main__":
    main()
