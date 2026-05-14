const {
  lookupsQuerySchema,
  workspaceQuerySchema,
} = require('../../../../modules/dashboard-workspace/schemas/dashboard-workspace.schema');

describe('dashboard-workspace schemas', () => {
  it('accepts friendly identifiers in workspace filters', () => {
    const result = workspaceQuerySchema.safeParse({
      panel: 'queue',
      tenantId: 'TEN0001',
      facility_id: 'FAC0001',
      branchId: 'BR0001',
      queue: 'appointments',
      datePreset: 'last_7_days',
    });

    expect(result.success).toBe(true);
  });

  it('rejects unsupported dashboard panels', () => {
    expect(
      workspaceQuerySchema.safeParse({
        panel: 'unsupported-panel',
      }).success
    ).toBe(false);
  });

  it('accepts friendly identifiers in lookups filters', () => {
    const result = lookupsQuerySchema.safeParse({
      tenant_id: 'TEN0009',
      facilityId: 'FAC0012',
    });

    expect(result.success).toBe(true);
  });
});
