const {
  checkSupplierDuplicates,
  compositeSimilarityScore,
} = require('@lib/supplier/supplier-similarity');

describe('supplier-similarity', () => {
  const existing = [
    {
      id: 'sup-1',
      human_friendly_id: 'SUP0001',
      tenant_id: 'tenant-1',
      name: 'DemoCare Medical Supplies Ltd',
      contact_email: 'supplies@hms-demo.test',
      phone: '+15550110000',
      addresses: [{ line1: '12 Industrial Close, Kampala' }],
    },
  ];

  it('weights name more heavily than location', () => {
    const nameHeavy = compositeSimilarityScore({
      nameScore: 100,
      locationScore: 0,
    });
    const locationHeavy = compositeSimilarityScore({
      nameScore: 0,
      locationScore: 100,
    });
    expect(nameHeavy).toBeGreaterThan(locationHeavy);
  });

  it('flags exact name conflicts', () => {
    const result = checkSupplierDuplicates({
      name: 'DemoCare Medical Supplies Ltd',
      existing,
    });
    expect(result.exactNameConflict).toBe(true);
    expect(result.similarMatches[0].is_exact).toBe(true);
  });

  it('flags near name matches', () => {
    const result = checkSupplierDuplicates({
      name: 'DemoCare Medical Supplies',
      existing,
    });
    expect(result.exactNameConflict).toBe(false);
    expect(result.similarMatches.length).toBeGreaterThan(0);
    expect(result.closestScore).toBeGreaterThanOrEqual(70);
  });

  it('flags exact email conflicts', () => {
    const result = checkSupplierDuplicates({
      name: 'Other Supplier',
      contactEmail: 'supplies@hms-demo.test',
      existing,
    });
    expect(result.exactEmailConflict).toBe(true);
  });

  it('excludes the supplier under edit', () => {
    const result = checkSupplierDuplicates({
      name: 'DemoCare Medical Supplies Ltd',
      existing,
      excludeSupplierId: 'sup-1',
    });
    expect(result.similarMatches).toHaveLength(0);
  });
});
