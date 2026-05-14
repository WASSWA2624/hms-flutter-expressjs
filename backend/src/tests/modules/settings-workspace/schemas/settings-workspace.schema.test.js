const {
  referenceDataQuerySchema,
  workspaceQuerySchema,
} = require('../../../../modules/settings-workspace/schemas/settings-workspace.schema');

describe('settings-workspace schemas', () => {
  it('accepts workspace filters with friendly identifiers', () => {
    const result = workspaceQuerySchema.safeParse({
      tenant_id: 'TEN0001',
      facility_id: 'FAC0001',
      group: 'organization',
      search: 'ward',
      state: 'configured',
      actionable_only: 'false',
    });

    expect(result.success).toBe(true);
  });

  it('rejects unsupported group filters', () => {
    const result = workspaceQuerySchema.safeParse({ group: 'unknown-group' });
    expect(result.success).toBe(false);
  });

  it('accepts UUID or friendly identifiers for reference filters', () => {
    const result = referenceDataQuerySchema.safeParse({
      tenantId: '550e8400-e29b-41d4-a716-446655440000',
      facilityId: 'FAC0010',
    });

    expect(result.success).toBe(true);
  });
});
