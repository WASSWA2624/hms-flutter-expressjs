const {
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
  workspaceQuerySchema,
} = require('../../../../modules/subscriptions-workspace/schemas/subscriptions-workspace.schema');

describe('subscriptions-workspace schemas', () => {
  it('accepts UUID and friendly identifiers in workspace query filters', () => {
    const result = workspaceQuerySchema.safeParse({
      tenant_id: 'TEN0001',
      plan_id: '550e8400-e29b-41d4-a716-446655440000',
      resource: 'subscriptions',
      panel: 'operations',
      search: 'Acme',
    });

    expect(result.success).toBe(true);
  });

  it('validates workspace resource enum values', () => {
    expect(
      workspaceQuerySchema.safeParse({
        panel: 'billing',
        resource: 'subscription-invoices',
      }).success
    ).toBe(true);
    expect(
      workspaceQuerySchema.safeParse({
        panel: 'billing',
        resource: 'unknown-resource',
      }).success
    ).toBe(false);
  });

  it('accepts only supported date preset values', () => {
    expect(
      workspaceQuerySchema.safeParse({
        panel: 'operations',
        resource: 'subscriptions',
        datePreset: 'next_30_days',
      }).success
    ).toBe(true);

    expect(
      workspaceQuerySchema.safeParse({
        panel: 'operations',
        resource: 'subscriptions',
        datePreset: 'last_365_days',
      }).success
    ).toBe(false);
  });

  it('accepts friendly identifiers in reference data filters', () => {
    const result = referenceDataQuerySchema.safeParse({ tenantId: 'TEN0009' });
    expect(result.success).toBe(true);
  });

  it('validates resolve legacy params contract', () => {
    const result = resolveLegacyParamsSchema.safeParse({
      resource: 'subscriptions',
      id: 'SUB0100',
    });
    expect(result.success).toBe(true);
  });
});
