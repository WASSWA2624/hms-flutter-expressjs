/**
 * Visit queue schema tests
 *
 * @module tests/modules/visit-queue/schemas
 * @description Tests for visit queue validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createVisitQueueSchema,
  updateVisitQueueSchema,
  visitQueueIdParamsSchema,
  listVisitQueuesQuerySchema
} = require('@validations/visit-queue/visit-queue.schema');

describe('Visit Queue Schemas', () => {
  describe('createVisitQueueSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      appointment_id: '550e8400-e29b-41d4-a716-446655440003',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440004',
      status: 'SCHEDULED',
      queued_at: '2026-01-19T12:00:00.000Z'
    };

    it('should validate correct visit queue data', () => {
      const result = createVisitQueueSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow tenant_id to be injected from authenticated context', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createVisitQueueSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional appointment_id', () => {
      const data = { ...validData };
      delete data.appointment_id;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional provider_user_id', () => {
      const data = { ...validData };
      delete data.provider_user_id;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional queued_at', () => {
      const data = { ...validData };
      delete data.queued_at;
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for queued_at', () => {
      const data = { ...validData, queued_at: 'invalid-date' };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null facility_id', () => {
      const data = { ...validData, facility_id: null };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null appointment_id', () => {
      const data = { ...validData, appointment_id: null };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null provider_user_id', () => {
      const data = { ...validData, provider_user_id: null };
      const result = createVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateVisitQueueSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        appointment_id: '550e8400-e29b-41d4-a716-446655440003',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440004',
        status: 'IN_PROGRESS',
        queued_at: '2026-01-19T12:00:00.000Z'
      };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate update with partial fields', () => {
      const data = { status: 'COMPLETED' };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate update with only facility_id', () => {
      const data = { facility_id: '550e8400-e29b-41d4-a716-446655440001' };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const data = {};
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status value', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const data = { facility_id: 'invalid-uuid' };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null values for nullable fields', () => {
      const data = {
        facility_id: null,
        appointment_id: null,
        provider_user_id: null
      };
      const result = updateVisitQueueSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid status values', () => {
      const statuses = ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];
      statuses.forEach(status => {
        const data = { status };
        const result = updateVisitQueueSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });
  });

  describe('visitQueueIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = visitQueueIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = visitQueueIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const data = {};
      const result = visitQueueIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-string id', () => {
      const data = { id: 123 };
      const result = visitQueueIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate friendly id', () => {
      const data = { id: 'VQU0000123' };
      const result = visitQueueIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('listVisitQueuesQuerySchema', () => {
    it('should validate with no query params', () => {
      const data = {};
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'queued_at',
        order: 'desc'
      };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        appointment_id: '550e8400-e29b-41d4-a716-446655440003',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440004',
        status: 'SCHEDULED',
        search: 'test'
      };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const data = {
        page: 2,
        limit: 50,
        sort_by: 'created_at',
        order: 'asc',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'COMPLETED',
        search: 'test'
      };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status value', () => {
      const data = { status: 'INVALID' };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for patient_id', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status filter values', () => {
      const statuses = ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'];
      statuses.forEach(status => {
        const data = { status };
        const result = listVisitQueuesQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should trim search parameter', () => {
      const data = { search: '  test  ' };
      const result = listVisitQueuesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test'); // Zod trim happens at parse
      }
    });
  });
});
