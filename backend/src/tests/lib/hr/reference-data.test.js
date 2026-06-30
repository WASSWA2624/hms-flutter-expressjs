const {
  DEFAULT_STAFF_POSITION_NAMES,
  PRACTITIONER_TYPE_OPTIONS,
  CONSULTATION_FEE_PRACTITIONER_TYPES,
  practitionerTypeOptions,
} = require('@lib/hr/reference-data');

describe('hr reference-data constants', () => {
  it('includes a broad global staff position catalog', () => {
    expect(DEFAULT_STAFF_POSITION_NAMES).toEqual(
      expect.arrayContaining([
        'Nurse',
        'Doctor',
        'Ward Manager',
        'Midwife',
        'Mortuary Attendant',
      ])
    );
    expect(DEFAULT_STAFF_POSITION_NAMES.length).toBeGreaterThanOrEqual(20);
  });

  it('exposes expanded practitioner types with labels', () => {
    expect(PRACTITIONER_TYPE_OPTIONS).toEqual(
      expect.arrayContaining(['MO', 'SPECIALIST', 'GP', 'SURGEON', 'OBGYN'])
    );
    const options = practitionerTypeOptions();
    expect(options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ value: 'MO', label: expect.stringContaining('Medical Officer') }),
        expect.objectContaining({ value: 'GP', label: expect.stringContaining('General Practitioner') }),
      ])
    );
  });

  it('defines consultation-fee practitioner types', () => {
    expect(CONSULTATION_FEE_PRACTITIONER_TYPES.has('SPECIALIST')).toBe(true);
    expect(CONSULTATION_FEE_PRACTITIONER_TYPES.has('INTERN')).toBe(false);
  });
});
