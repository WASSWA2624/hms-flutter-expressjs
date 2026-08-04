const {
  UGANDA_CLINICAL_SOURCES,
  compactSourceNote,
} = require('./uganda-clinical-sources');

const ageRange = (minimum, minimumUnit, maximum = null, maximumUnit = null) => ({
  age_min_value: minimum,
  age_min_unit: minimumUnit,
  age_max_value: maximum,
  age_max_unit: maximum == null ? null : maximumUnit || minimumUnit,
});
const ageDays = (minimum, maximum = null) => ageRange(minimum, 'DAY', maximum);
const ageMonths = (minimum, maximum = null) => ageRange(minimum, 'MONTH', maximum);
const ageYears = (minimum, maximum = null) => ageRange(minimum, 'YEAR', maximum);

const AGE = Object.freeze({
  UNDER_1: ageRange(7, 'DAY', 11, 'MONTH'),
  AGE_1_5: ageYears(1, 5),
  AGE_6_12: ageYears(6, 12),
  AGE_13_18: ageYears(13, 18),
  AGE_19_24: ageYears(19, 24),
  OVER_24: ageYears(25),
});

const SOURCE_METHODS = Object.freeze({
  LUGADA_ACT5DIFF: 'SOURCE_RI: Beckman Coulter ACT 5diff',
  LUGADA_ACT5DIFF_NONPREGNANT: 'SOURCE_RI: ACT 5diff; pregnancy status resolved',
  LUGADA_FACSCAN: 'SOURCE_RI: BD FACScan dual-platform',
  KIRONDE_ACT5DIFF: 'SOURCE_RI: Beckman Coulter ACT 5diff Iganga',
  KIRONDE_COBAS_INTEGRA: 'SOURCE_RI: Roche Cobas Integra 400 Plus',
  PALACPAC_COBAS_C111: 'SOURCE_RI: Roche Cobas C111 fasting cohort',
  MAYO_ASSAY_TRANSFER: 'SOURCE_RI: Mayo assay-specific transfer',
});

const buildRange = ({
  sourceId,
  sourceDetail = 'Verify transfer on the local analyser before activation',
  label,
  unit = null,
  method = null,
  gender = null,
  age = {},
  normalMin = null,
  normalMax = null,
  criticalMin = null,
  criticalMax = null,
  referenceText = null,
  version = 2,
}) => ({
  label,
  unit,
  method,
  gender,
  age_min_value: age.age_min_value ?? null,
  age_min_unit: age.age_min_unit ?? null,
  age_max_value: age.age_max_value ?? null,
  age_max_unit: age.age_max_unit ?? null,
  normal_min_value: normalMin,
  normal_max_value: normalMax,
  critical_min_value: criticalMin,
  critical_max_value: criticalMax,
  reference_text: referenceText,
  notes: compactSourceNote(sourceId, sourceDetail),
  effective_from: null,
  effective_to: null,
  version,
});

const buildSeries = ({ sourceId, unit, method, sourceDetail, rows }) =>
  rows.map(([label, age, normalMin, normalMax, gender = null]) =>
    buildRange({
      sourceId,
      sourceDetail,
      label,
      unit,
      method,
      gender,
      age,
      normalMin,
      normalMax,
    })
  );

const LUGADA_DETAIL = '90% Ugandan population RI; source template requires local transfer verification';
const KIRONDE_DETAIL = '90% RI for healthy Ugandan children aged 12-60 months';
const PALACPAC_DETAIL = '95% RI from healthy rural northern Ugandan participants';
const MAYO_DETAIL = 'Method-dependent interval; verify locally per CLSI EP28-A3c';

const lugadaSeries = (
  unit,
  rows,
  {
    method = SOURCE_METHODS.LUGADA_ACT5DIFF,
    sourceDetail = LUGADA_DETAIL,
  } = {}
) =>
  buildSeries({
    sourceId: 'LUGADA_UGANDA_2004',
    unit,
    method,
    sourceDetail,
    rows,
  });

const kirondeRange = (
  label,
  unit,
  normalMin,
  normalMax,
  method = SOURCE_METHODS.KIRONDE_COBAS_INTEGRA
) =>
  buildRange({
    sourceId: 'KIRONDE_UGANDA_2013',
    sourceDetail: KIRONDE_DETAIL,
    label,
    unit,
    method,
    age: ageMonths(12, 60),
    normalMin,
    normalMax,
  });

