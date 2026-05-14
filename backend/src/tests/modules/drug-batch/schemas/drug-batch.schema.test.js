const {
  createDrugBatchSchema,
  updateDrugBatchSchema,
  drugBatchIdParamsSchema,
  listDrugBatchesQuerySchema
} = require('@validations/drug-batch/drug-batch.schema');

describe('Drug Batch Schemas', () => {
  describe('createDrugBatchSchema', () => {
    const validData = {
      drug_id: '550e8400-e29b-41d4-a716-446655440000',
      batch_number: 'BATCH001',
      expiry_date: '2025-12-31T00:00:00.000Z',
      quantity: 100
    };

    it('should validate correct data', () => {
      expect(createDrugBatchSchema.safeParse(validData).success).toBe(true);
    });

    it('should require drug_id and batch_number', () => {
      expect(createDrugBatchSchema.safeParse({ ...validData, drug_id: undefined }).success).toBe(false);
      expect(createDrugBatchSchema.safeParse({ ...validData, batch_number: undefined }).success).toBe(false);
    });

    it('should accept optional fields', () => {
      const { expiry_date, quantity, ...required } = validData;
      expect(createDrugBatchSchema.safeParse(required).success).toBe(true);
    });

    it('should enforce constraints', () => {
      expect(createDrugBatchSchema.safeParse({ ...validData, batch_number: '' }).success).toBe(false);
      expect(createDrugBatchSchema.safeParse({ ...validData, batch_number: 'a'.repeat(81) }).success).toBe(false);
      expect(createDrugBatchSchema.safeParse({ ...validData, quantity: -1 }).success).toBe(false);
    });
  });

  describe('updateDrugBatchSchema', () => {
    it('should validate partial updates', () => {
      expect(updateDrugBatchSchema.safeParse({ batch_number: 'BATCH002' }).success).toBe(true);
      expect(updateDrugBatchSchema.safeParse({}).success).toBe(true);
    });
  });

  describe('drugBatchIdParamsSchema', () => {
    it('should validate UUID', () => {
      expect(drugBatchIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' }).success).toBe(true);
      expect(drugBatchIdParamsSchema.safeParse({ id: 'invalid' }).success).toBe(false);
    });
  });

  describe('listDrugBatchesQuerySchema', () => {
    it('should validate query params', () => {
      const data = { drug_id: '550e8400-e29b-41d4-a716-446655440000', page: 1, limit: 20 };
      expect(listDrugBatchesQuerySchema.safeParse(data).success).toBe(true);
      expect(listDrugBatchesQuerySchema.safeParse({}).success).toBe(true);
    });
  });
});
