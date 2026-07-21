const {
  evaluateLabResult,
  isRangeEffectiveAt,
  selectReferenceRange} = require('@services/lab-workspace/lab.interpretation');

describe('lab.interpretation', () => {
  const adultFemale = {
    gender: 'FEMALE',
    date_of_birth: new Date('1994-06-01T00:00:00.000Z')};

  const potassiumTest = {
    unit: 'mg/dL',
    reference_ranges: [
      {
        id: 'range-adult-v1',
        label: 'Adult v1',
        unit: 'mg/dL',
        age_min_value: 18,
        age_min_unit: 'YEAR',
        normal_min_value: '3.5',
        normal_max_value: '5.1',
        critical_min_value: '2.5',
        critical_max_value: '6.5',
        version: 1,
        sort_order: 0,
        effective_from: '2020-01-01T00:00:00.000Z',
        effective_to: '2025-12-31T23:59:59.000Z'},
      {
        id: 'range-adult-v2',
        label: 'Adult v2',
        unit: 'mg/dL',
        method: 'ISE',
        age_min_value: 18,
        age_min_unit: 'YEAR',
        normal_min_value: '3.6',
        normal_max_value: '5.2',
        critical_min_value: '2.6',
        critical_max_value: '6.4',
        version: 2,
        sort_order: 1,
        effective_from: '2026-01-01T00:00:00.000Z'}],
    unit_options: [{ unit: 'mg/dL', is_default: true }],
    result_options: []};

  it('selects effective-dated method-aware ranges and snapshots exact applied bounds', () => {
    const interpretation = evaluateLabResult({
      test: potassiumTest,
      patient: adultFemale,
      resultValue: '6.8',
      resultUnit: 'mg/dL',
      method: 'ISE',
      at: new Date('2026-07-15T00:00:00.000Z')});

    expect(interpretation.status).toBe('CRITICAL');
    expect(interpretation.result_flag).toBe('CRITICAL_HIGH');
    expect(interpretation.reference_range_label).toBe('Adult v2');
    expect(interpretation.applied_reference_range_id).toBe('range-adult-v2');
    expect(interpretation.applied_reference_range_json).toEqual(
      expect.objectContaining({
        id: 'range-adult-v2',
        label: 'Adult v2',
        unit: 'mg/dL',
        method: 'ISE',
        normal_min_value: '3.6000',
        normal_max_value: '5.2000',
        critical_min_value: '2.6000',
        critical_max_value: '6.4000',
        version: 2,
        source: 'APPLIED_RULE'})
    );
  });

  it('ignores expired catalog ranges so historical effective windows stay reproducible', () => {
    const matched = selectReferenceRange(
      potassiumTest,
      adultFemale,
      'mg/dL',
      { at: new Date('2024-06-01T00:00:00.000Z') }
    );
    expect(matched?.id).toBe('range-adult-v1');
    expect(isRangeEffectiveAt(potassiumTest.reference_ranges[0], new Date('2026-07-15'))).toBe(
      false
    );
  });

  it('does not match method-specific ranges when method is omitted', () => {
    const matched = selectReferenceRange(
      potassiumTest,
      adultFemale,
      'mg/dL',
      { method: null, at: new Date('2026-07-15T00:00:00.000Z') }
    );
    expect(matched).toBeNull();
  });
});
