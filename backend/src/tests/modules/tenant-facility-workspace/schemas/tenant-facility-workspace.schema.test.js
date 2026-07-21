const { setupQuerySchema } = require('../../../../modules/tenant-facility-workspace/schemas/tenant-facility-workspace.schema');

describe('tenant-facility-workspace schema', () => {
  it('accepts tenant and facility identifiers in setup query', () => {
    const parsed = setupQuerySchema.parse({
      tenantId: 'TEN0001',
      facilityId: 'FAC0001'});

    expect(parsed.tenantId).toBe('TEN0001');
    expect(parsed.facilityId).toBe('FAC0001');
  });

  it('accepts an empty setup query', () => {
    expect(setupQuerySchema.parse({})).toEqual({});
  });
});