const kirondeHematologyRange = (label, unit, normalMin, normalMax) =>
  kirondeRange(
    label,
    unit,
    normalMin,
    normalMax,
    SOURCE_METHODS.KIRONDE_ACT5DIFF
  );

const palacpacSeries = (unit, childValues, youngAdultValues) =>
  buildSeries({
    sourceId: 'PALACPAC_UGANDA_2014',
    unit,
    method: SOURCE_METHODS.PALACPAC_COBAS_C111,
    sourceDetail: PALACPAC_DETAIL,
    rows: [
      ['6-15 years', ageYears(6, 15), ...childValues],
      ['16-32 years', ageYears(16, 32), ...youngAdultValues],
    ],
  });

const HEMOGLOBIN_RANGES = lugadaSeries(
  'g/dL',
  [
    ['7 days-11 months', AGE.UNDER_1, 6.8, 14.7],
    ['1-5 years', AGE.AGE_1_5, 8.8, 12.5],
    ['6-12 years', AGE.AGE_6_12, 10, 13.7],
    ['Male 13-18 years', AGE.AGE_13_18, 11.2, 15.9, 'MALE'],
    ['Female 13-18 years', AGE.AGE_13_18, 9.9, 14.5, 'FEMALE'],
    ['Male 19-24 years', AGE.AGE_19_24, 11.5, 17.1, 'MALE'],
    ['Female 19-24 years', AGE.AGE_19_24, 9.9, 13.7, 'FEMALE'],
    ['Male over 24 years', AGE.OVER_24, 11.1, 16.8, 'MALE'],
    ['Female over 24 years', AGE.OVER_24, 10.1, 14.3, 'FEMALE'],
  ],
  {
    method: SOURCE_METHODS.LUGADA_ACT5DIFF_NONPREGNANT,
    sourceDetail: '90% population RI, not an anaemia decision or panic limit; verify locally and apply WHO 2024 separately',
  }
);

