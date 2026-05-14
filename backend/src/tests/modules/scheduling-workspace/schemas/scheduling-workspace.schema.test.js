const {
  workspaceQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
} = require('@validations/scheduling-workspace/scheduling-workspace.schema');

describe('scheduling-workspace schemas', () => {
  it('accepts friendly identifiers in workspace query', () => {
    const result = workspaceQuerySchema.safeParse({
      tenant_id: 'TEN0001',
      facility_id: 'FAC0007',
      provider_user_id: 'USR0011',
      date: '2026-03-03',
      panel: 'queue',
    });
    expect(result.success).toBe(true);
  });

  it('validates queue filters', () => {
    expect(workspaceQuerySchema.safeParse({ queue: 'WAITING_QUEUE' }).success).toBe(true);
    expect(workspaceQuerySchema.safeParse({ queue: 'UNKNOWN' }).success).toBe(false);
  });

  it('accepts reference-data lookup filters', () => {
    const result = referenceDataQuerySchema.safeParse({
      facility_id: 'FAC0003',
      search: 'Dr Kato',
    });
    expect(result.success).toBe(true);
  });

  it('validates resolve-legacy params', () => {
    expect(
      resolveLegacyParamsSchema.safeParse({
        resource: 'appointments',
        id: 'APT0021',
      }).success
    ).toBe(true);
  });
});
