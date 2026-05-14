/**
 * Admission schema tests
 *
 * @module tests/modules/admission/schemas
 * @description Tests for admission validation schemas
 */

const {
  createAdmissionSchema,
  updateAdmissionSchema,
  dischargeAdmissionSchema,
  admissionIdParamsSchema,
  listAdmissionsQuerySchema
} = require('../../../../modules/admission/schemas/admission.schema');

describe('Admission Schema Validation', () => {
  describe('createAdmissionSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        status: 'ADMITTED'
      };

      const result = createAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with optional fields', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        facility_id: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        encounter_id: 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        status: 'ADMITTED',
        admitted_at: '2026-01-19T10:00:00Z'
      };

      const result = createAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = createAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues).toHaveLength(2); // missing patient_id and status
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        status: 'ADMITTED'
      };

      const result = createAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        status: 'INVALID_STATUS'
      };

      const result = createAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateAdmissionSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        status: 'DISCHARGED',
        discharged_at: '2026-01-20T10:00:00Z'
      };

      const result = updateAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (partial update)', () => {
      const validData = {};

      const result = updateAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = updateAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format', () => {
      const invalidData = {
        admitted_at: 'invalid-date'
      };

      const result = updateAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('dischargeAdmissionSchema', () => {
    it('should validate with discharged_at', () => {
      const validData = {
        discharged_at: '2026-01-20T10:00:00Z'
      };

      const result = dischargeAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (uses current time)', () => {
      const validData = {};

      const result = dischargeAdmissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid date format', () => {
      const invalidData = {
        discharged_at: 'not-a-date'
      };

      const result = dischargeAdmissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('admissionIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = admissionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };

      const result = admissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = admissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listAdmissionsQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};

      const result = listAdmissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        facility_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        encounter_id: 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        status: 'ADMITTED',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      const result = listAdmissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      expect(result.data.page).toBe(1); // Coerced to number
      expect(result.data.limit).toBe(20); // Coerced to number
    });

    it('should use default pagination values', () => {
      const validData = {};

      const result = listAdmissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      expect(result.data.page).toBeDefined();
      expect(result.data.limit).toBeDefined();
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = listAdmissionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUIDs', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };

      const result = listAdmissionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
