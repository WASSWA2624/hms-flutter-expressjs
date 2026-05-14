/**
 * Medication administration schema tests
 *
 * @module tests/modules/medication-administration/schemas
 * @description Tests for medication administration validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createMedicationAdministrationSchema,
  updateMedicationAdministrationSchema,
  medicationAdministrationIdParamsSchema,
  listMedicationAdministrationsQuerySchema
} = require('@validations/medication-administration/medication-administration.schema');

describe('Medication Administration Schemas', () => {
  describe('createMedicationAdministrationSchema', () => {
    const validData = {
      admission_id: '550e8400-e29b-41d4-a716-446655440000',
      dose: '500mg',
      unit: 'mg',
      route: 'ORAL'
    };

    it('should validate correct medication administration data', () => {
      const result = createMedicationAdministrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require admission_id', () => {
      const data = { ...validData };
      delete data.admission_id;
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require dose', () => {
      const data = { ...validData };
      delete data.dose;
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require route', () => {
      const data = { ...validData };
      delete data.route;
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional prescription_id', () => {
      const data = {
        ...validData,
        prescription_id: '550e8400-e29b-41d4-a716-446655440001'
      };
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional administered_at', () => {
      const data = {
        ...validData,
        administered_at: '2024-01-01T10:00:00Z'
      };
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate route enum values', () => {
      const validRoutes = ['ORAL', 'IV', 'IM', 'SC', 'TOPICAL', 'INHALATION', 'RECTAL', 'OTHER'];
      
      validRoutes.forEach(route => {
        const data = { ...validData, route };
        const result = createMedicationAdministrationSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid route enum', () => {
      const data = { ...validData, route: 'INVALID_ROUTE' };
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for admission_id', () => {
      const data = { ...validData, admission_id: 'invalid-uuid' };
      const result = createMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateMedicationAdministrationSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateMedicationAdministrationSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = { dose: '1000mg', unit: 'mg' };
      const result = updateMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate route enum in update', () => {
      const data = { route: 'IV' };
      const result = updateMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid route enum in update', () => {
      const data = { route: 'INVALID' };
      const result = updateMedicationAdministrationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('medicationAdministrationIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = medicationAdministrationIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = medicationAdministrationIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listMedicationAdministrationsQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listMedicationAdministrationsQuerySchema.safeParse({
        page: '1',
        limit: '20',
        admission_id: '550e8400-e29b-41d4-a716-446655440000',
        route: 'ORAL'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listMedicationAdministrationsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should reject invalid route filter', () => {
      const result = listMedicationAdministrationsQuerySchema.safeParse({
        route: 'INVALID'
      });
      expect(result.success).toBe(false);
    });
  });
});
