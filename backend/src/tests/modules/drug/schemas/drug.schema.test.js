/**
 * Drug schema tests
 *
 * @module tests/modules/drug/schemas
 * @description Tests for drug validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createDrugSchema,
  updateDrugSchema,
  drugIdParamsSchema,
  listDrugsQuerySchema
} = require('@validations/drug/drug.schema');

describe('Drug Schemas', () => {
  describe('createDrugSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Paracetamol',
      code: 'PARA500',
      form: 'Tablet',
      strength: '500mg'
    };

    it('should validate correct drug data', () => {
      const result = createDrugSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional code', () => {
      const data = { ...validData };
      delete data.code;
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional form', () => {
      const data = { ...validData };
      delete data.form;
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional strength', () => {
      const data = { ...validData };
      delete data.strength;
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { ...validData, name: '  Paracetamol  ', code: '  PARA500  ' };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Paracetamol');
        expect(result.data.code).toBe('PARA500');
      }
    });

    it('should enforce max length for name', () => {
      const data = { ...validData, name: 'a'.repeat(256) };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for code', () => {
      const data = { ...validData, code: 'a'.repeat(81) };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for form', () => {
      const data = { ...validData, form: 'a'.repeat(81) };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for strength', () => {
      const data = { ...validData, strength: 'a'.repeat(81) };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept a friendly tenant identifier', () => {
      const data = { ...validData, tenant_id: 'TEN-ALPHA01' };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.tenant_id).toBe('TEN-ALPHA01');
      }
    });

    it('should reject empty name', () => {
      const data = { ...validData, name: '' };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null values for optional fields', () => {
      const data = { ...validData, code: null, form: null, strength: null };
      const result = createDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateDrugSchema', () => {
    const validData = {
      name: 'Paracetamol Updated',
      code: 'PARA500U',
      form: 'Capsule',
      strength: '500mg'
    };

    it('should validate correct update data', () => {
      const result = updateDrugSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { name: 'Paracetamol Updated' };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty object', () => {
      const result = updateDrugSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { name: '  Paracetamol Updated  ' };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Paracetamol Updated');
      }
    });

    it('should enforce max length for name', () => {
      const data = { name: 'a'.repeat(256) };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for code', () => {
      const data = { code: 'a'.repeat(81) };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for form', () => {
      const data = { form: 'a'.repeat(81) };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for strength', () => {
      const data = { strength: 'a'.repeat(81) };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const data = { name: '' };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null values for optional fields', () => {
      const data = { code: null, form: null, strength: null };
      const result = updateDrugSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('drugIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = drugIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = drugIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const result = drugIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should reject non-string id', () => {
      const data = { id: 123 };
      const result = drugIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listDrugsQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Paracetamol',
        code: 'PARA500',
        form: 'Tablet',
        strength: '500mg',
        search: 'para',
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty query params', () => {
      const result = listDrugsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate tenant_id format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept a friendly tenant identifier filter', () => {
      const data = { tenant_id: 'TEN-ALPHA01' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.tenant_id).toBe('TEN-ALPHA01');
      }
    });

    it('should trim string filter fields', () => {
      const data = { name: '  Paracetamol  ' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Paracetamol');
      }
    });

    it('should accept valid page number', () => {
      const data = { page: 5 };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid limit', () => {
      const data = { limit: 50 };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid sort_by', () => {
      const data = { sort_by: 'created_at' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid order', () => {
      const data = { order: 'desc' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept partial filter params', () => {
      const data = { name: 'Paracetamol' };
      const result = listDrugsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
