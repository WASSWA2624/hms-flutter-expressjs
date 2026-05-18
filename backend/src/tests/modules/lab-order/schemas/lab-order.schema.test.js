/**
 * Lab order schema tests
 *
 * @module tests/modules/lab-order/schemas
 * @description Tests for lab order validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const { createLabOrderSchema, updateLabOrderSchema, labOrderIdParamsSchema, listLabOrdersQuerySchema } = require('@validations/lab-order/lab-order.schema');

describe('Lab Order Schemas', () => {
  describe('createLabOrderSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      requested_tests: [{ lab_test_id: 'LBT0000001' }],
      status: 'ORDERED',
      ordered_at: '2026-01-19T12:00:00.000Z'
    };

    it('should validate correct lab order data', () => {
      const result = createLabOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should default status when omitted', () => {
      const data = { ...validData };
      delete data.status;
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.status).toBe('ORDERED');
    });

    it('should accept optional encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null encounter_id', () => {
      const data = { ...validData, encounter_id: null };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional ordered_at', () => {
      const data = { ...validData };
      delete data.ordered_at;
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('accepts configured test and panel request selections', () => {
      const result = createLabOrderSchema.safeParse({
        ...validData,
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
        requested_panels: [{ lab_panel_id: 'LPN0000001' }]
      });

      expect(result.success).toBe(true);
    });

    it('accepts large configured test request selections', () => {
      const result = createLabOrderSchema.safeParse({
        ...validData,
        requested_tests: Array.from({ length: 5000 }, (_, index) => ({
          lab_test_id: `LBT${String(index + 1).padStart(7, '0')}`
        }))
      });

      expect(result.success).toBe(true);
    });

    it('should validate status enum - ORDERED', () => {
      const data = { ...validData, status: 'ORDERED' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - COLLECTED', () => {
      const data = { ...validData, status: 'COLLECTED' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - IN_PROCESS', () => {
      const data = { ...validData, status: 'IN_PROCESS' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - COMPLETED', () => {
      const data = { ...validData, status: 'COMPLETED' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - CANCELLED', () => {
      const data = { ...validData, status: 'CANCELLED' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status enum', () => {
      const data = { ...validData, status: 'INVALID_STATUS' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid patient_id UUID', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid encounter_id UUID', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ordered_at datetime', () => {
      const data = { ...validData, ordered_at: 'invalid-date' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-ISO datetime for ordered_at', () => {
      const data = { ...validData, ordered_at: '2026-01-19' };
      const result = createLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLabOrderSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateLabOrderSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial update with patient_id', () => {
      const data = { patient_id: '550e8400-e29b-41d4-a716-446655440001' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial update with status', () => {
      const data = { status: 'COMPLETED' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial update with encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null encounter_id', () => {
      const data = { encounter_id: null };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept configured test and panel selections for existing order edits', () => {
      const data = {
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
        requested_panels: [{ lab_panel_id: 'LPN0000001' }]
      };

      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept large configured test selections for existing order edits', () => {
      const data = {
        requested_tests: Array.from({ length: 5000 }, (_, index) => ({
          lab_test_id: `LBT${String(index + 1).padStart(7, '0')}`
        }))
      };

      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid patient_id UUID', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid encounter_id UUID', () => {
      const data = { encounter_id: 'invalid-uuid' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ordered_at datetime', () => {
      const data = { ordered_at: 'invalid-date' };
      const result = updateLabOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('labOrderIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = labOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = labOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = labOrderIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should reject empty string id', () => {
      const data = { id: '' };
      const result = labOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject numeric id', () => {
      const data = { id: 123 };
      const result = labOrderIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listLabOrdersQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept all params optional', () => {
      const result = listLabOrdersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with encounter_id filter', () => {
      const data = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with patient_id filter', () => {
      const data = {
        patient_id: '550e8400-e29b-41d4-a716-446655440001'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with status filter', () => {
      const data = {
        status: 'COMPLETED'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with ordered_at_from filter', () => {
      const data = {
        ordered_at_from: '2026-01-01T00:00:00.000Z'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with ordered_at_to filter', () => {
      const data = {
        ordered_at_to: '2026-01-31T23:59:59.999Z'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with date range filters', () => {
      const data = {
        ordered_at_from: '2026-01-01T00:00:00.000Z',
        ordered_at_to: '2026-01-31T23:59:59.999Z'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with search param', () => {
      const data = {
        search: 'test search'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim search param', () => {
      const data = {
        search: '  test search  '
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test search');
      }
    });

    it('should reject invalid status enum', () => {
      const data = {
        status: 'INVALID_STATUS'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid patient_id UUID', () => {
      const data = {
        patient_id: 'invalid-uuid'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid encounter_id UUID', () => {
      const data = {
        encounter_id: 'invalid-uuid'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ordered_at_from datetime', () => {
      const data = {
        ordered_at_from: 'invalid-date'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ordered_at_to datetime', () => {
      const data = {
        ordered_at_to: 'invalid-date'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate all filters together', () => {
      const data = {
        page: 2,
        limit: 50,
        sort_by: 'ordered_at',
        order: 'desc',
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'COMPLETED',
        ordered_at_from: '2026-01-01T00:00:00.000Z',
        ordered_at_to: '2026-01-31T23:59:59.999Z',
        search: 'blood test'
      };
      const result = listLabOrdersQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
