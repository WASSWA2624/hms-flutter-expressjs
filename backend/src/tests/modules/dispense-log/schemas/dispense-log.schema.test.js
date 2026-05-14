/**
 * Dispense Log schema tests
 *
 * @module tests/modules/dispense-log/schemas
 * @description Tests for dispense log validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createDispenseLogSchema,
  updateDispenseLogSchema,
  dispenseLogIdParamsSchema,
  listDispenseLogsQuerySchema
} = require('@validations/dispense-log/dispense-log.schema');

describe('Dispense Log Schemas', () => {
  describe('createDispenseLogSchema', () => {
    const validData = {
      pharmacy_order_item_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'PENDING',
      dispensed_at: '2026-01-19T10:00:00.000Z',
      quantity_dispensed: 10
    };

    it('should validate correct dispense log data', () => {
      const result = createDispenseLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require pharmacy_order_item_id', () => {
      const data = { ...validData };
      delete data.pharmacy_order_item_id;
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createDispenseLogSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional dispensed_at', () => {
      const data = { ...validData };
      delete data.dispensed_at;
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional quantity_dispensed', () => {
      const data = { ...validData };
      delete data.quantity_dispensed;
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.quantity_dispensed).toBe(0); // default value
    });

    it('should reject negative quantity_dispensed', () => {
      const data = { ...validData, quantity_dispensed: -1 };
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-integer quantity_dispensed', () => {
      const data = { ...validData, quantity_dispensed: 10.5 };
      const result = createDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDispenseLogSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        status: 'DISPENSED',
        dispensed_at: '2026-01-19T11:00:00.000Z',
        quantity_dispensed: 20
      };
      const result = updateDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { status: 'DISPENSED' };
      const result = updateDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty update object', () => {
      const result = updateDispenseLogSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject negative quantity_dispensed', () => {
      const data = { quantity_dispensed: -5 };
      const result = updateDispenseLogSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('dispenseLogIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = dispenseLogIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = dispenseLogIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const result = dispenseLogIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listDispenseLogsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        pharmacy_order_item_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING',
        dispensed_at_from: '2026-01-01T00:00:00.000Z',
        dispensed_at_to: '2026-12-31T23:59:59.999Z'
      };
      const result = listDispenseLogsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty query params', () => {
      const result = listDispenseLogsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID' };
      const result = listDispenseLogsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should coerce page and limit to numbers', () => {
      const data = { page: '2', limit: '50' };
      const result = listDispenseLogsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(typeof result.data.page).toBe('number');
      expect(typeof result.data.limit).toBe('number');
    });
  });
});
