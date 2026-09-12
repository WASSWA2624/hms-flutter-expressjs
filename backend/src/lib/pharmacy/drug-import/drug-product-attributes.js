/**
 * Best-effort dosage form and strength inference for imported products.
 *
 * Source systems such as Medic-ERP only export a free-text product name
 * ("CEFIXIME 400MG CAPSULE"), so catalog form/strength are derived from it and
 * surfaced in the import review before anything is saved.
 */

const MAX_ATTRIBUTE_LENGTH = 80;

// Order is irrelevant: the keyword that appears last in the name wins, so
// "RELCER GEL SYRUP" resolves to Syrup rather than Gel.
const FORM_PATTERNS = Object.freeze([
  ['Tablet', '\\b(tablets?|tabs?)\\b'],
  ['Capsule', '\\b(capsules?|caps?)\\b'],
  ['Syrup', '\\b(syrups?|syp)\\b'],
  ['Suspension', '\\b(suspensions?|susp)\\b'],
  ['Injection', '\\b(injections?|injectable|inj)\\b'],
  ['Infusion', '\\binfusions?\\b'],
  ['Cream', '\\bcreams?\\b'],
  ['Ointment', '\\b(ointments?|oint)\\b'],
  ['Gel', '\\bgels?\\b'],
  ['Drops', '\\bdrops?\\b'],
  ['Spray', '\\bsprays?\\b'],
  ['Inhaler', '\\binhalers?\\b'],
  ['Powder', '\\bpowders?\\b'],
  ['Lozenge', '\\blozenges?\\b'],
  ['Solution', '\\bsolutions?\\b'],
  ['Suppository', '\\bsuppositor(y|ies)\\b'],
  ['Pessary', '\\bpessar(y|ies)\\b'],
  ['Sachet', '\\bsachets?\\b'],
  ['Lotion', '\\blotions?\\b'],
]);

const STRENGTH_PATTERN = '(\\d+(?:[.,]\\d+)?)\\s*(mcg|µg|ug|mg|g|ml|iu|mmol|meq|%)(?![a-z])';

const STRENGTH_UNITS = Object.freeze({
  mcg: 'mcg',
  µg: 'mcg',
  ug: 'mcg',
  mg: 'mg',
  g: 'g',
  ml: 'ml',
  iu: 'IU',
  mmol: 'mmol',
  meq: 'mEq',
  '%': '%',
});

const findLastForm = (text) => {
  let best = null;
  for (const [form, source] of FORM_PATTERNS) {
    for (const match of text.matchAll(new RegExp(source, 'gi'))) {
      if (!best || match.index >= best.index) {
        best = { form, index: match.index };
      }
    }
  }
  return best?.form || null;
};

/**
 * @param {string|null} name
 * @param {string|null} [brandName]
 * @returns {string|null}
 */
const inferDosageForm = (name, brandName = null) =>
  findLastForm(String(name || '')) || findLastForm(String(brandName || ''));

const extractStrengths = (text) => {
  const strengths = [];
  for (const match of String(text || '').matchAll(new RegExp(STRENGTH_PATTERN, 'gi'))) {
    const amount = match[1].replace(',', '.');
    const unit = STRENGTH_UNITS[match[2].toLowerCase()];
    const label = unit === '%' ? `${amount}%` : `${amount} ${unit}`;
    if (!strengths.includes(label)) strengths.push(label);
  }
  return strengths;
};

/**
 * @param {string|null} name
 * @param {string|null} [brandName]
 * @returns {string|null} e.g. "500 mg" or "500 mg + 65 mg"
 */
const inferStrength = (name, brandName = null) => {
  const strengths = extractStrengths(name);
  const resolved = strengths.length ? strengths : extractStrengths(brandName);
  if (!resolved.length) return null;
  return resolved.join(' + ').slice(0, MAX_ATTRIBUTE_LENGTH);
};

module.exports = {
  inferDosageForm,
  inferStrength,
};
