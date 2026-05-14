const {
  listTheatreFlowsQuerySchema,
  theatreCaseIdParamsSchema,
  startTheatreFlowSchema,
  assignResourceSchema,
  reopenRecordSchema,
} = require('@validations/theatre-flow/theatre-flow.schema');

describe('theatre-flow.schema', () => {
  it('validates list query with friendly ids', () => {
    const result = listTheatreFlowsQuerySchema.safeParse({
      tenant_id: 'TEN-001',
      queue_scope: 'ACTIVE',
      finalized: 'true',
      page: '1',
      limit: '20',
    });
    expect(result.success).toBe(true);
  });

  it('rejects invalid id params', () => {
    const result = theatreCaseIdParamsSchema.safeParse({ id: 'x' });
    expect(result.success).toBe(false);
  });

  it('validates start payload', () => {
    const result = startTheatreFlowSchema.safeParse({
      encounter_id: 'ENC-0001',
      workflow_stage: 'PRE_OP',
      status: 'SCHEDULED',
    });
    expect(result.success).toBe(true);
  });

  it('validates assign resource payload', () => {
    const result = assignResourceSchema.safeParse({
      resource_type: 'STAFF',
      resource_id: 'STF-332',
      staff_role: 'ANESTHETIST',
    });
    expect(result.success).toBe(true);
  });

  it('requires reopen reason', () => {
    const result = reopenRecordSchema.safeParse({
      record_type: 'ALL',
      reason: 'x',
    });
    expect(result.success).toBe(false);
  });
});