const UGANDA_REFERENCE_RANGE_OVERRIDES = Object.freeze({
  hemoglobin: HEMOGLOBIN_RANGES,
  hematocrit: lugadaSeries('%', [
    ['Under 1 year', AGE.UNDER_1, 20.4, 42.6],
    ['1-5 years', AGE.AGE_1_5, 25.9, 36.3],
    ['6-12 years', AGE.AGE_6_12, 29.2, 39.4],
    ['Male 13-18 years', AGE.AGE_13_18, 32.3, 45.5, 'MALE'],
    ['Female 13-18 years', AGE.AGE_13_18, 28.1, 42.4, 'FEMALE'],
    ['Male 19-24 years', AGE.AGE_19_24, 33.7, 48.7, 'MALE'],
    ['Female 19-24 years', AGE.AGE_19_24, 28.9, 40, 'FEMALE'],
    ['Male over 24 years', AGE.OVER_24, 32.2, 47.8, 'MALE'],
    ['Female over 24 years', AGE.OVER_24, 29.6, 41.4, 'FEMALE'],
  ]),
  red_blood_cell_count: lugadaSeries('x10^12/L', [
    ['Under 1 year', AGE.UNDER_1, 3, 5.4],
    ['1-5 years', AGE.AGE_1_5, 3.5, 5.2],
    ['6-12 years', AGE.AGE_6_12, 3.8, 5.4],
    ['Male 13-18 years', AGE.AGE_13_18, 4.1, 5.8, 'MALE'],
    ['Female 13-18 years', AGE.AGE_13_18, 3.5, 5.4, 'FEMALE'],
    ['Male 19-24 years', AGE.AGE_19_24, 4.3, 6.1, 'MALE'],
    ['Female 19-24 years', AGE.AGE_19_24, 3.6, 5.4, 'FEMALE'],
    ['Male over 24 years', AGE.OVER_24, 3.8, 6, 'MALE'],
    ['Female over 24 years', AGE.OVER_24, 3.7, 5.3, 'FEMALE'],
  ]),
  white_blood_cell_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 4.1, 15.8],
    ['1-5 years', AGE.AGE_1_5, 4.9, 13.6],
    ['6-12 years', AGE.AGE_6_12, 4.4, 11.5],
    ['13-18 years', AGE.AGE_13_18, 4.1, 10.7],
    ['19-24 years', AGE.AGE_19_24, 3.7, 9.7],
    ['Over 24 years', AGE.OVER_24, 3.4, 8.7],
  ]),
  platelet_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 123, 487],
    ['1-5 years', AGE.AGE_1_5, 126, 376],
    ['6-12 years', AGE.AGE_6_12, 134, 355],
    ['Male 13-18 years', AGE.AGE_13_18, 110, 327, 'MALE'],
    ['Female 13-18 years', AGE.AGE_13_18, 124, 353, 'FEMALE'],
    ['Male 19-24 years', AGE.AGE_19_24, 98, 306, 'MALE'],
    ['Female 19-24 years', AGE.AGE_19_24, 95, 368, 'FEMALE'],
    ['Male over 24 years', AGE.OVER_24, 80, 288, 'MALE'],
    ['Female over 24 years', AGE.OVER_24, 100, 297, 'FEMALE'],
  ]),
  mcv: lugadaSeries('fL', [
    ['Under 1 year', AGE.UNDER_1, 54.9, 88.3],
    ['1-5 years', AGE.AGE_1_5, 60.7, 82.8],
    ['6-12 years', AGE.AGE_6_12, 63.3, 83.9],
    ['Male 13-18 years', AGE.AGE_13_18, 65, 89.5, 'MALE'],
    ['Female 13-18 years', AGE.AGE_13_18, 67.4, 89.9, 'FEMALE'],
    ['Male 19-24 years', AGE.AGE_19_24, 67.2, 91.8, 'MALE'],
    ['Female 19-24 years', AGE.AGE_19_24, 64.2, 91.6, 'FEMALE'],
    ['Male over 24 years', AGE.OVER_24, 69.9, 95.2, 'MALE'],
    ['Female over 24 years', AGE.OVER_24, 67.7, 92.6, 'FEMALE'],
  ]),
  anc: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 0.9, 4.4],
    ['1-5 years', AGE.AGE_1_5, 1, 3.9],
    ['6-12 years', AGE.AGE_6_12, 0.9, 3.6],
    ['13-18 years', AGE.AGE_13_18, 0.9, 3.5],
    ['19-24 years', AGE.AGE_19_24, 1, 3.5],
    ['Over 24 years', AGE.OVER_24, 0.84, 3.37],
  ]),
  lymphocyte_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 1.9, 10.3],
    ['1-5 years', AGE.AGE_1_5, 2.4, 8.4],
    ['6-12 years', AGE.AGE_6_12, 2.2, 5.9],
    ['13-18 years', AGE.AGE_13_18, 1.7, 4.7],
    ['19-24 years', AGE.AGE_19_24, 1.3, 4.1],
    ['Over 24 years', AGE.OVER_24, 1.4, 4.2],
  ]),
  monocyte_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 0.22, 1.83],
    ['1-5 years', AGE.AGE_1_5, 0.26, 1.04],
    ['6-12 years', AGE.AGE_6_12, 0.24, 0.75],
    ['13-18 years', AGE.AGE_13_18, 0.21, 0.73],
    ['19-24 years', AGE.AGE_19_24, 0.18, 0.62],
    ['Over 24 years', AGE.OVER_24, 0.17, 0.59],
  ]),
  eosinophil_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 0.07, 1.85],
    ['1-5 years', AGE.AGE_1_5, 0.14, 2.03],
    ['6-12 years', AGE.AGE_6_12, 0.2, 3.14],
    ['13-18 years', AGE.AGE_13_18, 0.26, 2.77],
    ['19-24 years', AGE.AGE_19_24, 0.19, 2.42],
    ['Over 24 years', AGE.OVER_24, 0.13, 2.11],
  ]),
  basophil_count: lugadaSeries('x10^9/L', [
    ['Under 1 year', AGE.UNDER_1, 0.02, 0.3],
    ['1-5 years', AGE.AGE_1_5, 0.03, 0.17],
    ['6-12 years', AGE.AGE_6_12, 0.02, 0.12],
    ['13-18 years', AGE.AGE_13_18, 0.02, 0.1],
    ['19-24 years', AGE.AGE_19_24, 0.02, 0.08],
    ['Over 24 years', AGE.OVER_24, 0.01, 0.07],
  ]),
  neutrophil_percent: [kirondeHematologyRange('1-5 years', '%', 15.2, 46.8)],
  lymphocyte_percent: [kirondeHematologyRange('1-5 years', '%', 42.7, 75.7)],
  monocyte_percent: [kirondeHematologyRange('1-5 years', '%', 1.2, 6.5)],
  eosinophil_percent: [kirondeHematologyRange('1-5 years', '%', 0.9, 14)],
  basophil_percent: [kirondeHematologyRange('1-5 years', '%', 0.6, 1.8)],
  mean_platelet_volume: [kirondeHematologyRange('1-5 years', 'fL', 7, 9.7)],
  cd4_count: lugadaSeries(
    'cells/µL',
    [
      ['Under 1 year', AGE.UNDER_1, 700, 3514],
      ['1-5 years', AGE.AGE_1_5, 733, 2943],
      ['6-12 years', AGE.AGE_6_12, 704, 2304],
      ['13-18 years', AGE.AGE_13_18, 548, 1564],
      ['Male 19-24 years', AGE.AGE_19_24, 504, 1334, 'MALE'],
      ['Female 19-24 years', AGE.AGE_19_24, 560, 1961, 'FEMALE'],
      ['Male over 24 years', AGE.OVER_24, 362, 1376, 'MALE'],
      ['Female over 24 years', AGE.OVER_24, 454, 1485, 'FEMALE'],
    ],
    { method: SOURCE_METHODS.LUGADA_FACSCAN }
  ),
  cd8_absolute: lugadaSeries(
    'cells/µL',
    [
      ['Under 1 year', AGE.UNDER_1, 339, 2180],
      ['1-5 years', AGE.AGE_1_5, 423, 1940],
      ['6-12 years', AGE.AGE_6_12, 356, 1366],
      ['13-18 years', AGE.AGE_13_18, 282, 1262],
      ['Male 19-24 years', AGE.AGE_19_24, 286, 1579, 'MALE'],
      ['Female 19-24 years', AGE.AGE_19_24, 151, 1226, 'FEMALE'],
      ['Male over 24 years', AGE.OVER_24, 204, 1174, 'MALE'],
      ['Female over 24 years', AGE.OVER_24, 196, 1133, 'FEMALE'],
    ],
    { method: SOURCE_METHODS.LUGADA_FACSCAN }
  ),
  cd4_percent: lugadaSeries(
    '%',
    [
      ['Under 1 year', AGE.UNDER_1, 18.7, 44.4],
      ['1-5 years', AGE.AGE_1_5, 18.8, 45.8],
      ['6-12 years', AGE.AGE_6_12, 25.2, 47.2],
      ['13-18 years', AGE.AGE_13_18, 25.4, 46.2],
      ['Male 19-24 years', AGE.AGE_19_24, 18.5, 42.2, 'MALE'],
      ['Female 19-24 years', AGE.AGE_19_24, 27.4, 53, 'FEMALE'],
      ['Male over 24 years', AGE.OVER_24, 16.5, 45.3, 'MALE'],
      ['Female over 24 years', AGE.OVER_24, 22.5, 48.3, 'FEMALE'],
    ],
    { method: SOURCE_METHODS.LUGADA_FACSCAN }
  ),
  cd8_percent: lugadaSeries(
    '%',
    [
      ['Under 1 year', AGE.UNDER_1, 8.4, 28.5],
      ['1-5 years', AGE.AGE_1_5, 11, 30.7],
      ['6-12 years', AGE.AGE_6_12, 12.2, 31.7],
      ['13-18 years', AGE.AGE_13_18, 13, 33.1],
      ['Male 19-24 years', AGE.AGE_19_24, 12.7, 41.7, 'MALE'],
      ['Female 19-24 years', AGE.AGE_19_24, 9.2, 29.5, 'FEMALE'],
      ['Male over 24 years', AGE.OVER_24, 8.4, 36.3, 'MALE'],
      ['Female over 24 years', AGE.OVER_24, 10.2, 33.7, 'FEMALE'],
    ],
    { method: SOURCE_METHODS.LUGADA_FACSCAN }
  ),
  cd4_cd8_ratio: lugadaSeries(
    'ratio',
    [
      ['Under 1 year', AGE.UNDER_1, 0.9, 3.5],
      ['1-5 years', AGE.AGE_1_5, 0.8, 2.9],
      ['6-12 years', AGE.AGE_6_12, 0.9, 3.1],
      ['13-18 years', AGE.AGE_13_18, 1, 2.9],
      ['Male 19-24 years', AGE.AGE_19_24, 0.6, 2.5, 'MALE'],
      ['Female 19-24 years', AGE.AGE_19_24, 1.3, 4.6, 'FEMALE'],
      ['Male over 24 years', AGE.OVER_24, 0.7, 3.5, 'MALE'],
      ['Female over 24 years', AGE.OVER_24, 1, 3.1, 'FEMALE'],
    ],
    { method: SOURCE_METHODS.LUGADA_FACSCAN }
  ),

  sodium: [
    kirondeRange('1-5 years', 'mmol/L', 138, 144),
    ...palacpacSeries('mmol/L', [134.2, 141], [133.87, 147.4]),
  ],
  potassium: [
    kirondeRange('1-5 years', 'mmol/L', 3.8, 4.4),
    ...palacpacSeries('mmol/L', [3.46, 4.65], [3.58, 5.02]),
  ],
  chloride: [kirondeRange('1-5 years', 'mmol/L', 97, 104)],
  glucose: palacpacSeries('mg/dL', [66.4, 109.3], [67.2, 91.3]),
  bun: palacpacSeries('mg/dL', [5.14, 21.29], [6.05, 24.4]),
  creatinine: [
    kirondeRange('1-5 years', 'mg/dL', 0.18, 0.38),
    ...palacpacSeries('mg/dL', [0.31, 0.61], [0.43, 0.92]),
  ],
  urea: [kirondeRange('1-5 years', 'mmol/L', 0.8, 3.8)],
  uric_acid: palacpacSeries('mg/dL', [2, 4.88], [2.5, 5.59]),
  ast: [
    kirondeRange('1-5 years', 'U/L', 25, 67),
    ...palacpacSeries('U/L', [16.14, 29.9], [12.99, 26.11]),
  ],
  alt: [kirondeRange('1-5 years', 'U/L', 9, 32)],
  alp: [
    kirondeRange('1-5 years', 'U/L', 134, 351),
    ...palacpacSeries('U/L', [111.1, 419.7], [31.9, 108.4]),
  ],
  ggt: [kirondeRange('1-5 years', 'U/L', 8, 38)],
  amylase: palacpacSeries('U/L', [12.42, 36.3], [14.43, 37.3]),
  albumin: [kirondeRange('1-5 years', 'g/dL', 3.1, 4.7)],
  total_protein: [kirondeRange('1-5 years', 'g/dL', 6, 8.3)],
  bilirubin_total: [kirondeRange('1-5 years', 'mg/dL', 0.15, 1.04)],
  bilirubin_direct: [kirondeRange('1-5 years', 'mg/dL', 0, 0.25)],

  calcium_total: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'mg/dL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['Under 1 year', ageMonths(0, 11), 8.7, 11],
      ['1-17 years', ageYears(1, 17), 9.3, 10.6],
      ['18-59 years', ageYears(18, 59), 8.6, 10],
      ['60 years and older', ageYears(60), 8.8, 10.2],
    ],
  }),
  magnesium: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'mg/dL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['0-2 years', ageYears(0, 2), 1.6, 2.7],
      ['3-5 years', ageYears(3, 5), 1.6, 2.6],
      ['6-8 years', ageYears(6, 8), 1.6, 2.5],
      ['9-11 years', ageYears(9, 11), 1.6, 2.4],
      ['12-17 years', ageYears(12, 17), 1.6, 2.3],
      ['18 years and older', ageYears(18), 1.7, 2.3],
    ],
  }),
  phosphate: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'mg/dL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['Male 1-4 years', ageYears(1, 4), 4.3, 5.4, 'MALE'],
      ['Male 5-13 years', ageYears(5, 13), 3.7, 5.4, 'MALE'],
      ['Male 14-15 years', ageYears(14, 15), 3.5, 5.3, 'MALE'],
      ['Male 16-17 years', ageYears(16, 17), 3.1, 4.7, 'MALE'],
      ['Female 1-7 years', ageYears(1, 7), 4.3, 5.4, 'FEMALE'],
      ['Female 8-13 years', ageYears(8, 13), 4, 5.2, 'FEMALE'],
      ['Female 14-15 years', ageYears(14, 15), 3.5, 4.9, 'FEMALE'],
      ['Female 16-17 years', ageYears(16, 17), 3.1, 4.7, 'FEMALE'],
      ['Adults', ageYears(18), 2.5, 4.5],
    ],
  }),
  bicarbonate: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'mmol/L',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['Male 1-2 years', ageYears(1, 2), 17, 25, 'MALE'],
      ['Male 3 years', ageYears(3, 3), 18, 26, 'MALE'],
      ['Male 4-5 years', ageYears(4, 5), 19, 27, 'MALE'],
      ['Male 6-7 years', ageYears(6, 7), 20, 28, 'MALE'],
      ['Male 8-17 years', ageYears(8, 17), 21, 29, 'MALE'],
      ['Male adult', ageYears(18), 22, 29, 'MALE'],
      ['Female 1-3 years', ageYears(1, 3), 18, 25, 'FEMALE'],
      ['Female 4-5 years', ageYears(4, 5), 19, 26, 'FEMALE'],
      ['Female 6-7 years', ageYears(6, 7), 20, 27, 'FEMALE'],
      ['Female 8-9 years', ageYears(8, 9), 21, 28, 'FEMALE'],
      ['Female 10 years and older', ageYears(10), 22, 29, 'FEMALE'],
    ],
  }),
  tsh: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'uIU/mL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['0-5 days', ageDays(0, 5), 0.7, 15.2],
      ['6 days-2 months', ageRange(6, 'DAY', 2, 'MONTH'), 0.7, 11],
      ['3-11 months', ageMonths(3, 11), 0.7, 8.4],
      ['1-5 years', ageYears(1, 5), 0.7, 6],
      ['6-10 years', ageYears(6, 10), 0.6, 4.8],
      ['11-19 years', ageYears(11, 19), 0.5, 4.3],
      ['20 years and older', ageYears(20), 0.3, 4.2],
    ],
  }),
  free_t4: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'ng/dL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['0-5 days', ageDays(0, 5), 0.9, 2.5],
      ['6 days-2 months', ageRange(6, 'DAY', 2, 'MONTH'), 0.9, 2.2],
      ['3-11 months', ageMonths(3, 11), 0.9, 2],
      ['1-5 years', ageYears(1, 5), 1, 1.8],
      ['6-10 years', ageYears(6, 10), 1, 1.7],
      ['11-19 years', ageYears(11, 19), 1, 1.6],
      ['20 years and older', ageYears(20), 0.9, 1.7],
    ],
  }),
  ferritin: buildSeries({
    sourceId: 'MAYO_PEDIATRIC_CATALOG_2026',
    unit: 'ng/mL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: MAYO_DETAIL,
    rows: [
      ['Male 0 days-4 weeks', ageRange(0, 'DAY', 4, 'WEEK'), 150, 973, 'MALE'],
      ['Male 5 weeks-5 months', ageRange(5, 'WEEK', 5, 'MONTH'), 9, 580, 'MALE'],
      ['Male 6 months-9 years', ageRange(6, 'MONTH', 9, 'YEAR'), 6, 111, 'MALE'],
      ['Male 10-17 years', ageYears(10, 17), 15, 201, 'MALE'],
      ['Male adult', ageYears(18), 31, 409, 'MALE'],
      ['Female 0 days-4 weeks', ageRange(0, 'DAY', 4, 'WEEK'), 150, 973, 'FEMALE'],
      ['Female 5 weeks-5 months', ageRange(5, 'WEEK', 5, 'MONTH'), 9, 580, 'FEMALE'],
      ['Female 6 months-17 years', ageRange(6, 'MONTH', 17, 'YEAR'), 8, 115, 'FEMALE'],
      ['Female 18-50 years', ageYears(18, 50), 6, 175, 'FEMALE'],
      ['Female 51 years and older', ageYears(51), 11, 328, 'FEMALE'],
    ],
  }),
  serum_iron: buildSeries({
    sourceId: 'MAYO_IRON_PROFILE_2026',
    unit: 'µg/dL',
    method: SOURCE_METHODS.MAYO_ASSAY_TRANSFER,
    sourceDetail: 'Fasting morning specimen preferred; method-dependent; verify locally',
    rows: [
      ['Male birth-1 month', ageMonths(0, 0), 100, 250, 'MALE'],
      ['Male 1 month-11 years', ageRange(1, 'MONTH', 11, 'YEAR'), 50, 120, 'MALE'],
      ['Male 12 years and older', ageYears(12), 50, 150, 'MALE'],
      ['Female birth-1 month', ageMonths(0, 0), 100, 250, 'FEMALE'],
      ['Female 1 month-11 years', ageRange(1, 'MONTH', 11, 'YEAR'), 50, 120, 'FEMALE'],
      ['Female 12 years and older', ageYears(12), 35, 145, 'FEMALE'],
    ],
  }),
});

