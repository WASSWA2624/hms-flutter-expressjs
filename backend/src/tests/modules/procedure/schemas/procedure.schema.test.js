/**
 * Procedure schema tests
 *
 * @module tests/modules/procedure/schemas
 * @description Tests for procedure validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createProcedureSchema,
  updateProcedureSchema,
  procedureIdParamsSchema,
  listProceduresQuerySchema
} = require('@validations/procedure/procedure.schema');

describe('Procedure Schemas', () => {
  describe('createProcedureSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      code: '47562',
      description: 'Laparoscopic cholecystectomy',
      performed_at: '2026-01-19T10:00:00Z'
    };

    it('should validate correct procedure data', () => {
      const result = createProcedureSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require description', () => {
      const data = { ...validData };
      delete data.description;
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional code', () => {
      const data = { ...validData };
      delete data.code;
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional performed_at', () => {
      const data = { ...validData };
      delete data.performed_at;
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('accepts optional request-time billing payload', () => {
      const result = createProcedureSchema.safeParse({
        ...validData,
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: 120,
          line_items: [
            {
              id: 'proc-1',
              label: 'Laparoscopic cholecystectomy',
              quantity: 1,
              unit_price: 120,
              line_total: 120
            }
          ]
        }
      });
      expect(result.success).toBe(true);
      expect(result.data.billing.payment_status).toBe('PENDING');
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty description', () => {
      const data = { ...validData, description: '' };
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for performed_at', () => {
      const data = { ...validData, performed_at: 'invalid-date' };
      const result = createProcedureSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional clinical-request billing payload', () => {
      const result = createProcedureSchema.safeParse({
        ...validData,
        billing: {
          payment_status: 'PENDING',
          currency: 'USD',
          total_amount: 40,
          line_items: [
            {
              id: 'PROC-1',
              label: 'Wound care',
              quantity: 1,
              unit_price: 40,
              line_total: 40
            }
          ]
        }
      });
      expect(result.success).toBe(true);
    });
  });

  describe('updateProcedureSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateProcedureSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = {
        code: '47563',
        description: 'Updated procedure description'
      };
      const result = updateProcedureSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('procedureIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = procedureIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = procedureIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listProceduresQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listProceduresQuerySchema.safeParse({
        page: '1',
        limit: '20',
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        code: '47562'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listProceduresQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });
});
