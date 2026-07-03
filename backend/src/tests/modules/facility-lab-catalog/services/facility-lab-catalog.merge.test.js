const {
  mergeLabTestWithOffering,
  mapMergedLabTestRecord,
} = require('@services/lab-workspace/facility-lab-catalog.merge');

describe('facility-lab-catalog.merge', () => {
  const masterTest = {
    id: 'test-1',
    name: 'CBC',
    code: 'CBC',
    unit: '10^9/L',
    reference_ranges: [{ id: 'range-1', normal_min_value: 4, normal_max_value: 11 }],
    unit_options: [{ unit: '10^9/L', is_default: true }],
    result_options: [],
    unit_price: 10,
    currency: 'UGX',
  };

  it('returns null when offering is inactive', () => {
    expect(
      mergeLabTestWithOffering(masterTest, { is_active: false, unit_price: 20 })
    ).toBeNull();
  });

  it('merges facility price and override ranges', () => {
    const offering = {
      id: 'offering-1',
      is_active: true,
      unit_price: 25,
      currency: 'UGX',
      reference_ranges: [{ id: 'facility-range', normal_min_value: 3, normal_max_value: 9 }],
      unit_options: [],
      result_options: [],
    };

    const merged = mergeLabTestWithOffering(masterTest, offering);
    expect(merged.unit_price).toBe(25);
    expect(merged.reference_ranges).toHaveLength(1);
    expect(merged.reference_ranges[0].id).toBe('facility-range');
  });

  it('maps merged catalog record with offering metadata', () => {
    const mapped = mapMergedLabTestRecord(masterTest, {
      id: 'offering-1',
      is_active: true,
      unit_price: 30,
      reference_ranges: [],
      unit_options: [],
      result_options: [],
    });

    expect(mapped.is_offered_at_facility).toBe(true);
    expect(mapped.facility_offering_id).toBe('offering-1');
    expect(mapped.unit_price).toBe('30.00');
  });
});
