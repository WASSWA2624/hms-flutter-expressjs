const {
  createRadiologyOrderSchema,
} = require('@validations/radiology-workspace/radiology-workspace.schema');

describe('radiology-workspace.schema createRadiologyOrderSchema', () => {
  const basePayload = {
    patient_id: 'PAT0000001',
    encounter_id: 'ENC0000001',
    ordered_at: '2026-02-27T10:20:00.000Z',
  };

  it('accepts a multi-test imaging request with per-test notes and details', () => {
    const result = createRadiologyOrderSchema.safeParse({
      ...basePayload,
      notes: 'Shared note',
      requested_tests: [
        {
          radiology_test_id: 'RADT000001',
          clinical_note: 'Chest pain',
          request_details: {
            modality: 'XRAY',
            body_region: 'Chest',
            laterality: 'LEFT',
            priority: 'URGENT',
          },
        },
        {
          radiology_test_id: 'STD_RAD_TEST_RAD-00002',
          request_details: {
            modality: 'CT',
            body_region: 'Head',
            priority: 'STAT',
          },
        },
      ],
    });

    expect(result.success).toBe(true);
  });

  it('keeps legacy single radiology_test_id payloads valid', () => {
    const result = createRadiologyOrderSchema.safeParse({
      ...basePayload,
      radiology_test_id: 'RADT000001',
      clinical_note: 'Legacy note',
      request_details: {
        modality: 'XRAY',
        priority: 'ROUTINE',
      },
    });

    expect(result.success).toBe(true);
  });

  it('requires at least one requested test or legacy radiology_test_id', () => {
    const result = createRadiologyOrderSchema.safeParse(basePayload);

    expect(result.success).toBe(false);
    expect(result.error?.issues[0]?.path).toEqual(['requested_tests']);
  });
});
