const {
  collectLabOrderSchema,
  getLabWorkbenchQuerySchema,
  orderItemWorkflowParamsSchema,
  orderWorkflowParamsSchema,
  receiveLabSampleSchema,
  rejectLabSampleSchema,
  releaseLabOrderItemSchema,
  reverseLabOrderWorkflowSchema,
  sampleWorkflowParamsSchema,
} = require('@validations/lab-workspace/lab-workspace.schema');

describe('lab-workspace schemas', () => {
  it('accepts valid workbench filters', () => {
    const result = getLabWorkbenchQuerySchema.safeParse({
      page: '1',
      limit: '25',
      stage: 'RESULTS',
      status: 'IN_PROCESS',
      criticality: 'CRITICAL',
      from: '2026-03-01T00:00:00.000Z',
      to: '2026-03-31T23:59:59.000Z',
      patient_id: 'PAT000001',
      encounter_id: 'ENC000001',
      search: 'CBC',
    });

    expect(result.success).toBe(true);
  });

  it('rejects invalid workbench filters', () => {
    expect(
      getLabWorkbenchQuerySchema.safeParse({
        stage: 'UNKNOWN',
        criticality: 'SEVERE',
      }).success
    ).toBe(false);
  });

  it('accepts friendly identifiers in workflow params', () => {
    expect(orderWorkflowParamsSchema.safeParse({ id: 'LAB000001' }).success).toBe(true);
    expect(sampleWorkflowParamsSchema.safeParse({ id: 'LSP000001' }).success).toBe(true);
    expect(orderItemWorkflowParamsSchema.safeParse({ id: 'LIT000001' }).success).toBe(true);
  });

  it('validates workflow mutation payloads', () => {
    expect(
      collectLabOrderSchema.safeParse({
        sample_id: 'LSP000001',
        collected_at: '2026-03-11T08:30:00.000Z',
        notes: 'Collected from OPD',
      }).success
    ).toBe(true);

    expect(
      receiveLabSampleSchema.safeParse({
        received_at: '2026-03-11T08:45:00.000Z',
      }).success
    ).toBe(true);

    expect(
      rejectLabSampleSchema.safeParse({
        reason: 'Hemolysed specimen',
        notes: 'Request recollection',
      }).success
    ).toBe(true);

    expect(
      releaseLabOrderItemSchema.safeParse({
        result_id: 'LRS000001',
        status: 'CRITICAL',
        result_value: '12.8',
        result_unit: 'mg/dL',
        result_text: 'Critical potassium level',
        reported_at: '2026-03-11T09:30:00.000Z',
      }).success
    ).toBe(true);

    expect(
      reverseLabOrderWorkflowSchema.safeParse({
        reason: 'Released by mistake',
      }).success
    ).toBe(true);
  });
});
