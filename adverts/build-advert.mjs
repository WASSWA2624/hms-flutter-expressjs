/**
 * Build the HOSSPI WhatsApp adverts.
 *
 *   node adverts/build-advert.mjs
 *
 * Renders two PNGs from one design: a 1080x1080 square for sharing into chats
 * and groups, and a 1080x1920 portrait for WhatsApp Status. Both are produced
 * from the same brand tokens, copy and icon set the product itself uses, so
 * the advert cannot drift from the app.
 *
 * Text is set in Segoe UI, matching the website's stack, and rasterised by
 * sharp. The icons are lifted verbatim from src/components/ui/Icon.js, so the
 * glyphs on the advert are the glyphs in the application.
 */

import { readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import path from 'node:path';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..');

// sharp lives in the website's install; borrow it rather than adding a second
// ~30 MB copy of libvips for a script that runs a few times a year.
const require = createRequire(path.join(REPO, 'website/package.json'));
const sharp = require('sharp');

// --- brand -----------------------------------------------------------------
// Values are the website's own tokens (website/src/styles/theme.js).
const INK = '#0D2744';
const INK_DEEP = '#081A2E';
const PRIMARY = '#0079FD';
const PRIMARY_LIGHT = '#52A4FE';
const AZURE_SOFT = '#AECBFF';
const WHITE = '#FFFFFF';

const FONT = "'Segoe UI', 'Helvetica Neue', Arial, sans-serif";

// --- content ---------------------------------------------------------------
const HEADLINE = ['Run the whole hospital', 'from one system'];
const PROOF = '26 departments. One patient record.';
const PHONE = '+256 783 230 321';
const SITE = 'www.hosspi.com';

/**
 * Pull the icon geometry straight out of the product's own icon set, so the
 * advert tracks the application instead of drifting from a copied snapshot.
 *
 * @param {string[]} names - Icon keys to extract
 * @returns {Record<string, string>} Key to inner SVG markup
 */
function loadIcons(names) {
  const src = readFileSync(
    path.join(REPO, 'website/src/components/ui/Icon.js'), 'utf8'
  );
  const icons = {};
  for (const name of names) {
    // Plain string search rather than a built regex: the icon bodies are full
    // of slashes and quotes, and an escaped pattern here is a liability.
    const open = `\n  ${name}: (\n`;
    const from = src.indexOf(open);
    if (from === -1) throw new Error(`icon "${name}" not found in Icon.js`);
    const bodyStart = from + open.length;
    const to = src.indexOf('\n  ),', bodyStart);
    if (to === -1) throw new Error(`icon "${name}" is not terminated in Icon.js`);
    icons[name] = src
      .slice(bodyStart, to)
      .split('<>').join('')
      .split('</>').join('')
      .split(/\s+/)
      .join(' ')
      .trim();
  }
  return icons;
}
const DEPARTMENTS = [
  ['userPlus', 'Reception'],
  ['bed', 'Wards'],
  ['pulse', 'ICU'],
  ['scissors', 'Theatre'],
  ['flask', 'Laboratory'],
  ['pill', 'Pharmacy'],
  ['receipt', 'Billing'],
  ['chart', 'Reports'],
];

const ICONS = loadIcons([...DEPARTMENTS.map(([name]) => name), 'message']);

const logo = readFileSync(path.join(REPO, 'website/public/logos/icon-512.png'));
const logoHref = `data:image/png;base64,${logo.toString('base64')}`;

/**
 * One department tile: icon above a one-word label.
 *
 * @param {string} name - Icon key
 * @param {string} label - Caption
 * @param {number} x - Tile centre x
 * @param {number} y - Tile top y
 * @param {number} s - Icon box size
 * @returns {string} SVG fragment
 */
function tile(name, label, x, y, s) {
  const scale = s / 24;
  const iconX = x - s / 2;
  return `
  <g>
    <rect x="${x - s * 0.82}" y="${y - s * 0.34}" width="${s * 1.64}" height="${s * 1.64}"
          rx="${s * 0.34}" fill="#FFFFFF" fill-opacity="0.07"
          stroke="${PRIMARY_LIGHT}" stroke-opacity="0.22" stroke-width="1.5"/>
    <g transform="translate(${iconX} ${y}) scale(${scale})"
       fill="none" stroke="${AZURE_SOFT}" stroke-width="1.7"
       stroke-linecap="round" stroke-linejoin="round">${ICONS[name]}</g>
    <text x="${x}" y="${y + s * 1.62}" font-family="${FONT}" font-size="${s * 0.42}"
          font-weight="600" fill="#9FC0E8" text-anchor="middle">${label}</text>
  </g>`;
}

/**
 * Compose the advert.
 *
 * Positions flow from a single top-down cursor rather than magic offsets, so
 * blocks cannot overlap and the two canvases share one layout.
 *
 * @param {{w: number, h: number, tall: boolean}} spec - Canvas
 * @returns {string} SVG document
 */
function advert({ w, h, tall }) {
  const cx = w / 2;
  const k = tall ? 1.34 : 1;          // portrait has room; scale the rhythm up
  const barH = Math.round(196 * k);
  const floor = h - barH;             // nothing in the stack may cross this

  const logoSize = Math.round(104 * k);
  const wordSize = Math.round(54 * k);
  const eyebrowSize = Math.round(20 * k);
  const headSize = Math.round(66 * k);
  const headLead = Math.round(78 * k);
  const proofSize = Math.round(31 * k);
  const iconSize = Math.round(54 * k);
  const rowLead = Math.round(162 * k);

  // Three gaps separate the four blocks: lockup, headline, proof, icon grid.
  // Whatever height is left over after the blocks and a minimum margin gets
  // shared between those gaps, so a tall canvas spreads rather than leaving a
  // dead band above the bar.
  const gapLockup = Math.round(74 * k);
  const gapHead = Math.round(62 * k);
  const gapProof = Math.round(56 * k);

  const blocksH =
    logoSize + Math.round(58 * k) + Math.round(34 * k) +
    headLead * (HEADLINE.length - 1) +
    rowLead + Math.round(iconSize * 1.62);
  const margin = Math.round(56 * k);
  const slack = Math.max(
    0,
    floor - blocksH - gapLockup - gapHead - gapProof - margin * 2
  );
  const share = slack / 4;   // three gaps plus one share left as bottom air

  let y = margin + share * 0.5;
  const logoY = y;
  y += logoSize + Math.round(58 * k);
  const wordY = y;
  y += Math.round(34 * k);
  const eyebrowY = y;
  y += gapLockup + share;
  const headY = y;
  y += headLead * (HEADLINE.length - 1) + gapHead + share;
  const proofY = y;
  y += gapProof + share;
  const gridY = y;

  const gap = (w - Math.round(150 * k)) / 4;
  const grid = DEPARTMENTS.map(([name, label], i) => tile(
    name,
    label,
    Math.round(75 * k) + gap * (i % 4) + gap / 2,
    gridY + Math.floor(i / 4) * rowLead,
    iconSize
  )).join('');

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="${INK}"/>
      <stop offset="1" stop-color="${INK_DEEP}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.16" cy="0.06" r="0.8">
      <stop offset="0" stop-color="${PRIMARY}" stop-opacity="0.26"/>
      <stop offset="1" stop-color="${PRIMARY}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="bar" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${PRIMARY}"/>
      <stop offset="1" stop-color="#0267D9"/>
    </linearGradient>
  </defs>

  <rect width="${w}" height="${h}" fill="url(#bg)"/>
  <rect width="${w}" height="${h}" fill="url(#glow)"/>

  <!-- brand lockup -->
  <image href="${logoHref}" x="${cx - logoSize / 2}" y="${logoY}"
         width="${logoSize}" height="${logoSize}"/>
  <text x="${cx}" y="${wordY}" font-family="${FONT}" font-size="${wordSize}"
        font-weight="700" fill="${WHITE}" letter-spacing="1"
        text-anchor="middle">HOSSPI</text>
  <text x="${cx}" y="${eyebrowY}" font-family="${FONT}" font-size="${eyebrowSize}"
        font-weight="600" fill="${PRIMARY_LIGHT}" letter-spacing="${4.6 * k}"
        text-anchor="middle">HOSPITAL MANAGEMENT SYSTEM</text>

  <!-- headline -->
  ${HEADLINE.map((line, i) => `<text x="${cx}" y="${headY + i * headLead}"
        font-family="${FONT}" font-size="${headSize}" font-weight="700"
        fill="${WHITE}" text-anchor="middle">${line}</text>`).join('')}

  <text x="${cx}" y="${proofY}" font-family="${FONT}" font-size="${proofSize}"
        fill="${AZURE_SOFT}" text-anchor="middle">${PROOF}</text>

  <!-- what it covers -->
  ${grid}

  <!-- call to action -->
  <rect x="0" y="${floor}" width="${w}" height="${barH}" fill="url(#bar)"/>
  <g transform="translate(${cx - 262 * k} ${floor + 52 * k}) scale(${1.9 * k})"
     fill="none" stroke="${WHITE}" stroke-width="1.9"
     stroke-linecap="round" stroke-linejoin="round">${ICONS.message}</g>
  <text x="${cx + 30 * k}" y="${floor + 92 * k}" font-family="${FONT}"
        font-size="${Math.round(52 * k)}" font-weight="700" fill="${WHITE}"
        text-anchor="middle">${PHONE}</text>
  <text x="${cx}" y="${floor + 148 * k}" font-family="${FONT}"
        font-size="${Math.round(35 * k)}" font-weight="600" fill="#D6E7FF"
        letter-spacing="${1.5 * k}" text-anchor="middle">${SITE}</text>
</svg>`;
}

const OUTPUTS = [
  { file: 'hosspi-whatsapp-advert.png', w: 1080, h: 1080, tall: false },
  { file: 'hosspi-whatsapp-status.png', w: 1080, h: 1920, tall: true },
];

for (const spec of OUTPUTS) {
  const svg = advert(spec);
  const out = path.join(HERE, spec.file);
  await sharp(Buffer.from(svg))
    .png({ compressionLevel: 9 })
    .toFile(out);
  const { size } = statSync(out);
  console.log(`${spec.file}  ${spec.w}x${spec.h}  ${(size / 1024).toFixed(0)} KB`);
}
