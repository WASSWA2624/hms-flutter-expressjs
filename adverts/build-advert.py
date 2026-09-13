#!/usr/bin/env python3
"""
Build the HOSSPI WhatsApp adverts.

    python adverts/build-advert.py

Renders one design at two sizes - a 1080x1080 square for chats, groups and
broadcast lists, and a 1080x1920 portrait for WhatsApp Status and stories -
once for every contact number in PHONES.

The advert reads the product rather than restating it. The palette is the
website's theme, the logo is website/public/logos/icon-512.png, and the icons
are lifted out of website/src/components/ui/Icon.js at build time, so the
glyphs on the advert are the glyphs on the site. Every capability named here is
one users can reach in the current release - the same accuracy rule as
website/src/lib/product.js.

Type is set in Segoe UI with Pillow; the SVG icons are rasterised by PyMuPDF.
The canvas is drawn at SUPERSAMPLE times the final size and scaled down, which
anti-aliases the shapes as well as the type.

Layout is measured, never guessed, and evenly spaced. Every block reports its
height from the real font metrics, and the height left over becomes a single
gap: above the header, between every section and above the call-to-action bar.
No text is placed at a hand-tuned offset, which is how labels used to end up
sitting on the edges of their tiles.

Needs Pillow and PyMuPDF:  python -m pip install pillow pymupdf
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

try:
    import fitz  # PyMuPDF
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:  # an environment problem, not a bug
    raise SystemExit(f"missing {exc.name} - run: python -m pip install pillow pymupdf")

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
ICON_SOURCE = REPO / "website" / "src" / "components" / "ui" / "Icon.js"
LOGO = REPO / "website" / "public" / "logos" / "icon-512.png"

SUPERSAMPLE = 3

# --- brand -------------------------------------------------------------------
# The website's own tokens (website/src/styles/theme.js).
INK = "#0D2744"
INK_DEEP = "#081A2E"
PRIMARY = "#0079FD"
PRIMARY_DEEP = "#0267D9"
PRIMARY_LIGHT = "#52A4FE"
AZURE_SOFT = "#AECBFF"
MUTED = "#9FC0E8"
BAR_TEXT = "#D6E7FF"
WHITE = "#FFFFFF"

FONT_FILES = {
    "regular": "segoeui.ttf",
    "semibold": "seguisb.ttf",
    "bold": "segoeuib.ttf",
}

# --- content -----------------------------------------------------------------
# Only what users can reach in the current release. Check a claim against the
# app before adding it here.
NAME = "HOSSPI"
EYEBROW = "HOSPITAL MANAGEMENT SYSTEM"
BADGE = "AI-assisted"

# Headline lines as (text, accent) runs; accent runs are set in the light blue.
HEADLINE = (
    (("Run the whole hospital", False),),
    (("from ", False), ("one system.", True)),
)

# Short titles and one-line details: at phone-readable sizes the square has
# room for about 34 characters of detail per card.
FEATURES = (
    ("sparkle", "AI assistance", "Polishes notes, reads drug packs"),
    ("mic", "Speech to text", "Dictate notes, dates and amounts"),
    ("monitor", "Every platform", "Web, Android, iOS, desktop, Linux"),
    ("settings", "Made to fit", "Your roles, prices and defaults"),
    ("stethoscope", "Clinical care", "Outpatient, wards, ICU, theatre"),
    ("flask", "Diagnostics", "Lab, imaging and pharmacy"),
    ("receipt", "Finance", "Billing, claims and ledgers"),
    ("building", "Built for groups", "Many facilities, one organisation"),
)
HIGHLIGHTED = {"sparkle", "mic"}

PLATFORMS_HEADING = "RUNS ON EVERY DEVICE"
PLATFORMS = (
    ("globe", "Web", "Any browser"),
    ("smartphone", "Android", "Phones, tablets"),
    ("tablet", "iOS", "iPhone, iPad"),
    ("monitor", "Desktop", "Windows, macOS"),
    ("terminal", "Linux", "Native app"),
)

DEPARTMENTS_HEADING = "26 DEPARTMENTS, INCLUDING"
DEPARTMENTS = (
    "Reception", "Emergency", "Outpatient", "Wards", "ICU", "Theatre",
    "Laboratory", "Radiology", "Pharmacy", "Billing", "Insurance", "Mortuary",
)

CTA = "Book a demo"
SITE = "www.hosspi.com"
# One square and one portrait per number. The first keeps the plain file names;
# the rest add the number in local form, e.g. hosspi-whatsapp-advert-0709932926.png.
PHONES = ("+256 783 230 321", "+256 709 932 926")
PHONE_NOTE = "WHATSAPP OR CALL"

# Glyphs the website's set does not have yet, drawn on the same 24px grid with
# the same 1.7 stroke so they sit with the rest.
EXTRA_ICONS = {
    "mic": (
        '<rect x="9" y="2.5" width="6" height="11.5" rx="3"/>'
        '<path d="M5.5 11a6.5 6.5 0 0 0 13 0"/>'
        '<path d="M12 17.5v4"/>'
        '<path d="M8.5 21.5h7"/>'
    ),
}


# --- canvases ----------------------------------------------------------------

@dataclass(frozen=True)
class Spec:
    """Every size on one canvas, in final-image pixels."""

    file: str
    width: int
    height: int
    margin: float
    # the build fails rather than set sections closer together than this
    min_gap: float
    # brand lockup
    logo: float
    name: float
    eyebrow: float
    badge: float
    # headline
    headline: float
    leading: float
    # feature cards
    card_title: float
    card_detail: float
    card_pad: float
    card_badge: float
    card_icon: float
    card_gap: float
    radius: float
    # call to action bar
    bar: float
    cta: float
    site: float
    phone: float
    phone_note: float
    # portrait-only sections
    platforms: bool = False
    departments: bool = False
    section: float = 0
    section_gap: float = 0
    platform_icon: float = 0
    platform_name: float = 0
    platform_detail: float = 0
    platform_pad: float = 0
    chip: float = 0
    chip_gap: float = 0


SQUARE = Spec(
    file="hosspi-whatsapp-advert.png", width=1080, height=1080,
    margin=60, min_gap=30,
    logo=92, name=50, eyebrow=16, badge=20,
    headline=70, leading=1.12,
    card_title=27, card_detail=22, card_pad=20, card_badge=60, card_icon=30,
    card_gap=14, radius=20,
    bar=160, cta=40, site=24, phone=40, phone_note=16,
)

PORTRAIT = Spec(
    file="hosspi-whatsapp-status.png", width=1080, height=1920,
    margin=64, min_gap=36,
    logo=116, name=62, eyebrow=19, badge=23,
    headline=82, leading=1.1,
    card_title=31, card_detail=25, card_pad=26, card_badge=72, card_icon=36,
    card_gap=18, radius=24,
    bar=240, cta=50, site=30, phone=48, phone_note=19,
    platforms=True, departments=True,
    section=20, section_gap=22,
    platform_icon=50, platform_name=26, platform_detail=20, platform_pad=30,
    chip=23, chip_gap=14,
)


# --- fonts and measurement ---------------------------------------------------

def font_dirs() -> "list[Path]":
    configured = os.environ.get("HOSSPI_FONT_DIR")
    if configured:
        return [Path(configured)]
    windows = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    user = Path(os.environ.get("LOCALAPPDATA", "~")).expanduser() / "Microsoft" / "Windows" / "Fonts"
    return [windows, user]


@lru_cache(maxsize=None)
def font_path(weight: str) -> str:
    name = FONT_FILES[weight]
    for folder in font_dirs():
        candidate = folder / name
        if candidate.is_file():
            return str(candidate)
    raise SystemExit(
        f"Segoe UI ({name}) not found. The advert is set in the website's typeface; "
        "set HOSSPI_FONT_DIR to a folder holding " + ", ".join(FONT_FILES.values())
    )


@lru_cache(maxsize=None)
def font(weight: str, size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path(weight), max(1, round(size * SUPERSAMPLE)))


@lru_cache(maxsize=None)
def ascent(weight: str, size: float) -> float:
    """Baseline to the top of capitals and ascenders, in final pixels."""
    return -font(weight, size).getbbox("Hbdfhkl", anchor="ls")[1] / SUPERSAMPLE


@lru_cache(maxsize=None)
def descent(weight: str, size: float) -> float:
    """Baseline to the bottom of descenders, in final pixels."""
    return font(weight, size).getbbox("gjpqy", anchor="ls")[3] / SUPERSAMPLE


def measure(text: str, weight: str, size: float, tracking: float = 0.0) -> float:
    face = font(weight, size)
    if not tracking:
        return face.getlength(text) / SUPERSAMPLE
    advance = sum(face.getlength(char) for char in text)
    return (advance + tracking * SUPERSAMPLE * (len(text) - 1)) / SUPERSAMPLE


def wrap(text: str, weight: str, size: float, width: float) -> "list[str]":
    lines: "list[str]" = []
    current = ""
    for word in text.split():
        trial = f"{current} {word}" if current else word
        if current and measure(trial, weight, size) > width:
            lines.append(current)
            current = word
        else:
            current = trial
    if current:
        lines.append(current)
    # No lone word on the last line: pull one down from the line above when it
    # still fits, so a two-line detail reads as a pair rather than an orphan.
    if len(lines) >= 2 and " " not in lines[-1]:
        head, _, tail = lines[-2].rpartition(" ")
        if " " in head and measure(f"{tail} {lines[-1]}", weight, size) <= width:
            lines[-2:] = [head, f"{tail} {lines[-1]}"]
    return lines


def rgba(color: str, alpha: float = 1.0) -> "tuple[int, int, int, int]":
    value = color.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), round(alpha * 255))


# --- icons -------------------------------------------------------------------

ICONS: "dict[str, str]" = {}


def load_icons(names) -> None:
    """
    Pull icon geometry straight out of the website's icon set.

    A plain string search rather than a JSX parser: each icon is a
    `  name: (` block of fragment-wrapped SVG elements closed by `  ),`.
    """
    source = ICON_SOURCE.read_text(encoding="utf-8")
    for name in names:
        if name in ICONS:
            continue
        if name in EXTRA_ICONS:
            ICONS[name] = EXTRA_ICONS[name]
            continue
        opener = f"\n  {name}: (\n"
        start = source.find(opener)
        if start < 0:
            raise SystemExit(f'icon "{name}" not found in {ICON_SOURCE}')
        body_start = start + len(opener)
        end = source.find("\n  ),", body_start)
        if end < 0:
            raise SystemExit(f'icon "{name}" is not terminated in {ICON_SOURCE}')
        body = " ".join(source[body_start:end].replace("<>", "").replace("</>", "").split())
        # JSX spells some SVG attributes in camelCase. None of the icons use one
        # today; if that changes, stop rather than draw a broken glyph.
        if re.search(r"\s(?:className|stroke[A-Z]\w*|fill[A-Z]\w*|clip[A-Z]\w*)=", body):
            raise SystemExit(f'icon "{name}" uses a JSX-only attribute; teach load_icons it')
        ICONS[name] = body


@lru_cache(maxsize=None)
def icon_image(name: str, size: int, color: str, stroke: float) -> Image.Image:
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 24 24"><g fill="none" stroke="{color}" stroke-width="{stroke}" '
        f'stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</g></svg>'
    )
    with fitz.open(stream=svg.encode("utf-8"), filetype="svg") as doc:
        pixmap = doc[0].get_pixmap(alpha=True)
        # MuPDF hands back premultiplied alpha; RGBa -> RGBA undoes it.
        image = Image.frombytes("RGBa", (pixmap.width, pixmap.height), pixmap.samples)
    image = image.convert("RGBA")
    if image.size != (size, size):
        image = image.resize((size, size), Image.LANCZOS)
    return image


# --- drawing -----------------------------------------------------------------

class Canvas:
    """
    A supersampled surface, addressed in final-image pixels.

    RGB, not RGBA, on purpose: Pillow only alpha-blends a translucent fill or
    text colour when an RGBA drawing context sits on an RGB image. On an RGBA
    image it writes the colour's alpha into the pixels instead, and every
    translucent card comes out solid once the alpha channel is dropped. RGBA
    layers - icons, the logo, glows - are pasted through their own alpha.
    """

    def __init__(self, width: int, height: int):
        self.width, self.height = width, height
        self.image = Image.new("RGB", (width * SUPERSAMPLE, height * SUPERSAMPLE), rgba(INK)[:3])
        self.draw = ImageDraw.Draw(self.image, "RGBA")

    @staticmethod
    def px(value: float) -> int:
        return round(value * SUPERSAMPLE)

    def box(self, x0: float, y0: float, x1: float, y1: float) -> "list[int]":
        return [self.px(x0), self.px(y0), self.px(x1), self.px(y1)]

    def composite(self, layer: Image.Image, left: int, top: int) -> None:
        """Blend an RGBA layer over the canvas, tolerating a layer hanging off it."""
        x0, y0 = max(left, 0), max(top, 0)
        x1 = min(left + layer.width, self.image.width)
        y1 = min(top + layer.height, self.image.height)
        if x1 > x0 and y1 > y0:
            piece = layer.crop((x0 - left, y0 - top, x1 - left, y1 - top))
            self.image.paste(piece, (x0, y0), piece)

    # -- fills --

    def vertical_gradient(self, top: str, bottom: str) -> None:
        ramp = Image.linear_gradient("L").resize(self.image.size, Image.BILINEAR)
        start = Image.new("RGB", self.image.size, rgba(top)[:3])
        end = Image.new("RGB", self.image.size, rgba(bottom)[:3])
        self.image = Image.composite(end, start, ramp)
        self.draw = ImageDraw.Draw(self.image, "RGBA")

    def glow(self, cx: float, cy: float, radius: float, color: str, strength: float) -> None:
        size = self.px(radius * 2)
        falloff = Image.radial_gradient("L").resize((size, size), Image.BILINEAR)
        alpha = falloff.point(lambda v: int(round(strength * 255 * max(0.0, 1 - v / 255) ** 2)))
        layer = Image.new("RGBA", (size, size), rgba(color))
        layer.putalpha(alpha)
        self.composite(layer, self.px(cx - radius), self.px(cy - radius))

    def band(self, y0: float, y1: float, left: str, right: str) -> None:
        top = self.px(y0)
        size = (self.image.width, self.px(y1) - top)
        ramp = Image.linear_gradient("L").transpose(Image.Transpose.ROTATE_90).resize(size, Image.BILINEAR)
        strip = Image.composite(Image.new("RGB", size, rgba(right)[:3]),
                                Image.new("RGB", size, rgba(left)[:3]), ramp)
        self.image.paste(strip, (0, top))

    def rounded(self, x0: float, y0: float, x1: float, y1: float, radius: float,
                fill=None, outline=None, width: float = 1.0) -> None:
        self.draw.rounded_rectangle(
            self.box(x0, y0, x1, y1), radius=self.px(radius), fill=fill,
            outline=outline, width=max(1, self.px(width)),
        )

    # -- type and pictures --

    def text(self, x: float, baseline: float, text: str, weight: str, size: float,
             color, tracking: float = 0.0, anchor: str = "ls") -> None:
        face = font(weight, size)
        if not tracking:
            self.draw.text((self.px(x), self.px(baseline)), text, font=face, fill=color, anchor=anchor)
            return
        if anchor != "ls":
            raise ValueError("tracked text is left-aligned on its baseline only")
        cursor = float(self.px(x))
        for char in text:
            self.draw.text((cursor, self.px(baseline)), char, font=face, fill=color, anchor="ls")
            cursor += face.getlength(char) + tracking * SUPERSAMPLE

    def icon(self, name: str, x: float, y: float, size: float, color: str, stroke: float = 1.7) -> None:
        self.composite(icon_image(name, self.px(size), color, stroke), self.px(x), self.px(y))

    def picture(self, image: Image.Image, x: float, y: float, size: float) -> None:
        scaled = image.resize((self.px(size), self.px(size)), Image.LANCZOS)
        self.composite(scaled, self.px(x), self.px(y))


# --- blocks ------------------------------------------------------------------
# Each block returns (name, height, draw). draw(y) paints it with its top at y.

def header_block(c: Canvas, spec: Spec, x0: float, x1: float, logo: Image.Image):
    """Logo and name side by side, with the AI badge at the right edge."""
    name_cap = ascent("bold", spec.name)
    eyebrow_cap = ascent("semibold", spec.eyebrow)
    eyebrow_gap = spec.name * 0.3
    stack = name_cap + eyebrow_gap + eyebrow_cap
    height = max(spec.logo, stack)

    pill_h = spec.badge * 2.3
    pill_icon = spec.badge * 1.15
    pill_pad = spec.badge * 0.95
    pill_w = pill_pad + pill_icon + spec.badge * 0.45 + measure(BADGE, "semibold", spec.badge) + pill_pad

    text_x = x0 + spec.logo + spec.logo * 0.22
    tracking = spec.eyebrow * 0.2
    lockup_right = text_x + max(measure(NAME, "bold", spec.name),
                                measure(EYEBROW, "semibold", spec.eyebrow, tracking))
    if lockup_right + spec.badge > x1 - pill_w:
        raise SystemExit(f"{spec.file}: the brand lockup runs into the AI badge")

    def draw(y: float) -> None:
        c.picture(logo, x0, y + (height - spec.logo) / 2, spec.logo)
        top = y + (height - stack) / 2
        c.text(text_x, top + name_cap, NAME, "bold", spec.name, rgba(WHITE))
        c.text(text_x, top + name_cap + eyebrow_gap + eyebrow_cap, EYEBROW, "semibold",
               spec.eyebrow, rgba(PRIMARY_LIGHT), tracking=tracking)

        px0, py0 = x1 - pill_w, y + (height - pill_h) / 2
        c.rounded(px0, py0, x1, py0 + pill_h, pill_h / 2,
                  fill=rgba(PRIMARY, 0.18), outline=rgba(PRIMARY_LIGHT, 0.6), width=1.4)
        c.icon("sparkle", px0 + pill_pad, py0 + (pill_h - pill_icon) / 2, pill_icon, AZURE_SOFT, 1.9)
        cap = ascent("semibold", spec.badge)
        c.text(px0 + pill_pad + pill_icon + spec.badge * 0.45, py0 + (pill_h + cap) / 2,
               BADGE, "semibold", spec.badge, rgba(WHITE))

    return "header", height, draw


def headline_block(c: Canvas, spec: Spec, x0: float, x1: float):
    size = spec.headline
    cap, desc = ascent("bold", size), descent("bold", size)
    step = size * spec.leading
    for line in HEADLINE:
        width = sum(measure(text, "bold", size) for text, _ in line)
        if width > x1 - x0:
            raise SystemExit(f"{spec.file}: headline line is {width:.0f}px, the column is {x1 - x0:.0f}px")
    height = cap + step * (len(HEADLINE) - 1) + desc

    def draw(y: float) -> None:
        for index, line in enumerate(HEADLINE):
            x = x0
            for text, accent in line:
                c.text(x, y + cap + index * step, text, "bold", size,
                       rgba(PRIMARY_LIGHT if accent else WHITE))
                x += measure(text, "bold", size)

    return "headline", height, draw


def features_block(c: Canvas, spec: Spec, x0: float, x1: float):
    """Two columns of cards: icon badge on the left, title and detail beside it."""
    columns = 2
    card_w = (x1 - x0 - spec.card_gap) / columns
    text_offset = spec.card_pad + spec.card_badge + spec.card_pad * 0.9
    text_w = card_w - text_offset - spec.card_pad

    t_cap, t_desc = ascent("semibold", spec.card_title), descent("semibold", spec.card_title)
    d_cap, d_desc = ascent("regular", spec.card_detail), descent("regular", spec.card_detail)
    t_step, d_step = spec.card_title * 1.22, spec.card_detail * 1.38
    title_gap = spec.card_detail * 0.6  # title descender to detail capitals

    laid = []
    for glyph, title, detail in FEATURES:
        titles = wrap(title, "semibold", spec.card_title, text_w)
        details = wrap(detail, "regular", spec.card_detail, text_w)
        title_h = t_cap + t_step * (len(titles) - 1) + t_desc
        text_h = title_h + title_gap + d_cap + d_step * (len(details) - 1) + d_desc
        laid.append((glyph, titles, details, title_h, text_h))

    rows = [laid[i:i + columns] for i in range(0, len(laid), columns)]
    row_heights = [spec.card_pad * 2 + max(spec.card_badge, *(item[4] for item in row)) for row in rows]
    height = sum(row_heights) + spec.card_gap * (len(rows) - 1)

    def draw(y: float) -> None:
        top = y
        for row, row_h in zip(rows, row_heights):
            for column, (glyph, titles, details, title_h, text_h) in enumerate(row):
                left = x0 + column * (card_w + spec.card_gap)
                lit = glyph in HIGHLIGHTED
                c.rounded(left, top, left + card_w, top + row_h, spec.radius,
                          fill=rgba(PRIMARY, 0.15) if lit else rgba(WHITE, 0.055),
                          outline=rgba(PRIMARY_LIGHT, 0.55) if lit else rgba(WHITE, 0.1),
                          width=1.3)

                badge_x = left + spec.card_pad
                badge_y = top + (row_h - spec.card_badge) / 2
                c.rounded(badge_x, badge_y, badge_x + spec.card_badge, badge_y + spec.card_badge,
                          spec.card_badge * 0.3, fill=rgba(PRIMARY, 0.95 if lit else 0.22))
                inset = (spec.card_badge - spec.card_icon) / 2
                c.icon(glyph, badge_x + inset, badge_y + inset, spec.card_icon,
                       WHITE if lit else AZURE_SOFT, 1.8)

                text_x = left + text_offset
                text_y = top + (row_h - text_h) / 2
                for index, line in enumerate(titles):
                    c.text(text_x, text_y + t_cap + index * t_step, line, "semibold",
                           spec.card_title, rgba(WHITE))
                detail_top = text_y + title_h + title_gap
                for index, line in enumerate(details):
                    c.text(text_x, detail_top + d_cap + index * d_step, line, "regular",
                           spec.card_detail, rgba(MUTED))
            top += row_h + spec.card_gap

    return "features", height, draw


def section_heading(c: Canvas, spec: Spec, x: float, y: float, text: str) -> None:
    c.text(x, y + ascent("semibold", spec.section), text, "semibold", spec.section,
           rgba(PRIMARY_LIGHT), tracking=spec.section * 0.18)


def section_heading_height(spec: Spec) -> float:
    return ascent("semibold", spec.section) + spec.section_gap


def platforms_block(c: Canvas, spec: Spec, x0: float, x1: float):
    """One panel, one column per platform: icon, then name, then detail."""
    column_w = (x1 - x0) / len(PLATFORMS)
    n_cap, n_desc = ascent("semibold", spec.platform_name), descent("semibold", spec.platform_name)
    d_cap, d_desc = ascent("regular", spec.platform_detail), descent("regular", spec.platform_detail)
    icon_gap = spec.platform_name * 0.75   # icon foot to name capitals
    name_gap = spec.platform_detail * 0.5  # name descender to detail capitals

    for _, name, detail in PLATFORMS:
        widest = max(measure(name, "semibold", spec.platform_name),
                     measure(detail, "regular", spec.platform_detail))
        if widest > column_w - spec.platform_detail:
            raise SystemExit(f"{spec.file}: platform label '{detail}' is too wide for its column")

    item_h = spec.platform_icon + icon_gap + n_cap + n_desc + name_gap + d_cap + d_desc
    panel_h = spec.platform_pad * 2 + item_h
    heading_h = section_heading_height(spec)
    height = heading_h + panel_h

    def draw(y: float) -> None:
        section_heading(c, spec, x0, y, PLATFORMS_HEADING)
        top = y + heading_h
        c.rounded(x0, top, x1, top + panel_h, spec.radius,
                  fill=rgba(WHITE, 0.045), outline=rgba(WHITE, 0.09), width=1.3)
        for index, (glyph, name, detail) in enumerate(PLATFORMS):
            centre = x0 + column_w * (index + 0.5)
            icon_y = top + spec.platform_pad
            c.icon(glyph, centre - spec.platform_icon / 2, icon_y, spec.platform_icon, AZURE_SOFT)
            name_base = icon_y + spec.platform_icon + icon_gap + n_cap
            c.text(centre, name_base, name, "semibold", spec.platform_name, rgba(WHITE), anchor="ms")
            detail_base = name_base + n_desc + name_gap + d_cap
            c.text(centre, detail_base, detail, "regular", spec.platform_detail, rgba(MUTED), anchor="ms")
            if index:
                divider_x = x0 + column_w * index
                c.draw.line(
                    [(c.px(divider_x), c.px(top + spec.platform_pad)),
                     (c.px(divider_x), c.px(top + panel_h - spec.platform_pad))],
                    fill=rgba(WHITE, 0.08), width=c.px(1),
                )

    return "platforms", height, draw


def departments_block(c: Canvas, spec: Spec, x0: float, x1: float):
    """Department chips, wrapped left to right."""
    size = spec.chip
    cap = ascent("semibold", size)
    pad_x, pad_y = size * 0.85, size * 0.72
    chip_h = cap + pad_y * 2

    rows: "list[list[tuple[str, float]]]" = [[]]
    row_w = 0.0
    for department in DEPARTMENTS:
        chip_w = measure(department, "semibold", size) + pad_x * 2
        needed = chip_w if not rows[-1] else row_w + spec.chip_gap + chip_w
        if rows[-1] and needed > x1 - x0:
            rows.append([])
            needed = chip_w
        rows[-1].append((department, chip_w))
        row_w = needed

    heading_h = section_heading_height(spec)
    height = heading_h + len(rows) * chip_h + (len(rows) - 1) * spec.chip_gap

    def draw(y: float) -> None:
        section_heading(c, spec, x0, y, DEPARTMENTS_HEADING)
        top = y + heading_h
        for row in rows:
            x = x0
            for department, chip_w in row:
                c.rounded(x, top, x + chip_w, top + chip_h, chip_h / 2,
                          fill=rgba(WHITE, 0.06), outline=rgba(PRIMARY_LIGHT, 0.28), width=1.2)
                c.text(x + pad_x, top + pad_y + cap, department, "semibold", size, rgba(AZURE_SOFT))
                x += chip_w + spec.chip_gap
            top += chip_h + spec.chip_gap

    return "departments", height, draw


def paint_background(c: Canvas, spec: Spec) -> None:
    c.vertical_gradient(INK, INK_DEEP)
    c.glow(spec.width * 0.08, spec.height * 0.02, spec.width * 0.8, PRIMARY, 0.32)
    c.glow(spec.width * 1.02, spec.height * 0.62, spec.width * 0.62, PRIMARY_LIGHT, 0.10)


def paint_bar(c: Canvas, spec: Spec, phone: str) -> None:
    """Call to action across the foot: the ask on the left, the number on the right."""
    top = spec.height - spec.bar
    x0, x1 = spec.margin, spec.width - spec.margin
    c.band(top, spec.height, PRIMARY, PRIMARY_DEEP)
    c.draw.rectangle(c.box(0, top, spec.width, top + 1.5), fill=rgba(WHITE, 0.3))

    cta_cap = ascent("bold", spec.cta)
    site_cap = ascent("semibold", spec.site)
    site_gap = spec.site * 0.8
    left_stack = cta_cap + site_gap + site_cap
    left_top = top + (spec.bar - left_stack) / 2
    c.text(x0, left_top + cta_cap, CTA, "bold", spec.cta, rgba(WHITE))
    site_base = left_top + cta_cap + site_gap + site_cap
    globe = site_cap * 1.25
    c.icon("globe", x0, site_base - site_cap / 2 - globe / 2, globe, BAR_TEXT, 2.0)
    c.text(x0 + globe * 1.4, site_base, SITE, "semibold", spec.site, rgba(BAR_TEXT))
    left_right = x0 + max(measure(CTA, "bold", spec.cta),
                          globe * 1.4 + measure(SITE, "semibold", spec.site))

    note_tracking = spec.phone_note * 0.16
    note_cap = ascent("semibold", spec.phone_note)
    phone_cap = ascent("bold", spec.phone)
    phone_gap = spec.phone * 0.42
    right_stack = note_cap + phone_gap + phone_cap
    right_top = top + (spec.bar - right_stack) / 2
    text_w = max(measure(phone, "bold", spec.phone),
                 measure(PHONE_NOTE, "semibold", spec.phone_note, note_tracking))
    text_x = x1 - text_w
    circle = right_stack * 1.08
    circle_x = text_x - spec.phone * 0.45 - circle
    circle_y = right_top + (right_stack - circle) / 2
    if left_right + spec.phone * 0.6 > circle_x:
        raise SystemExit(f"{spec.file}: the call to action and the phone number collide")

    c.draw.ellipse(c.box(circle_x, circle_y, circle_x + circle, circle_y + circle), fill=rgba(WHITE))
    glyph = circle * 0.5
    c.icon("message", circle_x + (circle - glyph) / 2, circle_y + (circle - glyph) / 2,
           glyph, PRIMARY, 2.1)
    c.text(text_x, right_top + note_cap, PHONE_NOTE, "semibold", spec.phone_note,
           rgba(BAR_TEXT), tracking=note_tracking)
    c.text(text_x, right_top + note_cap + phone_gap + phone_cap, phone, "bold",
           spec.phone, rgba(WHITE))


# --- compose -----------------------------------------------------------------

def compose(spec: Spec, logo: Image.Image, phone: str) -> Image.Image:
    c = Canvas(spec.width, spec.height)
    paint_background(c, spec)

    x0, x1 = spec.margin, spec.width - spec.margin
    blocks = [
        header_block(c, spec, x0, x1, logo),
        headline_block(c, spec, x0, x1),
        features_block(c, spec, x0, x1),
    ]
    if spec.platforms:
        blocks.append(platforms_block(c, spec, x0, x1))
    if spec.departments:
        blocks.append(departments_block(c, spec, x0, x1))

    # One gap for the whole canvas - above the header, between sections and
    # above the bar - so the spacing reads as a single rhythm.
    floor = spec.height - spec.bar
    content = sum(height for _, height, _ in blocks)
    gap = (floor - content) / (len(blocks) + 1)
    if gap < spec.min_gap:
        sizes = ", ".join(f"{name} {height:.0f}" for name, height, _ in blocks)
        raise SystemExit(f"{spec.file}: sections would sit {gap:.0f}px apart, under the "
                         f"{spec.min_gap:.0f}px minimum ({sizes}) - shorten the copy or "
                         "shrink the spec")

    y = gap
    for _, height, draw in blocks:
        draw(y)
        y += height + gap

    paint_bar(c, spec, phone)
    return c.image.resize((spec.width, spec.height), Image.LANCZOS)


def output_name(file: str, phone: str, index: int) -> str:
    """The first number keeps the plain name; the others add it in local form."""
    if index == 0:
        return file
    digits = re.sub(r"\D", "", phone)
    local = "0" + digits[3:] if digits.startswith("256") else digits
    stem, _, extension = file.rpartition(".")
    return f"{stem}-{local}.{extension}"


def main() -> None:
    names = {glyph for glyph, _, _ in FEATURES} | {glyph for glyph, _, _ in PLATFORMS}
    load_icons(sorted(names | {"sparkle", "globe", "message"}))
    logo = Image.open(LOGO).convert("RGBA")

    for index, phone in enumerate(PHONES):
        for spec in (SQUARE, PORTRAIT):
            out = HERE / output_name(spec.file, phone, index)
            compose(spec, logo, phone).save(out, optimize=True)
            print(f"{out.name}  {spec.width}x{spec.height}  {out.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
