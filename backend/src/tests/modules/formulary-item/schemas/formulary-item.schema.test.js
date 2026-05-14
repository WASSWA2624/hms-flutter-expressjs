const {
  createFormularyItemSchema,
  updateFormularyItemSchema,
  formularyItemIdParamsSchema,
  listFormularyItemsQuerySchema
} = require('@validations/formulary-item/formulary-item.schema');

describe('Formulary Item Schemas', () => {
  const validData = {
    tenant_id: '550e8400-e29b-41d4-a716-446655440000',
    drug_id: '550e8400-e29b-41d4-a716-446655440001',
    is_active: true
  };

  describe('createFormularyItemSchema', () => {
    it('should validate correct data', () => {
      expect(createFormularyItemSchema.safeParse(validData).success).toBe(true);
    });

    it('should require tenant_id and drug_id', () => {
      expect(createFormularyItemSchema.safeParse({ ...validData, tenant_id: undefined }).success).toBe(false);
      expect(createFormularyItemSchema.safeParse({ ...validData, drug_id: undefined }).success).toBe(false);
    });

    it('should accept optional is_active', () => {
      const { is_active, ...required } = validData;
      expect(createFormularyItemSchema.safeParse(required).success).toBe(true);
    });
  });

  describe('updateFormularyItemSchema', () => {
    it('should validate partial updates', () => {
      expect(updateFormularyItemSchema.safeParse({ is_active: false }).success).toBe(true);
      expect(updateFormularyItemSchema.safeParse({}).success).toBe(true);
    });
  });

  describe('formularyItemIdParamsSchema', () => {
    it('should validate UUID', () => {
      expect(formularyItemIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(true);
      expect(formularyItemIdParamsSchema.safeParse({ id: 'invalid' }).success).toBe(false);
    });
  });

  describe('listFormularyItemsQuerySchema', () => {
    it('should validate query params', () => {
      expect(listFormularyItemsQuerySchema.safeParse({ tenant_id: validData.tenant_id }).success).toBe(true);
      expect(listFormularyItemsQuerySchema.safeParse({}).success).toBe(true);
    });
  });
});
