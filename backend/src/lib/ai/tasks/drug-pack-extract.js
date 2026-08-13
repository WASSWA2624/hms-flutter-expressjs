/**
 * drug_pack_extract task
 *
 * Reads pack photos and/or OCR text into structured drug-create fields.
 * Extract only what is visible. Do not invent missing values.
 */

const { z } = require('zod');
const { AI_MAX_INPUT_CHARS } = require('@config/env');
const {
  AI_MAX_PACK_IMAGES,
  AI_MAX_IMAGE_BASE64_CHARS,
} = require('@config/constants');

const KNOWN_FORMS = Object.freeze([
  'Tablet',
  'Capsule',
  'Chewable Tablet',
  'Syrup',
  'Suspension',
  'Injection',
  'Ampoule',
  'Vial',
  'Cream',
  'Ointment',
  'Gel',
  'Drops',
  'Inhaler',
  'Suppository',
  'Patch',
  'Powder',
  'Solution',
  'Lotion',
  'Spray',
  'Other',
]);

const FORM_ALIASES = Object.freeze({
  tab: 'Tablet',
  tabs: 'Tablet',
  tablet: 'Tablet',
  tablets: 'Tablet',
  cap: 'Capsule',
  caps: 'Capsule',
  capsule: 'Capsule',
  capsules: 'Capsule',
  chewable: 'Chewable Tablet',
  'chewable tablet': 'Chewable Tablet',
  'chewable tablets': 'Chewable Tablet',
  syrup: 'Syrup',
  suspension: 'Suspension',
  susp: 'Suspension',
  inj: 'Injection',
  injection: 'Injection',
  ampoule: 'Ampoule',
  amp: 'Ampoule',
  vial: 'Vial',
  cream: 'Cream',
  ointment: 'Ointment',
  gel: 'Gel',
  drops: 'Drops',
  inhaler: 'Inhaler',
  suppository: 'Suppository',
  patch: 'Patch',
  powder: 'Powder',
  solution: 'Solution',
  lotion: 'Lotion',
  spray: 'Spray',
});

const EMPTY_OUTPUT = Object.freeze({
  generic_name: null,
  brand_name: null,
  form: null,
  strength: null,
  code: null,
  batch_number: null,
  manufactured_at: null,
  expiry_date: null,
  barcode: null,
  raw_text: null,
});

const MISSING_VALUE = /^(unknown|n\/?a|none|null|nil|-|not\s+(?:visible|found|listed))$/i;

const stripDataUrl = (value) => {
  const text = String(value || '').trim();
  if (!text) {
    return '';
  }
  const match = text.match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/s);
  return String(match ? match[1] : text).replace(/\s+/g, '');
};

const emptyToNull = (value) => {
  if (value == null) {
    return null;
  }
  const text = String(value).trim();
  if (!text || MISSING_VALUE.test(text)) {
    return null;
  }
  return text;
};

const extractJsonObject = (raw) => {
  let text = String(raw || '').trim();
  if (!text) {
    return null;
  }
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
  try {
    const parsed = JSON.parse(text);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
  } catch (_error) {
    // Fall through to brace slice.
  }
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  try {
    const parsed = JSON.parse(text.slice(start, end + 1));
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
  } catch (_error) {
    return null;
  }
  return null;
};

const normalizeForm = (value) => {
  const text = emptyToNull(value);
  if (!text) {
    return null;
  }
  const exact = KNOWN_FORMS.find(
    (form) => form.toLowerCase() === text.toLowerCase()
  );
  if (exact) {
    return exact;
  }
  const alias = FORM_ALIASES[text.toLowerCase()];
  return alias || null;
};

const normalizeStrength = (value) => {
  const text = emptyToNull(value);
  if (!text) {
    return null;
  }
  return text
    .replace(/,/g, '.')
    .replace(
      /(\d+(?:\.\d+)?)\s*(mg|mcg|µg|g|ml|mL|%|IU|units?)\b/gi,
      (_, amount, unit) => `${amount} ${unit}`
    )
    .replace(/\s{2,}/g, ' ')
    .trim();
};

const normalizeIsoDate = (value) => {
  const text = emptyToNull(value);
  if (!text) {
    return null;
  }
  const iso = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (iso) {
    return text;
  }
  const yearMonth = text.match(/^(\d{4})[\/\-.](\d{1,2})$/);
  if (yearMonth) {
    const month = Number(yearMonth[2]);
    if (month >= 1 && month <= 12) {
      return `${yearMonth[1]}-${String(month).padStart(2, '0')}-01`;
    }
  }
  const monthYear = text.match(/^(\d{1,2})[\/\-.](\d{4})$/);
  if (monthYear) {
    const month = Number(monthYear[1]);
    const year = Number(monthYear[2]);
    if (month >= 1 && month <= 12) {
      return `${year}-${String(month).padStart(2, '0')}-01`;
    }
  }
  const dmy = text.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$/);
  if (dmy) {
    const day = Number(dmy[1]);
    const month = Number(dmy[2]);
    let year = Number(dmy[3]);
    if (year < 100) {
      year += 2000;
    }
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    }
  }
  const parsed = Date.parse(text);
  if (Number.isFinite(parsed)) {
    const date = new Date(parsed);
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  return null;
};

