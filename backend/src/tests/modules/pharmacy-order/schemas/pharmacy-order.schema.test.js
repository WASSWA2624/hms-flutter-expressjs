/**
 * Pharmacy order schema tests
 *
 * @module tests/modules/pharmacy-order/schemas
 * @description Tests for pharmacy order validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPharmacyOrderSchema,
  updatePharmacyOrderSchema,
  pharmacyOrderIdParamsSchema,
  listPharmacyOrdersQuerySchema
} = require('@validations/pharmacy-order/pharmacy-order.schema');

describe('Pharmacy Order Schemas', () => {
  describe('createPharmacyOrderSchema', () => {
    const validData = {
      patient_id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'ORDERED',
      ordered_at: '2026-01-19T12:00:00.000Z'
    };

    it('should validate correct pharmacy order data', () => {
      const result = createPharmacyOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable encounter_id', () => {
      const data = { ...validData, encounter_id: null };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['ORDERED', 'DISPENSED', 'PARTIALLY_DISPENSED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createPharmacyOrderSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional ordered_at', () => {
      const data = { ...validData };
      delete data.ordered_at;
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate ordered_at datetime format', () => {
      const data = { ...validData, ordered_at: 'invalid-date' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept friendly identifier format for patient_id', () => {
      const data = { ...validData, patient_id: 'PAT-001' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid identifier format for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid uuid' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept friendly identifier format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'ENC-001' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid identifier format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid uuid' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid ISO 8601 datetime for ordered_at', () => {
      const data = { ...validData, ordered_at: '2026-01-19T15:30:00.000Z' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept minimal valid data', () => {
      const data = { patient_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = createPharmacyOrderSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updatePharmacyOrderSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updatePharmacyOrderSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const result = updatePharmacyOrderSchema.safeParse({ status: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept all valid status values', () => {
      const statuses = ['ORDERED', 'DISPENSED', 'PARTIALLY_DISPENSED', 'CANCELLED'];
      statuses.forEach(status => {
        const result = updatePharmacyOrderSchema.safeParse({ status });
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid patient_id UUID', () => {
      const result = updatePharmacyOrderSchema.safeParse({
        patient_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept patient_id friendly identifier', () => {
      const result = updatePharmacyOrderSchema.safeParse({ patient_id: 'PAT-001' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid patient_id identifier', () => {
      const result = updatePharmacyOrderSchema.safeParse({ patient_id: 'invalid uuid' });
      expect(result.success).toBe(false);
    });

    it('should accept valid encounter_id UUID', () => {
      const result = updatePharmacyOrderSchema.safeParse({
        encounter_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept encounter_id friendly identifier', () => {
      const result = updatePharmacyOrderSchema.safeParse({ encounter_id: 'ENC-001' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid encounter_id identifier', () => {
      const result = updatePharmacyOrderSchema.safeParse({ encounter_id: 'invalid uuid' });
      expect(result.success).toBe(false);
    });

    it('should accept nullable encounter_id', () => {
      const result = updatePharmacyOrderSchema.safeParse({ encounter_id: null });
      expect(result.success).toBe(true);
    });

    it('should accept valid ordered_at datetime', () => {
      const result = updatePharmacyOrderSchema.safeParse({
        ordered_at: '2026-01-19T12:00:00.000Z'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid ordered_at format', () => {
      const result = updatePharmacyOrderSchema.safeParse({ ordered_at: 'invalid-date' });
      expect(result.success).toBe(false);
    });

    it('should accept partial updates', () => {
      const result = updatePharmacyOrderSchema.safeParse({
        status: 'DISPENSED',
        ordered_at: '2026-01-19T12:00:00.000Z'
      });
      expect(result.success).toBe(true);
    });

    it('should accept all fields together', () => {
      const result = updatePharmacyOrderSchema.safeParse({
        patient_id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'PARTIALLY_DISPENSED',
        ordered_at: '2026-01-19T12:00:00.000Z'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('pharmacyOrderIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const result = pharmacyOrderIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept friendly pharmacy order id', () => {
      const result = pharmacyOrderIdParamsSchema.safeParse({ id: 'PHO-B1DEB9CE0C' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid identifier', () => {
      const result = pharmacyOrderIdParamsSchema.safeParse({ id: 'invalid uuid' });
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = pharmacyOrderIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listPharmacyOrdersQuerySchema', () => {
    it('should validate with no query params', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid patient_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        patient_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept friendly patient_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        patient_id: 'PAT-001'
      });
      expect(result.success).toBe(true);
    });

    it('should accept valid encounter_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        encounter_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept friendly encounter_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        encounter_id: 'ENC-001'
      });
      expect(result.success).toBe(true);
    });

    it('should accept status filter', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({ status: 'ORDERED' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid status filter', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({ status: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept ordered_at_from filter', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        ordered_at_from: '2026-01-01T00:00:00.000Z'
      });
      expect(result.success).toBe(true);
    });

    it('should accept ordered_at_to filter', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        ordered_at_to: '2026-12-31T23:59:59.999Z'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid datetime for ordered_at_from', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        ordered_at_from: 'invalid-date'
      });
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for ordered_at_to', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        ordered_at_to: 'invalid-date'
      });
      expect(result.success).toBe(false);
    });

    it('should accept pagination params', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        page: '1',
        limit: '20',
        sort_by: 'ordered_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should accept all filters combined', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({
        patient_id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'ORDERED',
        ordered_at_from: '2026-01-01T00:00:00.000Z',
        ordered_at_to: '2026-12-31T23:59:59.999Z',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid identifier for patient_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({ patient_id: 'invalid uuid' });
      expect(result.success).toBe(false);
    });

    it('should reject invalid identifier for encounter_id', () => {
      const result = listPharmacyOrdersQuerySchema.safeParse({ encounter_id: 'invalid uuid' });
      expect(result.success).toBe(false);
    });
  });
});
