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
  SOURCE_METHODS,
} = require('../../../scripts/seeders/data/uganda-lab-reference-ranges');
const {
  assertLabCatalogIntegrity,
} = require('../../../scripts/seeders/data/catalog-validation');
const {
  selectReferenceRange,
} = require('../../modules/lab-workspace/services/lab.interpretation');

const REFERENCE_DATE = new Date('2026-01-01T12:00:00.000Z');
const AGE_UNIT_DAYS = {
  DAY: 1,
  WEEK: 7,
  MONTH: 30.4375,
  YEAR: 365.25,
};

const getTest = (key) => {
  const test = LAB_TEST_CATALOG.find((entry) => entry.key === key);
  if (!test) throw new Error(`Missing test fixture: ${key}`);
  return test;
};

const birthDateAtAge = ({ years = 0, months = 0, days = 0 }) => {
  const birthDate = new Date(REFERENCE_DATE);
  birthDate.setUTCFullYear(birthDate.getUTCFullYear() - years);
  birthDate.setUTCMonth(birthDate.getUTCMonth() - months);
  birthDate.setUTCDate(birthDate.getUTCDate() - days);
  return birthDate;
};

const selectForAge = (
  key,
  age,
  gender,
  { unit = null, method = null } = {}
) => {
  const test = getTest(key);
  return selectReferenceRange(
    test,
    {
      date_of_birth: birthDateAtAge(age),
      gender,
    },
    unit || test.unit,
    { at: REFERENCE_DATE, method }
  );
};

const rangeAgeInDays = (range, bound, fallback) => {
  const value = range[`age_${bound}_value`];
  const unit = range[`age_${bound}_unit`];
  if (value == null) return fallback;
  return Number(value) * AGE_UNIT_DAYS[unit];
};

const expectBounds = (range, minimum, maximum) => {
  expect(Number(range?.normal_min_value)).toBeCloseTo(minimum, 4);
  expect(Number(range?.normal_max_value)).toBeCloseTo(maximum, 4);
};

const buildNumericFixture = (referenceRange) => ({
  key: 'fixture_test',
  name: 'Fixture Test',
  code: 'FIXTURE',
  result_kind: 'NUMERIC',
  unit: 'mg/dL',
  unit_options: [{ unit: 'mg/dL', is_default: true }],
  reference_ranges: [referenceRange],
  result_options: [],
});

const fixturePanel = {
  key: 'fixture_panel',
  name: 'Fixture Panel',
  code: 'FIX-PNL',
  test_keys: ['fixture_test'],
};

