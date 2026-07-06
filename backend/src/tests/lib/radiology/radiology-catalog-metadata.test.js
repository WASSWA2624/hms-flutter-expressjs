/**
 * Radiology catalog metadata tests
 */

const {
  inferBodyRegionFromName,
  resolveRadiologyBodyRegion,
  buildRadiologyCatalogMetadata,
  isNonBodyRegionToken,
} = require('@lib/radiology/radiology-catalog-metadata');

describe('radiology-catalog-metadata', () => {
  it('rejects catalog source tokens as body regions', () => {
    expect(isNonBodyRegionToken('FACILITY')).toBe(true);
    expect(isNonBodyRegionToken('GLOBAL')).toBe(true);
    expect(resolveRadiologyBodyRegion({ body_region: 'FACILITY' })).toBeNull();
  });

  it('infers pelvis from pelvic ultrasound names', () => {
    expect(inferBodyRegionFromName('Transvaginal Pelvic Ultrasound')).toBe('Pelvis');
    expect(
      buildRadiologyCatalogMetadata({
        name: 'Transvaginal Pelvic Ultrasound',
        modality: 'ULTRASOUND',
      }).body_region,
    ).toBe('Pelvis');
  });

  it('prefers stored body region when valid', () => {
    expect(
      resolveRadiologyBodyRegion({
        name: 'Chest X-Ray',
        body_region: 'Chest',
      }),
    ).toBe('Chest');
  });
});
