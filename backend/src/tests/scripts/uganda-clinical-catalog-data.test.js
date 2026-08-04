const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
} = require('../../../scripts/seeders/data/uganda-lab-catalog');
const {
  RADIOLOGY_TEST_CATALOG,
} = require('../../../scripts/seeders/data/uganda-radiology-catalog');
const {
  UGANDA_DIAGNOSIS_CATALOG,
} = require('../../../scripts/seeders/data/uganda-diagnosis-catalog');
const {
  UGANDA_CLINICAL_SOURCES,
} = require('../../../scripts/seeders/data/uganda-clinical-sources');
const {
  selectReferenceRange,
} = require('../../modules/lab-workspace/services/lab.interpretation');

const DAY_MS = 24 * 60 * 60 * 1000;
const REFERENCE_DATE = new Date('2026-01-01T12:00:00.000Z');

const getTest = (key) => {
  const test = LAB_TEST_CATALOG.find((entry) => entry.key === key);
  if (!test) throw new Error(`Missing test fixture: ${key}`);
  return test;
};

const selectForAge = (key, ageDays, gender, unit = null) => {
  const test = getTest(key);
  return selectReferenceRange(
    test,
    {
      date_of_birth: new Date(REFERENCE_DATE.getTime() - ageDays * DAY_MS),
      gender,
    },
    unit || test.unit,
    { at: REFERENCE_DATE }
  );
};

const expectBounds = (range, minimum, maximum) => {
  expect(Number(range?.normal_min_value)).toBeCloseTo(minimum, 4);
  expect(Number(range?.normal_max_value)).toBeCloseTo(maximum, 4);
};

