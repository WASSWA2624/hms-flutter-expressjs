# adverts/

Shareable HOSSPI artwork. Generated, not hand-drawn: edit the script, rebuild.

| File | Size | Use |
| --- | --- | --- |
| `hosspi-whatsapp-advert.png` | 1080x1080 | chats, groups, broadcast lists |
| `hosspi-whatsapp-status.png` | 1080x1920 | WhatsApp Status, Instagram/Facebook stories |

```bash
node adverts/build-advert.mjs
```

Needs `website/node_modules` installed; the script borrows sharp from there
rather than keeping a second copy of libvips.

## Editing

Copy, phone number and the department list are constants at the top of
`build-advert.mjs`. The palette is the website's own tokens, the icons are read
out of `website/src/components/ui/Icon.js` at build time, and the logo is
`website/public/logos/icon-512.png`, so the advert cannot drift from the
product. Layout flows from a single top-down cursor with the leftover height
shared between blocks, so both canvases come from one set of numbers.

Keep the headline to two lines. A third pushes the icon grid into the call to
action bar.
