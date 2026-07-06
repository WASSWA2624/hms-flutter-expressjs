/**
 * Resolve radiology catalog metadata for clinical term search results.
 */

const NON_BODY_REGION_TOKENS = new Set([
  'FACILITY',
  'GLOBAL',
  'FAVORITES',
  'ALL',
  'STANDARD',
  'STANDARD_RADIOLOGY_CATALOG',
  'FACILITY_RADIOLOGY_CATALOG',
  'GLOBAL_RADIOLOGY_CATALOG',
  'UGANDA_CATALOG',
]);

const BODY_REGION_NAME_ALIASES = Object.freeze([
  { region: 'Pelvis', patterns: ['PELVIC', 'PELVIS', 'TRANSVAGINAL', 'UTERINE', 'OVARIAN'] },
  { region: 'Chest', patterns: ['THORAX', 'THORACIC', 'LUNG', 'RIB'] },
  { region: 'Abdomen', patterns: ['ABDOMINAL', 'HEPATIC', 'RENAL', 'SPLENIC'] },
  { region: 'Head', patterns: ['CRANIAL', 'SKULL', 'BRAIN', 'CEREBRAL'] },
  { region: 'Neck', patterns: ['CERVICAL', 'THYROID', 'LARYNGEAL'] },
  { region: 'Breast', patterns: ['MAMMO', 'MAMMARY'] },
  { region: 'Heart', patterns: ['CARDIAC', 'CORONARY'] },
  { region: 'Kidneys', patterns: ['RENAL', 'KIDNEY'] },
  { region: 'Liver', patterns: ['HEPATIC', 'HEPATOBILIARY'] },
  { region: 'Knee', patterns: ['PATELL', 'PATELLA'] },
  { region: 'Shoulder', patterns: ['GLENOHUMERAL', 'ROTATOR'] },
  { region: 'Foot', patterns: ['PLANTAR', 'TARSAL', 'METATARSAL'] },
  { region: 'Hand', patterns: ['PALMAR', 'CARPAL', 'METACARPAL'] },
  { region: 'Wrist', patterns: ['CARPAL'] },
  { region: 'Ankle', patterns: ['TARSAL', 'MALLEOL'] },
  { region: 'Hip', patterns: ['ACETABUL', 'FEMOROACETABULAR'] },
  { region: 'Orbit', patterns: ['OCULAR', 'OPHTHALMIC'] },
  { region: 'Paranasal sinuses', patterns: ['SINUS', 'PARANASAL'] },
  { region: 'Lumbar spine', patterns: ['LUMBAR'] },
  { region: 'Thoracic spine', patterns: ['THORACIC SPINE'] },
  { region: 'Cervical spine', patterns: ['CERVICAL SPINE'] },
]);

const LATERALITY_NAME_PATTERNS = Object.freeze([
  { laterality: 'LEFT', patterns: ['LEFT'] },
  { laterality: 'RIGHT', patterns: ['RIGHT'] },
  { laterality: 'BILATERAL', patterns: ['BILATERAL', 'BOTH'] },
  { laterality: 'OBLIQUE', patterns: ['OBLIQUE'] },
]);

const RADIOLOGY_BODY_REGIONS = Object.freeze([
  'Abdomen',
  'Abdomen and pelvis',
  'Acetabulum',
  'Adrenal glands',
  'Ankle',
  'Aorta',
  'Appendix',
  'Arm',
  'Axilla',
  'Biliary tree',
  'Bladder',
  'Brachial plexus',
  'Brain',
  'Breast',
  'Calcaneus',
  'Carotid arteries',
  'Cervical spine',
  'Chest',
  'Clavicle',
  'Coccyx',
  'Colon',
  'Elbow',
  'Esophagus',
  'Face',
  'Femur',
  'Fetal anatomy',
  'Finger',
  'Foot',
  'Forearm',
  'Gallbladder',
  'Hand',
  'Head',
  'Heart',
  'Hepatobiliary system',
  'Hip',
  'Humerus',
  'Internal auditory canals',
  'Kidneys',
  'Knee',
  'Larynx',
  'Leg',
  'Liver',
  'Lumbar spine',
  'Lung',
  'Mandible',
  'Mastoid',
  'Maxillofacial region',
  'Mediastinum',
  'Neck',
  'Orbit',
  'Ovary',
  'Pancreas',
  'Paranasal sinuses',
  'Pelvis',
  'Peripheral arteries',
  'Peripheral veins',
  'Prostate',
  'Renal arteries',
  'Ribs',
  'Sacrum',
  'Scapula',
  'Scrotum',
  'Shoulder',
  'Small bowel',
  'Soft tissue',
  'Spleen',
  'Sternum',
  'Temporomandibular joint',
  'Thoracic spine',
  'Thyroid',
  'Tibia and fibula',
  'Toe',
  'Uterus',
  'Wrist',
]);

const normalizeText = (value) => String(value ?? '').trim();

const normalizeToken = (value) => normalizeText(value).toUpperCase().replace(/[^A-Z0-9]+/g, '_');

const isNonBodyRegionToken = (value) => {
  const token = normalizeToken(value);
  return !token || NON_BODY_REGION_TOKENS.has(token);
};

const inferBodyRegionFromName = (name) => {
  const normalized = normalizeText(name).toUpperCase();
  if (!normalized) return null;

  const regionsByLength = [...RADIOLOGY_BODY_REGIONS].sort(
    (left, right) => right.length - left.length
  );
  for (const region of regionsByLength) {
    if (normalized.includes(region.toUpperCase())) {
      return region;
    }
  }

  for (const alias of BODY_REGION_NAME_ALIASES) {
    if (alias.patterns.some((pattern) => normalized.includes(pattern))) {
      return alias.region;
    }
  }

  return null;
};

const inferLateralityFromName = (name) => {
  const normalized = normalizeText(name).toUpperCase();
  if (!normalized) return null;

  for (const entry of LATERALITY_NAME_PATTERNS) {
    if (entry.patterns.some((pattern) => normalized.includes(pattern))) {
      return entry.laterality;
    }
  }

  return null;
};

const resolveRadiologyBodyRegion = (test = {}) => {
  const stored = normalizeText(test.body_region);
  if (stored && !isNonBodyRegionToken(stored)) {
    return stored;
  }
  return inferBodyRegionFromName(test.name);
};

const resolveRadiologyLaterality = (test = {}) => {
  const stored = normalizeText(test.laterality);
  if (stored) {
    return stored;
  }
  return inferLateralityFromName(test.name);
};

const buildRadiologyCatalogMetadata = (test = {}, extra = {}) => ({
  modality: normalizeText(test.modality) || null,
  body_region: resolveRadiologyBodyRegion(test),
  laterality: resolveRadiologyLaterality(test),
  equipment: normalizeText(test.equipment) || null,
  procedure_type: normalizeText(test.procedure_type) || null,
  ...extra,
});

module.exports = {
  RADIOLOGY_BODY_REGIONS,
  NON_BODY_REGION_TOKENS,
  inferBodyRegionFromName,
  inferLateralityFromName,
  resolveRadiologyBodyRegion,
  resolveRadiologyLaterality,
  buildRadiologyCatalogMetadata,
  isNonBodyRegionToken,
};