describe('Uganda clinical catalog seed data', () => {
  it('ships a broad Uganda laboratory menu with valid panel references', () => {
    expect(LAB_TEST_CATALOG.length).toBeGreaterThanOrEqual(146);
    expect(LAB_PANEL_CATALOG.length).toBeGreaterThanOrEqual(100);

    const keys = new Set(LAB_TEST_CATALOG.map((entry) => entry.key));
    expect([...keys]).toEqual(
      expect.arrayContaining([
        'urea',
        'complete_blood_count',
      ].filter((key) => key !== 'complete_blood_count'))
    );
    expect([...keys]).toEqual(
      expect.arrayContaining([
        'hemoglobin',
        'anc',
        'lymphocyte_count',
        'cd4_count',
        'cd8_absolute',
        'fibrinogen',
        'semen_analysis',
        'filaria_microscopy',
        'trypanosoma_microscopy',
        'leishmania_microscopy',
        'skin_snip_onchocerca',
        'hepatitis_a_igm',
        'hepatitis_b_e_antigen',
        'hepatitis_b_core_total_antibody',
        'hbv_viral_load',
      ])
    );
  });

  it('provides a sourced range or safe local-verification fallback for every numeric unit', () => {
    for (const test of LAB_TEST_CATALOG.filter((entry) => entry.result_kind === 'NUMERIC')) {
      const units = test.unit_options.length
        ? test.unit_options.map((entry) => entry.unit)
        : [test.unit];

      for (const unit of units) {
        expect(
          test.reference_ranges.some(
            (range) => String(range.unit ?? '') === String(unit ?? '')
          )
        ).toBe(true);
      }

      expect(test.reference_ranges.length).toBeGreaterThan(0);
      expect(test.reference_ranges.every((range) => Boolean(range.notes))).toBe(true);
    }
  });

  it('does not overlap validated age/sex selectors for the same test and unit', () => {
    for (const test of LAB_TEST_CATALOG) {
      const validated = test.reference_ranges.filter(
        (range) => Number(range.version) >= 2
      );
      for (let leftIndex = 0; leftIndex < validated.length; leftIndex += 1) {
        for (let rightIndex = leftIndex + 1; rightIndex < validated.length; rightIndex += 1) {
          const left = validated[leftIndex];
          const right = validated[rightIndex];
          if (left.unit !== right.unit || left.method !== right.method) continue;
          if (left.gender && right.gender && left.gender !== right.gender) continue;

          const leftMin = left.age_min_value ?? Number.NEGATIVE_INFINITY;
          const leftMax = left.age_max_value ?? Number.POSITIVE_INFINITY;
          const rightMin = right.age_min_value ?? Number.NEGATIVE_INFINITY;
          const rightMax = right.age_max_value ?? Number.POSITIVE_INFINITY;
          expect(
            Math.max(leftMin, rightMin) <= Math.min(leftMax, rightMax)
          ).toBe(false);
        }
      }
    }
  });

  it('selects WHO/Uganda haemoglobin limits by age, sex, and alternate unit', () => {
    expectBounds(selectForAge('hemoglobin', 200, 'FEMALE'), 10.5, 14.7);
    expectBounds(selectForAge('hemoglobin', 3 * 365, 'MALE'), 11, 12.5);
    expectBounds(selectForAge('hemoglobin', 8 * 365, 'FEMALE'), 11.5, 13.7);
    expectBounds(selectForAge('hemoglobin', 13 * 365, 'MALE'), 12, 15.9);
    expectBounds(selectForAge('hemoglobin', 13 * 365, 'FEMALE'), 12, 14.5);
    expectBounds(selectForAge('hemoglobin', 30 * 365, 'MALE'), 13, 16.8);
    expectBounds(selectForAge('hemoglobin', 30 * 365, 'FEMALE'), 12, 14.3);
    expectBounds(selectForAge('hemoglobin', 30 * 365, 'MALE', 'g/L'), 130, 168);

    const olderAdult = selectForAge('hemoglobin', 70 * 365, 'MALE');
    expect(olderAdult.reference_text).toMatch(/locally verified/i);
    expect(olderAdult.normal_min_value).toBeNull();
  });

  it('selects local Ugandan child and young-adult chemistry intervals', () => {
    expectBounds(selectForAge('creatinine', 3 * 365, 'FEMALE'), 0.18, 0.38);
    expectBounds(selectForAge('creatinine', 10 * 365, 'MALE'), 0.31, 0.61);
    expectBounds(selectForAge('creatinine', 20 * 365, 'FEMALE'), 0.43, 0.92);
    expectBounds(selectForAge('urea', 3 * 365, 'MALE'), 0.8, 3.8);
    expectBounds(selectForAge('sodium', 10 * 365, 'FEMALE'), 134.2, 141);
    expectBounds(selectForAge('potassium', 20 * 365, 'MALE'), 3.58, 5.02);
  });

  it('uses age- and sex-specific pediatric intervals where local data are unavailable', () => {
    expectBounds(selectForAge('tsh', 3, 'FEMALE'), 0.7, 15.2);
    expectBounds(selectForAge('free_t4', 8 * 365, 'MALE'), 1, 1.7);
    expectBounds(selectForAge('magnesium', 10 * 365, 'FEMALE'), 1.6, 2.4);
    expectBounds(selectForAge('phosphate', 10 * 365, 'MALE'), 3.7, 5.4);
    expectBounds(selectForAge('phosphate', 10 * 365, 'FEMALE'), 4, 5.2);
    expectBounds(selectForAge('ferritin', 15 * 365, 'MALE'), 15, 201);
    expectBounds(selectForAge('ferritin', 15 * 365, 'FEMALE'), 8, 115);
  });

  it('keeps automatic critical limits restricted to sourced WHO haemoglobin severity cutoffs', () => {
    const criticalRanges = LAB_TEST_CATALOG.flatMap((test) =>
      test.reference_ranges.filter(
        (range) =>
          range.critical_min_value != null || range.critical_max_value != null
      )
    );
    expect(criticalRanges.length).toBeGreaterThan(0);
    expect(
      criticalRanges.every((range) =>
        range.notes.includes('WHO_HAEMOGLOBIN_2024')
      )
    ).toBe(true);
  });

  it('covers Uganda-priority diagnoses with unique WHO ICD-10 codes', () => {
    expect(UGANDA_DIAGNOSIS_CATALOG.length).toBeGreaterThanOrEqual(180);
    const byKey = Object.fromEntries(
      UGANDA_DIAGNOSIS_CATALOG.map((entry) => [entry.key, entry])
    );

    expect(byKey.diabetic_ketoacidosis.code).toBe('E10.1');
    expect(byKey.type_2_diabetic_ketoacidosis.code).toBe('E11.1');
    expect(byKey.road_traffic_injury.description).toMatch(/motor-vehicle traffic/i);
    expect(byKey.malaria_in_pregnancy.description).toMatch(/add B50-B54/i);
    expect(byKey.visceral_leishmaniasis.code).toBe('B55.0');
    expect(byKey.burkitt_lymphoma.code).toBe('C83.7');
  });

  it('covers district-to-referral imaging including pediatric and interventional services', () => {
    expect(RADIOLOGY_TEST_CATALOG.length).toBeGreaterThanOrEqual(140);
    const keys = RADIOLOGY_TEST_CATALOG.map((entry) => entry.key);
    expect(keys).toEqual(
      expect.arrayContaining([
        'uss_neonatal_cranial',
        'uss_pediatric_hip',
        'uss_intussusception',
        'ct_pulmonary_angiogram',
        'ct_triphasic_liver',
        'mri_pituitary',
        'mri_mrcp',
        'mri_rectal_staging',
        'echo_pediatric_congenital',
        'ir_percutaneous_nephrostomy',
        'ir_biliary_drainage',
      ])
    );
  });

  it('exports versioned primary-source metadata for clinical governance', () => {
    expect(Object.keys(UGANDA_CLINICAL_SOURCES)).toEqual(
      expect.arrayContaining([
        'UG_MOH_UCG_2023',
        'UG_MOH_LAB_MENU_2017',
        'WHO_ICD10_2019',
        'WHO_HAEMOGLOBIN_2024',
        'LUGADA_UGANDA_2004',
        'KIRONDE_UGANDA_2013',
        'PALACPAC_UGANDA_2014',
        'CLSI_EP28_A3C',
      ])
    );
  });
});
