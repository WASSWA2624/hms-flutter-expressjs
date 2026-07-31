/**
 * Prisma-safe radiology procedure text search helpers.
 *
 * `radiology_procedure.modality` is an ImagingModality enum — never use
 * `{ contains }` on it (Prisma throws, which surfaces as Unexpected response).
 */

const IMAGING_MODALITIES = Object.freeze([
  'XRAY',
  'CT',
  'MRI',
  'ULTRASOUND',
  'FLUOROSCOPY',
  'MAMMOGRAPHY',
  'PET',
  'NUCLEAR_MEDICINE',
  'INTERVENTIONAL_RADIOLOGY',
  'ECG',
  'ECHO',
  'ENDO',
  'GASTRO',
  'OTHER',
]);

const MODALITY_ALIASES = Object.freeze({
  X_RAY: 'XRAY',
  US: 'ULTRASOUND',
  SONO: 'ULTRASOUND',
  SONOGRAPHY: 'ULTRASOUND',
  NM: 'NUCLEAR_MEDICINE',
  IR: 'INTERVENTIONAL_RADIOLOGY',
  MAMMO: 'MAMMOGRAPHY',
  FLUORO: 'FLUOROSCOPY',
});

const normalizeModalityToken = (value) =>
  String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');

const matchingImagingModalities = (rawQuery) => {
  const token = normalizeModalityToken(rawQuery);
  if (!token) {
    return [];
  }
  if (IMAGING_MODALITIES.includes(token)) {
    return [token];
  }
  const alias = MODALITY_ALIASES[token];
  if (alias && IMAGING_MODALITIES.includes(alias)) {
    return [alias];
  }
  return IMAGING_MODALITIES.filter(
    (modality) => modality.includes(token) || token.includes(modality)
  );
};

/**
 * Build Prisma OR clauses for radiology_procedure free-text search.
 * @param {string} rawQuery
 * @returns {object[]}
 */
const buildRadiologyProcedureSearchOr = (rawQuery) => {
  const raw = String(rawQuery || '').trim();
  if (!raw) {
    return [];
  }
  const or = [
    { name: { contains: raw } },
    { code: { contains: raw } },
    { body_region: { contains: raw } },
  ];
  for (const modality of matchingImagingModalities(raw)) {
    or.push({ modality });
  }
  return or;
};

/**
 * Nested radiology_procedure filter for facility offering queries.
 * @param {string} rawQuery
 * @returns {{ deleted_at: null, OR: object[] } | null}
 */
const buildRadiologyProcedureSearchFilter = (rawQuery) => {
  const or = buildRadiologyProcedureSearchOr(rawQuery);
  if (or.length === 0) {
    return null;
  }
  return {
    deleted_at: null,
    OR: or,
  };
};

module.exports = {
  IMAGING_MODALITIES,
  buildRadiologyProcedureSearchFilter,
  buildRadiologyProcedureSearchOr,
  matchingImagingModalities,
};