describe('Uganda clinical catalog seed data', () => {
  it('ships a broad Uganda laboratory menu with valid panel references', () => {
    expect(LAB_TEST_CATALOG.length).toBeGreaterThanOrEqual(147);
    expect(LAB_PANEL_CATALOG.length).toBeGreaterThanOrEqual(100);

    const keys = new Set(LAB_TEST_CATALOG.map((entry) => entry.key));
    expect([...keys]).toEqual(
      expect.arrayContaining([
        'urea',
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
        'treponema_pallidum_antibody',
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
      expect(test.reference_ranges.length).toBeLessThanOrEqual(25);
      expect(test.reference_ranges.every((range) => Boolean(range.notes))).toBe(true);
    }
  });

  it('rejects malformed numeric and reversed-age reference ranges', () => {
    expect(() =>
      assertLabCatalogIntegrity({
        tests: [
          buildNumericFixture({
            unit: 'mg/dL',
            age_min_value: 10,
            age_min_unit: 'YEAR',
            age_max_value: 5,
            age_max_unit: 'YEAR',
            normal_min_value: 1,
            normal_max_value: 2,
          }),
        ],
        panels: [fixturePanel],
      })
    ).toThrow(/minimum age/i);

    expect(() =>
      assertLabCatalogIntegrity({
        tests: [
          buildNumericFixture({
            unit: 'mg/dL',
            normal_min_value: 'not-a-number',
            normal_max_value: 2,
          }),
        ],
        panels: [fixturePanel],
      })
    ).toThrow(/finite number/i);
  });

  it('does not overlap active numeric age/sex templates for the same test and unit', () => {
    for (const test of LAB_TEST_CATALOG) {
      const active = test.reference_ranges.filter(
        (range) =>
          range.normal_min_value != null
          || range.normal_max_value != null
          || range.critical_min_value != null
          || range.critical_max_value != null
      );
      expect(active.every((range) => Boolean(range.method))).toBe(true);

      for (let leftIndex = 0; leftIndex < active.length; leftIndex += 1) {
        for (let rightIndex = leftIndex + 1; rightIndex < active.length; rightIndex += 1) {
          const left = active[leftIndex];
          const right = active[rightIndex];
          if (left.unit !== right.unit || left.method !== right.method) continue;
          if (left.gender && right.gender && left.gender !== right.gender) continue;

          const leftMin = rangeAgeInDays(left, 'min', Number.NEGATIVE_INFINITY);
          const leftMax = rangeAgeInDays(left, 'max', Number.POSITIVE_INFINITY);
          const rightMin = rangeAgeInDays(right, 'min', Number.NEGATIVE_INFINITY);
          const rightMax = rangeAgeInDays(right, 'max', Number.POSITIVE_INFINITY);
          expect(
            Math.max(leftMin, rightMin) <= Math.min(leftMax, rightMax)
          ).toBe(false);
        }
      }
    }
  });

  it('selects method-gated Ugandan haemoglobin templates by age, sex, and unit', () => {
    const method = SOURCE_METHODS.LUGADA_ACT5DIFF_NONPREGNANT;
    expectBounds(selectForAge('hemoglobin', { months: 6 }, 'FEMALE', { method }), 6.8, 14.7);
    expectBounds(selectForAge('hemoglobin', { years: 3 }, 'MALE', { method }), 8.8, 12.5);
    expectBounds(selectForAge('hemoglobin', { years: 8 }, 'FEMALE', { method }), 10, 13.7);
    expectBounds(selectForAge('hemoglobin', { years: 13 }, 'MALE', { method }), 11.2, 15.9);
    expectBounds(selectForAge('hemoglobin', { years: 13 }, 'FEMALE', { method }), 9.9, 14.5);
    expectBounds(selectForAge('hemoglobin', { years: 30 }, 'MALE', { method }), 11.1, 16.8);
    expectBounds(selectForAge('hemoglobin', { years: 30 }, 'FEMALE', { method }), 10.1, 14.3);
    expectBounds(
      selectForAge('hemoglobin', { years: 30 }, 'MALE', { method, unit: 'g/L' }),
      111,
      168
    );

    const newborn = selectForAge('hemoglobin', { days: 3 }, 'MALE', { method });
    expect(newborn.reference_text).toMatch(/locally verified/i);
    expect(newborn.normal_min_value).toBeNull();
  });

  it('changes year-based bands on the calendar birthday rather than after 365-day approximations', () => {
    const test = getTest('hemoglobin');
    const patient = {
      date_of_birth: new Date('2013-07-10T00:00:00.000Z'),
      gender: 'FEMALE',
    };
    const options = {
      method: SOURCE_METHODS.LUGADA_ACT5DIFF_NONPREGNANT,
    };

    const beforeBirthday = selectReferenceRange(
      test,
      patient,
      'g/dL',
      { ...options, at: new Date('2026-07-09T12:00:00.000Z') }
    );
    const onBirthday = selectReferenceRange(
      test,
      patient,
      'g/dL',
      { ...options, at: new Date('2026-07-10T12:00:00.000Z') }
    );

    expect(beforeBirthday.label).toBe('6-12 years');
    expect(onBirthday.label).toBe('Female 13-18 years');
  });

  it('selects local Ugandan child and young-adult chemistry intervals', () => {
    expectBounds(
      selectForAge('creatinine', { years: 3 }, 'FEMALE', {
        method: SOURCE_METHODS.KIRONDE_COBAS_INTEGRA,
      }),
      0.18,
      0.38
    );
    expectBounds(
      selectForAge('creatinine', { years: 10 }, 'MALE', {
        method: SOURCE_METHODS.PALACPAC_COBAS_C111,
      }),
      0.31,
      0.61
    );
    expectBounds(
      selectForAge('creatinine', { years: 20 }, 'FEMALE', {
        method: SOURCE_METHODS.PALACPAC_COBAS_C111,
      }),
      0.43,
      0.92
    );
    expectBounds(
      selectForAge('urea', { years: 3 }, 'MALE', {
        method: SOURCE_METHODS.KIRONDE_COBAS_INTEGRA,
      }),
      0.8,
      3.8
    );
    expectBounds(
      selectForAge('sodium', { years: 10 }, 'FEMALE', {
        method: SOURCE_METHODS.PALACPAC_COBAS_C111,
      }),
      134.2,
      141
    );
    expectBounds(
      selectForAge('potassium', { years: 20 }, 'MALE', {
        method: SOURCE_METHODS.PALACPAC_COBAS_C111,
      }),
      3.58,
      5.02
    );

    expectBounds(
      selectForAge('creatinine', { years: 5 }, 'FEMALE', {
        method: SOURCE_METHODS.KIRONDE_COBAS_INTEGRA,
      }),
      0.18,
      0.38
    );
    const outsideKirondeCohort = selectForAge(
      'creatinine',
      { years: 5, months: 1 },
      'FEMALE',
      { method: SOURCE_METHODS.KIRONDE_COBAS_INTEGRA }
    );
    expect(outsideKirondeCohort.normal_min_value).toBeNull();
  });

  it('uses age- and sex-specific pediatric intervals where local data are unavailable', () => {
    const method = SOURCE_METHODS.MAYO_ASSAY_TRANSFER;
    expectBounds(selectForAge('tsh', { days: 3 }, 'FEMALE', { method }), 0.7, 15.2);
    expectBounds(selectForAge('free_t4', { years: 8 }, 'MALE', { method }), 1, 1.7);
    expectBounds(selectForAge('magnesium', { years: 10 }, 'FEMALE', { method }), 1.6, 2.4);
    expectBounds(selectForAge('phosphate', { years: 10 }, 'MALE', { method }), 3.7, 5.4);
    expectBounds(selectForAge('phosphate', { years: 10 }, 'FEMALE', { method }), 4, 5.2);
    expectBounds(selectForAge('ferritin', { years: 15 }, 'MALE', { method }), 15, 201);
    expectBounds(selectForAge('ferritin', { years: 15 }, 'FEMALE', { method }), 8, 115);
  });

  it('does not auto-apply template intervals or seed facility critical-call limits', () => {
    for (const test of LAB_TEST_CATALOG.filter((entry) => entry.result_kind === 'NUMERIC')) {
      for (const gender of ['MALE', 'FEMALE']) {
        const selected = selectForAge(test.key, { years: 30 }, gender);
        expect(selected).not.toBeNull();
        expect(selected.normal_min_value).toBeNull();
        expect(selected.normal_max_value).toBeNull();
        expect(selected.critical_min_value).toBeNull();
        expect(selected.critical_max_value).toBeNull();
      }
    }

    const criticalRanges = LAB_TEST_CATALOG.flatMap((test) =>
      test.reference_ranges.filter(
        (range) =>
          range.critical_min_value != null || range.critical_max_value != null
      )
    );
    expect(criticalRanges).toEqual([]);
  });

  it('covers Uganda-priority diagnoses with unique WHO ICD-10 codes', () => {
    expect(UGANDA_DIAGNOSIS_CATALOG.length).toBeGreaterThanOrEqual(180);
    const byKey = Object.fromEntries(
      UGANDA_DIAGNOSIS_CATALOG.map((entry) => [entry.key, entry])
    );

    expect(byKey.diabetic_ketoacidosis.code).toBe('E10.1');
    expect(byKey.type_2_diabetic_ketoacidosis.code).toBe('E11.1');
    expect(byKey.dengue_fever.code).toBe('A97.9');
    expect(byKey.endomyocardial_fibrosis.code).toBe('I42.3');
    expect(byKey.allergic_rhinitis.code).toBe('J30.4');
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
        'MAYO_IRON_PROFILE_2026',
        'CLSI_EP28_A3C',
      ])
    );
  });
});
