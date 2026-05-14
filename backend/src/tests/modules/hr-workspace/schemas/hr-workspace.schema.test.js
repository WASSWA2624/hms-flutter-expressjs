const {
  workspaceQuerySchema,
  workItemsQuerySchema,
  rosterIdentifierParamsSchema,
  rosterGenerateSchema,
  rosterPublishSchema,
  shiftOverrideSchema,
  resolveLegacyParamsSchema,
} = require('@validations/hr-workspace/hr-workspace.schema');

describe('hr-workspace schemas', () => {
  it('accepts UUID and friendly identifiers in workspace query filters', () => {
    const result = workspaceQuerySchema.safeParse({
      facility_id: 'FAC1234',
      department_id: '550e8400-e29b-41d4-a716-446655440000',
      search: 'night shift',
    });
    expect(result.success).toBe(true);
  });

  it('validates work-items queue enum values', () => {
    expect(workItemsQuerySchema.safeParse({ queue: 'UNASSIGNED_SHIFTS' }).success).toBe(true);
    expect(workItemsQuerySchema.safeParse({ queue: 'UNKNOWN_QUEUE' }).success).toBe(false);
  });

  it('accepts friendly roster identifier in params', () => {
    const result = rosterIdentifierParamsSchema.safeParse({ rosterIdentifier: 'NR000120' });
    expect(result.success).toBe(true);
  });

  it('applies roster generation defaults', () => {
    const result = rosterGenerateSchema.safeParse({});
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.replace_existing_assignments).toBe(true);
      expect(result.data.dry_run).toBe(false);
    }
  });

  it('requires publish_note when allow_partial_publish is true to be validated downstream', () => {
    const valid = rosterPublishSchema.safeParse({
      allow_partial_publish: true,
      publish_note: 'Coverage gap acknowledged',
    });
    expect(valid.success).toBe(true);
  });

  it('validates shift override payload with friendly staff identifier', () => {
    const result = shiftOverrideSchema.safeParse({
      staff_profile_id: 'SPF0012',
      reason: 'Emergency backfill',
    });
    expect(result.success).toBe(true);
  });

  it('validates resolve legacy resource contract', () => {
    expect(
      resolveLegacyParamsSchema.safeParse({
        resource: 'shift-assignments',
        id: 'SAS0233',
      }).success
    ).toBe(true);
  });
});
