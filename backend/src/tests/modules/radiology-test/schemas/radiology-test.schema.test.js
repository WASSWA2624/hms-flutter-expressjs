/**
 * Radiology test schema tests
 *
 * @module tests/modules/radiology-test/schemas
 * @description Tests for radiology test validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createRadiologyTestSchema,
  updateRadiologyTestSchema,
  radiologyTestIdParamsSchema,
  listRadiologyTestsQuerySchema
} = require('@validations/radiology-test/radiology-test.schema');

describe('Radiology Test Schemas', () => {
  describe('createRadiologyTestSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should validate correct radiology test data', () => {
      const result = createRadiologyTestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require name', () => {
      const data = { ...validData };
      delete data.name;
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require modality', () => {
      const data = { ...validData };
      delete data.modality;
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate modality enum values', () => {
      const data = { ...validData, modality: 'INVALID' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid modality values', () => {
      const modalities = ['XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER'];
      modalities.forEach(modality => {
        const data = { ...validData, modality };
        const result = createRadiologyTestSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional code', () => {
      const data = { ...validData };
      delete data.code;
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from name', () => {
      const data = { ...validData, name: '  Chest X-Ray  ' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Chest X-Ray');
      }
    });

    it('should trim whitespace from code', () => {
      const data = { ...validData, code: '  CXR-001  ' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.code).toBe('CXR-001');
      }
    });

    it('should enforce name max length', () => {
      const data = { ...validData, name: 'a'.repeat(256) };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce code max length', () => {
      const data = { ...validData, code: 'a'.repeat(81) };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept nullable code', () => {
      const data = { ...validData, code: null };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject empty name', () => {
      const data = { ...validData, name: '' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject name with only whitespace', () => {
      const data = { ...validData, name: '   ' };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept code at max length', () => {
      const data = { ...validData, code: 'a'.repeat(80) };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept name at max length', () => {
      const data = { ...validData, name: 'a'.repeat(255) };
      const result = createRadiologyTestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateRadiologyTestSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateRadiologyTestSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate modality enum when provided', () => {
      const result = updateRadiologyTestSchema.safeParse({ modality: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept valid modality values', () => {
      const modalities = ['XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER'];
      modalities.forEach(modality => {
        const result = updateRadiologyTestSchema.safeParse({ modality });
        expect(result.success).toBe(true);
      });
    });

    it('should accept partial updates', () => {
      const result = updateRadiologyTestSchema.safeParse({
        name: 'Updated X-Ray',
        modality: 'CT'
      });
      expect(result.success).toBe(true);
    });

    it('should trim whitespace from fields', () => {
      const result = updateRadiologyTestSchema.safeParse({
        name: '  Updated Test  ',
        code: '  CODE-001  '
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Test');
        expect(result.data.code).toBe('CODE-001');
      }
    });

    it('should accept nullable code', () => {
      const result = updateRadiologyTestSchema.safeParse({ code: null });
      expect(result.success).toBe(true);
    });

    it('should enforce name max length when provided', () => {
      const result = updateRadiologyTestSchema.safeParse({ name: 'a'.repeat(256) });
      expect(result.success).toBe(false);
    });

    it('should enforce code max length when provided', () => {
      const result = updateRadiologyTestSchema.safeParse({ code: 'a'.repeat(81) });
      expect(result.success).toBe(false);
    });

    it('should reject empty name when provided', () => {
      const result = updateRadiologyTestSchema.safeParse({ name: '' });
      expect(result.success).toBe(false);
    });

    it('should reject name with only whitespace when provided', () => {
      const result = updateRadiologyTestSchema.safeParse({ name: '   ' });
      expect(result.success).toBe(false);
    });

    it('should accept only modality update', () => {
      const result = updateRadiologyTestSchema.safeParse({ modality: 'MRI' });
      expect(result.success).toBe(true);
    });

    it('should accept only name update', () => {
      const result = updateRadiologyTestSchema.safeParse({ name: 'New Name' });
      expect(result.success).toBe(true);
    });

    it('should accept only code update', () => {
      const result = updateRadiologyTestSchema.safeParse({ code: 'NEW-001' });
      expect(result.success).toBe(true);
    });
  });

  describe('radiologyTestIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const result = radiologyTestIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = radiologyTestIdParamsSchema.safeParse({ id: 'invalid-uuid' });
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = radiologyTestIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should reject empty id', () => {
      const result = radiologyTestIdParamsSchema.safeParse({ id: '' });
      expect(result.success).toBe(false);
    });

    it('should reject numeric id', () => {
      const result = radiologyTestIdParamsSchema.safeParse({ id: 123 });
      expect(result.success).toBe(false);
    });
  });

  describe('listRadiologyTestsQuerySchema', () => {
    it('should validate with no query params', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid tenant_id', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept name filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({
        name: 'X-Ray'
      });
      expect(result.success).toBe(true);
    });

    it('should accept code filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({
        code: 'CXR-001'
      });
      expect(result.success).toBe(true);
    });

    it('should accept modality filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ modality: 'XRAY' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid modality filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ modality: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept search parameter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ search: 'chest' });
      expect(result.success).toBe(true);
    });

    it('should accept pagination params', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should accept all filters combined', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'X-Ray',
        code: 'CXR',
        modality: 'XRAY',
        search: 'chest',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for tenant_id', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ tenant_id: 'invalid' });
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from search', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ search: '  chest  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('chest');
      }
    });

    it('should trim whitespace from name filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ name: '  X-Ray  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('X-Ray');
      }
    });

    it('should trim whitespace from code filter', () => {
      const result = listRadiologyTestsQuerySchema.safeParse({ code: '  CXR-001  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.code).toBe('CXR-001');
      }
    });

    it('should accept all valid modality values in filter', () => {
      const modalities = ['XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER'];
      modalities.forEach(modality => {
        const result = listRadiologyTestsQuerySchema.safeParse({ modality });
        expect(result.success).toBe(true);
      });
    });
  });
});
