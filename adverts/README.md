# adverts/

Shareable HOSSPI artwork. Generated, not hand-drawn: edit the script, rebuild.

| File | Size | Use |
| --- | --- | --- |
| `hosspi-whatsapp-advert.png` | 1080x1080 | chats, groups, broadcast lists |
| `hosspi-whatsapp-status.png` | 1080x1920 | WhatsApp Status, Instagram/Facebook stories |

The pair is built once for every contact number in `PHONES`. The plain names
carry +256 783 230 321; the copies suffixed `-0709932926` carry
+256 709 932 926.

```bash
python adverts/build-advert.py
```

Needs Pillow and PyMuPDF (`python -m pip install pillow pymupdf`) and the Segoe
UI fonts that ship with Windows. Anywhere else, point `HOSSPI_FONT_DIR` at a
folder holding `segoeui.ttf`, `seguisb.ttf` and `segoeuib.ttf`.

## What it says

Both canvases carry the logo and name side by side, the headline, and eight
feature cards: AI assistance, speech to text, every platform, customisation,
clinical care, diagnostics, finance and multi-facility groups. The portrait
adds a platform row and a list of departments. Both end on the demo call to
action, the WhatsApp number and the website.

Only capabilities users can reach in the current release belong here - the
same rule as `website/src/lib/product.js`. Check a claim against the app before
adding it.

## Editing

Copy, features, platforms, departments and contact details are constants at
the top of `build-advert.py`, and each canvas has its own `Spec` of sizes. The
palette is the website's tokens, the icons are read out of
`website/src/components/ui/Icon.js` at build time (plus a microphone the site's
set does not have yet), and the logo is `website/public/logos/icon-512.png`, so
the advert cannot drift from the product.

Type is sized for a phone, where WhatsApp shows the image at a fraction of its
pixel width. Keep card details to about 34 characters so they stay on one line
in the square.

Layout is measured and evenly spaced: every block takes its height from the
real font metrics, and the height left over becomes one gap used above the
header, between every section and above the call-to-action bar. If copy grows
until that gap falls below the spec's `min_gap`, the build stops and prints
each block's height instead of cramming the layout.
