const {
  filterAuthorizedSections,
  isSectionAuthorized,
  listAuthorizedSectionDefs,
  REPORT_TYPES,
} = require('@lib/patient-reports/sections');
const { PERMISSIONS } = require('@config/permissions');

describe('patient-reports sections catalog', () => {
  test('authorizes clinical sections by permission', () => {
    expect(
      isSectionAuthorized('laboratory_results', [PERMISSIONS.LAB_READ])
    ).toBe(true);
    expect(
      isSectionAuthorized('laboratory_results', [PERMISSIONS.PATIENT_READ])
    ).toBe(false);
    expect(
      isSectionAuthorized('billing_information', [PERMISSIONS.BILLING_READ])
    ).toBe(true);
  });

  test('filters unauthorized sections from selection', () => {
    const selected = filterAuthorizedSections(
      ['patient_information', 'laboratory_results', 'billing_information'],
      [PERMISSIONS.PATIENT_READ, PERMISSIONS.LAB_READ]
    );

    expect(selected).toEqual(['patient_information', 'laboratory_results']);
  });

  test('lists only authorized section definitions', () => {
    const defs = listAuthorizedSectionDefs([PERMISSIONS.PATIENT_READ]);
    const ids = defs.map((entry) => entry.id);

    expect(ids).toContain('patient_information');
    expect(ids).toContain('appointments');
    expect(ids).not.toContain('laboratory_results');
    expect(ids).not.toContain('radiology_reports');
    expect(REPORT_TYPES.PATIENT_CLINICAL).toBe('patient_clinical');
  });
});
