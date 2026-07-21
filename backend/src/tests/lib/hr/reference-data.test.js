const {
  STAFF_POSITION_CATALOG,
  PRACTITIONER_TYPE_CATALOG,
  COMPENSATION_PAY_TYPE_CATALOG,
  DEFAULT_STAFF_POSITION_NAMES,
  PRACTITIONER_TYPE_OPTIONS,
  CONSULTATION_FEE_PRACTITIONER_TYPES,
  practitionerTypeOptions,
  compensationPayTypeOptions,
  staffPositionCatalogOptions,
  staffPositionLabelKeyForName} = require('@lib/hr/reference-data');

describe('hr reference-data constants', () => {
  it('includes a comprehensive global staff position catalog', () => {
    expect(STAFF_POSITION_CATALOG.length).toBeGreaterThanOrEqual(60);
    expect(DEFAULT_STAFF_POSITION_NAMES).toEqual(
      expect.arrayContaining([
        'Nurse',
        'Doctor',
        'Ward Manager',
        'Midwife',
        'Mortuary Attendant',
        'Chief Nursing Officer'])
    );
    for (const entry of STAFF_POSITION_CATALOG) {
      expect(entry.labelKey).toMatch(/^labels\.hr\.reference\.staff_position\./);
    }
  });

  it('exposes expanded practitioner types with localized labels', () => {
    expect(PRACTITIONER_TYPE_CATALOG.length).toBeGreaterThanOrEqual(18);
    expect(PRACTITIONER_TYPE_OPTIONS).toEqual(
      expect.arrayContaining([
        'MO',
        'SPECIALIST',
        'GP',
        'SURGEON',
        'OBGYN',
        'NURSE_PRACTITIONER',
        'ORTHOPAEDIC_SURGEON'])
    );
    const options = practitionerTypeOptions();
    expect(options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'MO',
          label_key: 'labels.hr.reference.practitioner_type.mo',
          label: expect.stringContaining('Medical Officer')})])
    );
  });

  it('defines localized compensation pay types', () => {
    expect(COMPENSATION_PAY_TYPE_CATALOG).toHaveLength(5);
    const options = compensationPayTypeOptions();
    expect(options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'PER_CONSULTATION',
          label_key: 'labels.hr.reference.compensation_pay_type.per_consultation'}),
        expect.objectContaining({
          value: 'PER_MONTH',
          label_key: 'labels.hr.reference.compensation_pay_type.per_month'})])
    );
  });

  it('defines localized leave types and half-day periods', () => {
    const { LEAVE_TYPE_CATALOG, leaveTypeOptions, leaveHalfDayPeriodOptions } = require('@lib/hr/reference-data');
    expect(LEAVE_TYPE_CATALOG.length).toBeGreaterThanOrEqual(9);
    const leaveTypes = leaveTypeOptions();
    expect(leaveTypes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'ANNUAL',
          label_key: 'labels.hr.reference.leave_type.annual'}),
        expect.objectContaining({
          value: 'SICK',
          label_key: 'labels.hr.reference.leave_type.sick'})])
    );
    const halfDayPeriods = leaveHalfDayPeriodOptions();
    expect(halfDayPeriods).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          value: 'MORNING',
          label_key: 'labels.hr.reference.leave_half_day_period.morning'})])
    );
  });

  it('maps known staff position names to label keys', () => {
    expect(staffPositionLabelKeyForName('Nurse')).toBe(
      'labels.hr.reference.staff_position.nurse'
    );
    expect(staffPositionLabelKeyForName('Obstetrician/Gynaecologist')).toBe(
      'labels.hr.reference.staff_position.obgyn'
    );
  });

  it('defines consultation-fee practitioner types', () => {
    expect(CONSULTATION_FEE_PRACTITIONER_TYPES.has('SPECIALIST')).toBe(true);
    expect(CONSULTATION_FEE_PRACTITIONER_TYPES.has('INTERN')).toBe(false);
    expect(CONSULTATION_FEE_PRACTITIONER_TYPES.has('PATHOLOGIST')).toBe(false);
  });

  it('returns localized staff position catalog options', () => {
    const options = staffPositionCatalogOptions();
    expect(options[0]).toEqual(
      expect.objectContaining({
        value: expect.any(String),
        label: expect.any(String),
        label_key: expect.stringMatching(/^labels\.hr\.reference\.staff_position\./)})
    );
  });
});
