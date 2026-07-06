/**
 * Facility radiology catalog merge tests
 */

const {
  mapMergedRadiologyTestRecord,
  mapClinicalCatalogRadiologyTestRow,
} = require('@services/radiology-workspace/facility-radiology-catalog.merge');

describe('facility-radiology-catalog.merge', () => {
  const masterTest = {
    id: 'uuid-1',
    human_friendly_id: 'RAD0000001',
    name: 'Chest X-Ray',
    code: 'CXR',
    modality: 'XRAY',
    unit_price: 10000,
    currency: 'UGX',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const offering = {
    id: 'offering-1',
    is_active: true,
    sort_order: 0,
    unit_price: 25000,
    currency: 'UGX',
  };

  it('maps merged radiology test with facility offering', () => {
    const mapped = mapMergedRadiologyTestRecord(masterTest, offering);
    expect(mapped).toMatchObject({
      name: 'Chest X-Ray',
      code: 'CXR',
      is_offered_at_facility: true,
      facility_offering_id: 'offering-1',
      unit_price: '25000.00',
      currency: 'UGX',
    });
  });

  it('maps clinical catalog row for active offering', () => {
    const mapped = mapClinicalCatalogRadiologyTestRow(masterTest, offering);
    expect(mapped).toMatchObject({
      term_type: 'RADIOLOGY_TEST',
      source: 'FACILITY',
      origin: 'FACILITY_RADIOLOGY_CATALOG',
      unit_price: '25000.00',
    });
  });
});
