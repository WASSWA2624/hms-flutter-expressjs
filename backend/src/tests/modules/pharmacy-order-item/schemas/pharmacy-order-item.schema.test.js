/**
 * Pharmacy order item schema tests
 */

const {
  createPharmacyOrderItemSchema,
  updatePharmacyOrderItemSchema,
  pharmacyOrderItemIdParamsSchema,
  listPharmacyOrderItemsQuerySchema
} = require('@validations/pharmacy-order-item/pharmacy-order-item.schema');

describe('Pharmacy Order Item Schemas', () => {
  const validCreateData = {
    pharmacy_order_id: '550e8400-e29b-41d4-a716-446655440000',
    drug_id: '550e8400-e29b-41d4-a716-446655440001',
    quantity: 2,
    dosage: '10mg',
    frequency: 'BID',
    route: 'ORAL',
    status: 'ACTIVE'
  };

  describe('createPharmacyOrderItemSchema', () => {
    it('should validate valid payload', () => {
      const result = createPharmacyOrderItemSchema.safeParse(validCreateData);
      expect(result.success).toBe(true);
    });

    it('should require pharmacy_order_id, drug_id and quantity', () => {
      const missingOrder = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        pharmacy_order_id: undefined
      });
      const missingDrug = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        drug_id: undefined
      });
      const missingQuantity = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        quantity: undefined
      });

      expect(missingOrder.success).toBe(false);
      expect(missingDrug.success).toBe(false);
      expect(missingQuantity.success).toBe(false);
    });

    it('should reject invalid enum values', () => {
      const badFrequency = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        frequency: 'INVALID'
      });
      const badRoute = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        route: 'INVALID'
      });
      const badStatus = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        status: 'INVALID'
      });

      expect(badFrequency.success).toBe(false);
      expect(badRoute.success).toBe(false);
      expect(badStatus.success).toBe(false);
    });

    it('should allow nullable optional fields', () => {
      const result = createPharmacyOrderItemSchema.safeParse({
        ...validCreateData,
        dosage: null,
        frequency: null,
        route: null
      });
      expect(result.success).toBe(true);
    });
  });

  describe('updatePharmacyOrderItemSchema', () => {
    it('should allow empty payload', () => {
      const result = updatePharmacyOrderItemSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial payload', () => {
      const result = updatePharmacyOrderItemSchema.safeParse({
        quantity: 5,
        status: 'COMPLETED'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('pharmacyOrderItemIdParamsSchema', () => {
    it('should validate valid id', () => {
      const result = pharmacyOrderItemIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid id', () => {
      const result = pharmacyOrderItemIdParamsSchema.safeParse({ id: 'bad-id' });
      expect(result.success).toBe(false);
    });
  });

  describe('listPharmacyOrderItemsQuerySchema', () => {
    it('should validate query filters', () => {
      const result = listPharmacyOrderItemsQuerySchema.safeParse({
        pharmacy_order_id: '550e8400-e29b-41d4-a716-446655440000',
        drug_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'ACTIVE',
        route: 'ORAL',
        frequency: 'BID',
        search: '10mg',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid enums in query', () => {
      const result = listPharmacyOrderItemsQuerySchema.safeParse({ route: 'INVALID' });
      expect(result.success).toBe(false);
    });
  });
});

