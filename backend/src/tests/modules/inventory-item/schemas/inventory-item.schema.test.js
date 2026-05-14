/**
 * Inventory item schema tests
 *
 * @module tests/modules/inventory-item/schemas
 * @description Tests for inventory item validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createInventoryItemSchema,
  updateInventoryItemSchema,
  inventoryItemIdParamsSchema,
  listInventoryItemsQuerySchema
} = require('@validations/inventory-item/inventory-item.schema');

describe('Inventory Item Schemas', () => {
  describe('createInventoryItemSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Surgical Gloves',
      category: 'SUPPLY',
      sku: 'SG-001',
      unit: 'Box'
    };

    it('should validate correct inventory item data', () => {
      const result = createInventoryItemSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require category', () => {
      const data = { ...validData };
      delete data.category;
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept MEDICATION category', () => {
      const data = { ...validData, category: 'MEDICATION' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept SUPPLY category', () => {
      const data = { ...validData, category: 'SUPPLY' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept EQUIPMENT category', () => {
      const data = { ...validData, category: 'EQUIPMENT' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept OTHER category', () => {
      const data = { ...validData, category: 'OTHER' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid category', () => {
      const data = { ...validData, category: 'INVALID' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional sku', () => {
      const data = { ...validData };
      delete data.sku;
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional unit', () => {
      const data = { ...validData };
      delete data.unit;
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { ...validData, name: '  Surgical Gloves  ', sku: '  SG-001  ' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Surgical Gloves');
        expect(result.data.sku).toBe('SG-001');
      }
    });

    it('should enforce max length for name', () => {
      const data = { ...validData, name: 'a'.repeat(256) };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for sku', () => {
      const data = { ...validData, sku: 'a'.repeat(81) };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for unit', () => {
      const data = { ...validData, unit: 'a'.repeat(41) };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const data = { ...validData, name: '' };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional fields', () => {
      const data = { ...validData, sku: null, unit: null };
      const result = createInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateInventoryItemSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        name: 'Updated Surgical Gloves',
        category: 'EQUIPMENT',
        sku: 'SG-002',
        unit: 'Pair'
      };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept partial updates', () => {
      const data = { name: 'Updated Name' };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const result = updateInventoryItemSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should trim string fields', () => {
      const data = { name: '  Updated Name  ' };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Name');
      }
    });

    it('should enforce max length for name', () => {
      const data = { name: 'a'.repeat(256) };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for sku', () => {
      const data = { sku: 'a'.repeat(81) };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for unit', () => {
      const data = { unit: 'a'.repeat(41) };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const data = { name: '' };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid category', () => {
      const data = { category: 'INVALID' };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for nullable fields', () => {
      const data = { sku: null, unit: null };
      const result = updateInventoryItemSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('inventoryItemIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = inventoryItemIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const data = { id: 'invalid-uuid' };
      const result = inventoryItemIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = inventoryItemIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-string id', () => {
      const data = { id: 12345 };
      const result = inventoryItemIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listInventoryItemsQuerySchema', () => {
    it('should validate empty query', () => {
      const result = listInventoryItemsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate sort params', () => {
      const data = { sort_by: 'name', order: 'asc' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Surgical',
        category: 'SUPPLY',
        sku: 'SG-001',
        unit: 'Box'
      };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate search param', () => {
      const data = { search: 'gloves' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid category', () => {
      const data = { category: 'INVALID' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim string query params', () => {
      const data = { name: '  Surgical  ', sku: '  SG-001  ' };
      const result = listInventoryItemsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Surgical');
        expect(result.data.sku).toBe('SG-001');
      }
    });

    it('should accept all valid categories', () => {
      ['MEDICATION', 'SUPPLY', 'EQUIPMENT', 'OTHER'].forEach(category => {
        const data = { category };
        const result = listInventoryItemsQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });
  });
});