const UNIT_CONVERSIONS = Object.freeze({
  hemoglobin: { from: 'g/dL', to: 'g/L', factor: 10 },
  white_blood_cell_count: { from: 'x10^9/L', to: '10^3/uL', factor: 1 },
  calcium_total: { from: 'mg/dL', to: 'mmol/L', factor: 0.2495 },
  magnesium: { from: 'mg/dL', to: 'mmol/L', factor: 0.4114 },
  glucose: { from: 'mg/dL', to: 'mmol/L', factor: 1 / 18.0182 },
  creatinine: { from: 'mg/dL', to: 'umol/L', factor: 88.4 },
});

const roundConverted = (value, factor) => {
  if (value == null) return null;
  return Number((Number(value) * factor).toFixed(4));
};

const convertRangeUnit = (entry, conversion) => ({
  ...entry,
  label: entry.label ? `${entry.label} (${conversion.to})` : conversion.to,
  unit: conversion.to,
  normal_min_value: roundConverted(entry.normal_min_value, conversion.factor),
  normal_max_value: roundConverted(entry.normal_max_value, conversion.factor),
  critical_min_value: roundConverted(entry.critical_min_value, conversion.factor),
  critical_max_value: roundConverted(entry.critical_max_value, conversion.factor),
});

const sanitizeLegacyRange = (entry) => ({
  ...entry,
  method: null,
  normal_min_value: null,
  normal_max_value: null,
  critical_min_value: null,
  critical_max_value: null,
  reference_text:
    entry.reference_text
    || 'Automatic numeric interpretation disabled pending a locally verified interval',
  notes: [
    entry.notes,
    compactSourceNote(
      'CLSI_EP28_A3C',
      'Legacy numeric limits disabled; configure an analyser- and population-verified facility interval'
    ),
  ]
    .filter(Boolean)
    .join('. ')
    .slice(0, 255),
  effective_from: entry.effective_from ?? null,
  effective_to: entry.effective_to ?? null,
  version: entry.version ?? 1,
});

