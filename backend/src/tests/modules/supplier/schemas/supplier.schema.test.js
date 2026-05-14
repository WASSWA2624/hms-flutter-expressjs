/**
 * Supplier schema validation tests
 *
 * @module tests/modules/supplier/schemas
 * @description Comprehensive tests for supplier validation schemas
 */

const {
  createSupplierSchema,
  updateSupplierSchema,
  supplierIdParamsSchema,
  listSuppliersQuerySchema
} = require('@modules/supplier/schemas/supplier.schema');

describe('Supplier Schema Validation', () => {
  describe('createSupplierSchema', () => {
    it('should validate valid supplier data', () => {
      const validData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        contact_email: 'contact@medicalsupplies.com',
        phone: '+1234567890'
      };

      const result = createSupplierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with optional fields omitted', () => {
      const validData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      const result = createSupplierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation without tenant_id', () => {
      const invalidData = {
        name: 'Medical Supplies Inc'
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues[0].path).toContain('tenant_id');
    });

    it('should fail validation without name', () => {
      const invalidData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      expect(result.error.issues[0].path).toContain('name');
    });

    it('should fail validation with invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Medical Supplies Inc'
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation with invalid email format', () => {
      const invalidData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        contact_email: 'invalid-email'
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation with name exceeding max length', () => {
      const invalidData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'A'.repeat(256)
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation with phone exceeding max length', () => {
      const invalidData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        phone: '1'.repeat(41)
      };

      const result = createSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from fields', () => {
      const dataWithWhitespace = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: '  Medical Supplies Inc  ',
        contact_email: '  contact@medicalsupplies.com  ',
        phone: '  +1234567890  '
      };

      const result = createSupplierSchema.safeParse(dataWithWhitespace);
      expect(result.success).toBe(true);
      expect(result.data.name).toBe('Medical Supplies Inc');
      expect(result.data.contact_email).toBe('contact@medicalsupplies.com');
      expect(result.data.phone).toBe('+1234567890');
    });
  });

  describe('updateSupplierSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        name: 'Updated Supplies Inc',
        contact_email: 'updated@medicalsupplies.com',
        phone: '+9876543210'
      };

      const result = updateSupplierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial fields', () => {
      const validData = {
        name: 'Updated Supplies Inc'
      };

      const result = updateSupplierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const result = updateSupplierSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should fail validation with invalid email format', () => {
      const invalidData = {
        contact_email: 'invalid-email'
      };

      const result = updateSupplierSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should allow null values for optional fields', () => {
      const validData = {
        contact_email: null,
        phone: null
      };

      const result = updateSupplierSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('supplierIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validParams = {
        id: '550e8400-e29b-41d4-a716-446655440000'
      };

      const result = supplierIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    it('should fail validation with invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      const result = supplierIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });

    it('should fail validation without id', () => {
      const result = supplierIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listSuppliersQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical',
        contact_email: 'contact@',
        search: 'supplies'
      };

      const result = listSuppliersQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should validate with no query parameters', () => {
      const result = listSuppliersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with only pagination parameters', () => {
      const validQuery = {
        page: '2',
        limit: '50'
      };

      const result = listSuppliersQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should fail validation with invalid tenant_id format', () => {
      const invalidQuery = {
        tenant_id: 'invalid-uuid'
      };

      const result = listSuppliersQuerySchema.safeParse(invalidQuery);
      expect(result.success).toBe(false);
    });
  });
});