const imageSchema = z.object({
  mime_type: z
    .enum(['image/jpeg', 'image/png', 'image/webp', 'image/jpg'])
    .optional()
    .default('image/jpeg')
    .transform((value) => (value === 'image/jpg' ? 'image/jpeg' : value)),
  data: z
    .string()
    .trim()
    .min(1)
    .max(AI_MAX_IMAGE_BASE64_CHARS + 64)
    .transform(stripDataUrl)
    .pipe(z.string().min(32).max(AI_MAX_IMAGE_BASE64_CHARS)),
});

const emptyOutput = () => ({ ...EMPTY_OUTPUT });

const drugPackExtractTask = {
  key: 'drug_pack_extract',
  failOpen: true,
  usesVision: true,
  temperature: 0,
  inputSchema: z
    .object({
      images: z.array(imageSchema).max(AI_MAX_PACK_IMAGES).optional().default([]),
      ocr_text: z.string().trim().max(AI_MAX_INPUT_CHARS).optional(),
      barcode: z.string().trim().max(64).optional(),
      locale: z.string().trim().min(1).max(32).optional().default('en'),
    })
    .superRefine((value, ctx) => {
      const hasImages = Array.isArray(value.images) && value.images.length > 0;
      const hasText = Boolean(value.ocr_text && value.ocr_text.trim());
      if (!hasImages && !hasText) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'images or ocr_text is required',
          path: ['images'],
        });
      }
    }),
  systemPrompt: [
    'You extract drug pack fields from photos and optional OCR text.',
    'Output a single JSON object only. No markdown, labels, or explanation.',
    'Use null when a field is not clearly visible. Never invent names, strengths, dates, or codes.',
    'Prefer printed pack text over OCR hints when they disagree.',
    'generic_name is the INN/active ingredient. brand_name is the trade mark.',
    `form must be one of: ${KNOWN_FORMS.join(', ')}.`,
    'strength is dose with a space before the unit, for example "500 mg" or "125 mg/5 mL".',
    'Dates must be ISO YYYY-MM-DD. If only month/year is printed, use YYYY-MM-01.',
    'raw_text is the readable pack wording, one fact per line, without marketing slogans.',
    'JSON keys: generic_name, brand_name, form, strength, code, batch_number, manufactured_at, expiry_date, barcode, raw_text.',
  ].join(' '),
  buildUserPrompt: (input) => {
    const lines = [
      `locale: ${input.locale || 'en'}`,
      `photo_count: ${Array.isArray(input.images) ? input.images.length : 0}`,
    ];
    if (input.barcode) {
      lines.push(`barcode: ${input.barcode}`);
    }
    if (input.ocr_text) {
      lines.push('ocr_text:');
      lines.push(input.ocr_text);
    }
    lines.push(
      'Extract fields from the attached pack photo(s) and any ocr_text. Return JSON only.'
    );
    return lines.join('\n');
  },
  buildImages: (input) =>
    (Array.isArray(input.images) ? input.images : [])
      .map((image) => stripDataUrl(image?.data))
      .filter(Boolean),
  outputParser: (completionText, input) => {
    const parsed = extractJsonObject(completionText);
    if (!parsed) {
      return {
        ...emptyOutput(),
        barcode: emptyToNull(input?.barcode),
        raw_text: emptyToNull(input?.ocr_text),
      };
    }
    return {
      generic_name: emptyToNull(parsed.generic_name),
      brand_name: emptyToNull(parsed.brand_name),
      form: normalizeForm(parsed.form),
      strength: normalizeStrength(parsed.strength),
      code: emptyToNull(parsed.code),
      batch_number: emptyToNull(parsed.batch_number),
      manufactured_at: normalizeIsoDate(parsed.manufactured_at),
      expiry_date: normalizeIsoDate(parsed.expiry_date),
      barcode: emptyToNull(parsed.barcode) || emptyToNull(input.barcode),
      raw_text: emptyToNull(parsed.raw_text) || emptyToNull(input.ocr_text),
    };
  },
  failOpenOutput: (input) => ({
    ...emptyOutput(),
    barcode: emptyToNull(input?.barcode),
    raw_text: emptyToNull(input?.ocr_text),
  }),
};

module.exports = {
  drugPackExtractTask,
  KNOWN_FORMS,
};