const normalizedUnit = (value) => String(value ?? '').trim().toLowerCase();

const rangeHasGenericSelector = (entry, unit) =>
  normalizedUnit(entry.unit) === normalizedUnit(unit)
  && !entry.method
  && !entry.gender
  && entry.age_min_value == null
  && entry.age_max_value == null;

const buildVerificationFallback = (unit) =>
  buildRange({
    sourceId: 'CLSI_EP28_A3C',
    sourceDetail: 'Configure and verify an analyser-, specimen-, age-, sex-, and facility-specific interval',
    label: 'Local verification required',
    unit,
    referenceText: 'No automatic interval for this demographic/unit; use a locally verified laboratory reference interval',
    version: 1,
  });

const applyUgandaReferenceRanges = (test) => {
  if (test.result_kind !== 'NUMERIC') return test;

  const overrides = UGANDA_REFERENCE_RANGE_OVERRIDES[test.key] || [];
  const legacyRanges = test.reference_ranges.map(sanitizeLegacyRange);
  let ranges = [...overrides, ...legacyRanges];

  const conversion = UNIT_CONVERSIONS[test.key];
  if (conversion) {
    const convertedRanges = ranges
      .filter(
        (entry) =>
          normalizedUnit(entry.unit) === normalizedUnit(conversion.from)
          && (
            entry.normal_min_value != null
            || entry.normal_max_value != null
            || entry.critical_min_value != null
            || entry.critical_max_value != null
          )
      )
      .map((entry) => convertRangeUnit(entry, conversion));
    ranges = [...ranges, ...convertedRanges];
  }

  const units = test.unit_options.length > 0
    ? test.unit_options.map((entry) => entry.unit)
    : [test.unit ?? null];
  for (const unit of units) {
    if (!ranges.some((entry) => rangeHasGenericSelector(entry, unit))) {
      ranges.push(buildVerificationFallback(unit));
    }
  }

  return {
    ...test,
    reference_range:
      overrides.length > 0
        ? 'Sourced age-/sex-specific templates require an explicit method match and local verification'
        : 'Automatic numeric interpretation disabled until a local interval is configured',
    reference_ranges: ranges,
  };
};

module.exports = {
  AGE,
  SOURCE_METHODS,
  UGANDA_CLINICAL_SOURCES,
  UGANDA_REFERENCE_RANGE_OVERRIDES,
  applyUgandaReferenceRanges,
};
