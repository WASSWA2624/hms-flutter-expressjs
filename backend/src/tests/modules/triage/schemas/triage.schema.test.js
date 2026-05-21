const {
  triageIdParamsSchema,
  listTriageQueueQuerySchema,
  recordVitalsSchema,
  routeTriageSchema,
  correctStageSchema,
  ROUTE_DESTINATION_VALUES
} = require('@validations/triage/triage.schema');

describe('Triage Schemas', () => {
  describe('triageIdParamsSchema', () => {
    it('accepts public encounter identifiers and normalizes friendly IDs', () => {
      const result = triageIdParamsSchema.safeParse({ id: 'enc-1001' });

      expect(result.success).toBe(true);
      expect(result.data.id).toBe('ENC-1001');
    });

    it('rejects malformed identifiers', () => {
      const result = triageIdParamsSchema.safeParse({ id: 'encounter' });

      expect(result.success).toBe(false);
    });
  });

  describe('listTriageQueueQuerySchema', () => {
    it('accepts supported queue filters', () => {
      const result = listTriageQueueQuerySchema.safeParse({
        page: '1',
        limit: '20',
        queue_scope: 'WAITING',
        encounter_type: 'EMERGENCY',
        stage: 'WAITING_VITALS',
        triage_level: 'URGENT',
        search: 'PAT-1001'
      });

      expect(result.success).toBe(true);
    });
  });

  describe('recordVitalsSchema', () => {
    it('requires at least one vital', () => {
      const result = recordVitalsSchema.safeParse({ vitals: [] });

      expect(result.success).toBe(false);
    });

    it('accepts structured blood pressure values', () => {
      const result = recordVitalsSchema.safeParse({
        vitals: [
          {
            vital_type: 'BLOOD_PRESSURE',
            systolic_value: 120,
            diastolic_value: 80,
            unit: 'mmHg'
          }
        ],
        triage_level: 'LEVEL_2',
        chief_complaint: 'Chest pain'
      });

      expect(result.success).toBe(true);
    });

    it('rejects blood pressure entries without structured or slash values', () => {
      const result = recordVitalsSchema.safeParse({
        vitals: [{ vital_type: 'BLOOD_PRESSURE', value: '120 over 80' }]
      });

      expect(result.success).toBe(false);
    });
  });

  describe('routeTriageSchema', () => {
    it('accepts all supported triage route destinations', () => {
      ROUTE_DESTINATION_VALUES.forEach((routeTo) => {
        const result = routeTriageSchema.safeParse({ route_to: routeTo });

        expect(result.success).toBe(true);
      });
    });

    it('rejects unsupported route destinations', () => {
      const result = routeTriageSchema.safeParse({ route_to: 'CAFETERIA' });

      expect(result.success).toBe(false);
    });
  });

  describe('correctStageSchema', () => {
    it('requires a reason when correcting stage', () => {
      const result = correctStageSchema.safeParse({
        stage_to: 'WAITING_DOCTOR_ASSIGNMENT'
      });

      expect(result.success).toBe(false);
    });
  });
});
