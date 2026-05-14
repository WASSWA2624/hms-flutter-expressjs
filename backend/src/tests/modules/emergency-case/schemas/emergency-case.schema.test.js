/**
 * Emergency case schema tests
 *
 * @module tests/modules/emergency-case/schemas
 * @description Tests for emergency case validation schemas
 */

const {
  createEmergencyCaseSchema,
  updateEmergencyCaseSchema,
  emergencyCaseIdParamsSchema,
  listEmergencyCasesQuerySchema
} = require('../../../../modules/emergency-case/schemas/emergency-case.schema');

describe('Emergency Case Schema Validation', () => {
  describe('createEmergencyCaseSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'HIGH',
        status: 'PENDING'
      };

      const result = createEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with optional facility_id', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        facility_id: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'CRITICAL',
        status: 'IN_PROGRESS'
      };

      const result = createEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept all valid severity levels', () => {
      const severities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
      
      severities.forEach(severity => {
        const data = {
          tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          severity,
          status: 'PENDING'
        };
        
        const result = createEmergencyCaseSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should accept all valid statuses', () => {
      const statuses = ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
      
      statuses.forEach(status => {
        const data = {
          tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          severity: 'HIGH',
          status
        };
        
        const result = createEmergencyCaseSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = createEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues.length).toBeGreaterThan(0);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'HIGH',
        status: 'PENDING'
      };

      const result = createEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid severity', () => {
      const invalidData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'INVALID_SEVERITY',
        status: 'PENDING'
      };

      const result = createEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'HIGH',
        status: 'INVALID_STATUS'
      };

      const result = createEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateEmergencyCaseSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        severity: 'CRITICAL',
        status: 'IN_PROGRESS'
      };

      const result = updateEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (partial update)', () => {
      const validData = {};

      const result = updateEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only status update', () => {
      const validData = {
        status: 'COMPLETED'
      };

      const result = updateEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with patient_id update', () => {
      const validData = {
        patient_id: 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = updateEmergencyCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid severity', () => {
      const invalidData = {
        severity: 'INVALID'
      };

      const result = updateEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };

      const result = updateEmergencyCaseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('emergencyCaseIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = emergencyCaseIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = emergencyCaseIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = emergencyCaseIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listEmergencyCasesQuerySchema', () => {
    it('should validate valid query params', () => {
      const validData = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        facility_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        patient_id: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'HIGH',
        status: 'PENDING'
      };

      const result = listEmergencyCasesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal params', () => {
      const validData = {};

      const result = listEmergencyCasesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only pagination', () => {
      const validData = {
        page: 2,
        limit: 50
      };

      const result = listEmergencyCasesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only filters', () => {
      const validData = {
        tenant_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        severity: 'CRITICAL'
      };

      const result = listEmergencyCasesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid'
      };

      const result = listEmergencyCasesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid severity', () => {
      const invalidData = {
        severity: 'INVALID'
      };

      const result = listEmergencyCasesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = listEmergencyCasesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
