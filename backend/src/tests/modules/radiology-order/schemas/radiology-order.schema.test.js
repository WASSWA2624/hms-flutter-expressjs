/**
 * Radiology Order schema tests
 *
 * @module tests/modules/radiology-order/schemas
 * @description Tests for radiology order validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createRadiologyOrderSchema,
  updateRadiologyOrderSchema,
  radiologyOrderIdParamsSchema,
  listRadiologyOrdersQuerySchema
} = require('@validations/radiology-order/radiology-order.schema');

describe('Radiology Order Schemas', () => {
  describe('createRadiologyOrderSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'ORDERED',
      ordered_at: '2026-01-19T09:00:00.000Z'
    };

    it('should validate correct radiology order data', () => {
      const result = createRadiologyOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should default status when omitted', () => {
      const data = { ...validData };
      delete data.status;
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.status).toBe('ORDERED');
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createRadiologyOrderSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional radiology_test_id', () => {
      const data = { ...validData };
      delete data.radiology_test_id;
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional ordered_at', () => {
      const data = { ...validData };
      delete data.ordered_at;
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null encounter_id', () => {
      const data = { ...validData, encounter_id: null };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null radiology_test_id', () => {
      const data = { ...validData, radiology_test_id: null };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for radiology_test_id', () => {
      const data = { ...validData, radiology_test_id: 'invalid-uuid' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for ordered_at', () => {
      const data = { ...validData, ordered_at: 'not-a-datetime' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid datetime for ordered_at', () => {
      const data = { ...validData, ordered_at: '2026-12-31T23:59:59.999Z' };
      const result = createRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateRadiologyOrderSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'IN_PROCESS',
      ordered_at: '2026-01-19T10:00:00.000Z'
    };

    it('should validate correct update data', () => {
      const result = updateRadiologyOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow empty object (no updates)', () => {
      const result = updateRadiologyOrderSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only status', () => {
      const data = { status: 'COMPLETED' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only patient_id', () => {
      const data = { patient_id: '550e8400-e29b-41d4-a716-446655440005' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440006' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only radiology_test_id', () => {
      const data = { radiology_test_id: '550e8400-e29b-41d4-a716-446655440007' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates - only ordered_at', () => {
      const data = { ordered_at: '2026-01-20T15:30:00.000Z' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { status };
        const result = updateRadiologyOrderSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow null encounter_id', () => {
      const data = { encounter_id: null };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null radiology_test_id', () => {
      const data = { radiology_test_id: null };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for patient_id', () => {
      const data = { patient_id: 'not-a-uuid' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for encounter_id', () => {
      const data = { encounter_id: 'not-a-uuid' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for radiology_test_id', () => {
      const data = { radiology_test_id: 'not-a-uuid' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for ordered_at', () => {
      const data = { ordered_at: 'invalid-date' };
      const result = updateRadiologyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('radiologyOrderIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = radiologyOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'not-a-uuid' };
      const result = radiologyOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = radiologyOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject null id', () => {
      const data = { id: null };
      const result = radiologyOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty string id', () => {
      const data = { id: '' };
      const result = radiologyOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listRadiologyOrdersQuerySchema', () => {
    it('should validate empty query', () => {
      const result = listRadiologyOrdersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with sort params', () => {
      const data = { sort_by: 'ordered_at', order: 'desc' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all filter params', () => {
      const data = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'ORDERED',
        search: 'test search',
        page: '2',
        limit: '50',
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { status: 'ORDERED' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status values', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { status };
        const result = listRadiologyOrdersQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate search param', () => {
      const data = { search: 'CT Scan' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim search param', () => {
      const data = { search: '  spaced search  ' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('spaced search');
      }
    });

    it('should reject invalid UUID for encounter_id', () => {
      const data = { encounter_id: 'invalid-uuid' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for patient_id', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for radiology_test_id', () => {
      const data = { radiology_test_id: 'invalid-uuid' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate order param values', () => {
      const validOrders = ['asc', 'desc'];
      validOrders.forEach(order => {
        const data = { order };
        const result = listRadiologyOrdersQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid order values', () => {
      const data = { order: 'invalid' };
      const result = listRadiologyOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
