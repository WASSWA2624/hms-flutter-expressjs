const {
  createOpdFlowSchema,
  encounterIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  payConsultationSchema,
  recordVitalsSchema,
  assignDoctorSchema,
  doctorReviewSchema,
  dispositionSchema,
  listOpdFlowsQuerySchema
} = require('@validations/opd-flow/opd-flow.schema');

describe('opd-flow.schema', () => {
  describe('createOpdFlowSchema', () => {
    it('validates walk-in with patient registration', () => {
      const result = createOpdFlowSchema.safeParse({
        tenant_id: 'TEN0000001',
        facility_id: 'FAC0000001',
        patient_registration: {
          first_name: 'Jane',
          last_name: 'Doe'
        }
      });

      expect(result.success).toBe(true);
    });

    it('requires patient source', () => {
      const result = createOpdFlowSchema.safeParse({
        tenant_id: 'TEN0000001'
      });
      expect(result.success).toBe(false);
    });

    it('requires appointment when arrival_mode is ONLINE_APPOINTMENT', () => {
      const result = createOpdFlowSchema.safeParse({
        tenant_id: 'TEN0000001',
        arrival_mode: 'ONLINE_APPOINTMENT',
        patient_id: 'PAT0000002'
      });
      expect(result.success).toBe(false);
    });

    it('accepts human-friendly patient identifier', () => {
      const result = createOpdFlowSchema.safeParse({
        tenant_id: 'TEN0000001',
        patient_id: 'pat0000003'
      });

      expect(result.success).toBe(true);
      expect(result.data.patient_id).toBe('PAT0000003');
    });

    it('accepts UUID scope identifiers for tenant and facility', () => {
      const result = createOpdFlowSchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: 'PAT0000003'
      });

      expect(result.success).toBe(true);
      expect(result.data.tenant_id).toBe('550e8400-e29b-41d4-a716-446655440000');
      expect(result.data.facility_id).toBe('550e8400-e29b-41d4-a716-446655440001');
    });
  });

  describe('encounterIdParamsSchema', () => {
    it('validates encounter id params', () => {
      const result = encounterIdParamsSchema.safeParse({
        id: 'ENC0000010'
      });
      expect(result.success).toBe(true);
    });

    it('rejects UUID-like encounter route params', () => {
      const result = encounterIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440010'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('resolveLegacyRouteParamsSchema', () => {
    it('accepts emergency legacy resource with friendly id', () => {
      const result = resolveLegacyRouteParamsSchema.safeParse({
        resource: 'emergency-cases',
        id: 'emc0000001'
      });

      expect(result.success).toBe(true);
      expect(result.data.id).toBe('EMC0000001');
    });

    it('accepts UUID id for legacy lookup', () => {
      const result = resolveLegacyRouteParamsSchema.safeParse({
        resource: 'ambulance-dispatches',
        id: '550e8400-e29b-41d4-a716-446655440001'
      });

      expect(result.success).toBe(true);
      expect(result.data.id).toBe('550e8400-e29b-41d4-a716-446655440001');
    });

    it('rejects unsupported legacy resource', () => {
      const result = resolveLegacyRouteParamsSchema.safeParse({
        resource: 'unknown-resource',
        id: 'EMC0000001'
      });

      expect(result.success).toBe(false);
    });
  });

  describe('payConsultationSchema', () => {
    it('validates payment payload', () => {
      const result = payConsultationSchema.safeParse({
        method: 'CASH',
        amount: '40.00',
        status: 'COMPLETED'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('recordVitalsSchema', () => {
    it('validates vitals payload', () => {
      const result = recordVitalsSchema.safeParse({
        vitals: [
          {
            vital_type: 'TEMPERATURE',
            value: '36.8',
            unit: 'C'
          }
        ],
        triage_level: 'IMMEDIATE'
      });

      expect(result.success).toBe(true);
    });

    it('rejects empty vitals array', () => {
      const result = recordVitalsSchema.safeParse({
        vitals: []
      });

      expect(result.success).toBe(false);
    });

    it('rejects unknown triage alias', () => {
      const result = recordVitalsSchema.safeParse({
        vitals: [
          {
            vital_type: 'HEART_RATE',
            value: '90'
          }
        ],
        triage_level: 'SUPER_URGENT'
      });

      expect(result.success).toBe(false);
    });
  });

  describe('assignDoctorSchema', () => {
    it('validates provider id', () => {
      const result = assignDoctorSchema.safeParse({
        provider_user_id: 'DOC0000011'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('doctorReviewSchema', () => {
    it('validates lab, radiology, and medication payloads', () => {
      const result = doctorReviewSchema.safeParse({
        note: 'Review completed.',
        diagnoses: [
          {
            diagnosis_type: 'PRIMARY',
            description: 'Malaria'
          }
        ],
        procedures: [
          {
            description: 'Physical examination'
          }
        ],
        lab_requests: [
          {
            lab_test_id: 'LAB0000012'
          }
        ],
        radiology_requests: [
          {
            radiology_test_id: 'RAD0000013'
          }
        ],
        medications: [
          {
            drug_id: 'DRG0000014',
            quantity: 2
          }
        ]
      });

      expect(result.success).toBe(true);
    });

    it('accepts lab panel requests during doctor review', () => {
      const result = doctorReviewSchema.safeParse({
        note: 'Request chemistry panel',
        lab_requests: [
          {
            lab_panel_id: 'LPN0000014'
          }
        ]
      });

      expect(result.success).toBe(true);
    });

    it('rejects lab requests without a test or panel selection', () => {
      const result = doctorReviewSchema.safeParse({
        note: 'Incomplete request',
        lab_requests: [{}]
      });

      expect(result.success).toBe(false);
    });

    it('rejects lab requests that mix test and panel identifiers in one row', () => {
      const result = doctorReviewSchema.safeParse({
        note: 'Invalid request row',
        lab_requests: [
          {
            lab_test_id: 'LBT0000012',
            lab_panel_id: 'LPN0000014'
          }
        ]
      });

      expect(result.success).toBe(false);
    });

    it('rejects invalid radiology status', () => {
      const result = doctorReviewSchema.safeParse({
        note: 'Review completed.',
        radiology_requests: [
          {
            radiology_test_id: 'RAD0000013',
            status: 'PENDING_APPROVAL'
          }
        ]
      });

      expect(result.success).toBe(false);
    });
  });

  describe('dispositionSchema', () => {
    it('validates admit payload', () => {
      const result = dispositionSchema.safeParse({
        decision: 'ADMIT',
        notes: 'Needs close observation'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('listOpdFlowsQuerySchema', () => {
    it('validates list query payload', () => {
      const result = listOpdFlowsQuerySchema.safeParse({
        page: 1,
        limit: 20,
        stage: 'WAITING_VITALS',
        search: 'jane'
      });
      expect(result.success).toBe(true);
    });

    it('rejects invalid stage', () => {
      const result = listOpdFlowsQuerySchema.safeParse({
        stage: 'INVALID_STAGE'
      });
      expect(result.success).toBe(false);
    });

    it('accepts human-friendly patient filter', () => {
      const result = listOpdFlowsQuerySchema.safeParse({
        patient_id: 'pat0000003'
      });

      expect(result.success).toBe(true);
      expect(result.data.patient_id).toBe('PAT0000003');
    });

    it('accepts UUID scope filters for tenant and facility', () => {
      const result = listOpdFlowsQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001'
      });

      expect(result.success).toBe(true);
      expect(result.data.tenant_id).toBe('550e8400-e29b-41d4-a716-446655440000');
      expect(result.data.facility_id).toBe('550e8400-e29b-41d4-a716-446655440001');
    });
  });
});
