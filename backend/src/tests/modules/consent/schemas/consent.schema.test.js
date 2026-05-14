/**
 * Consent schema tests
 *
 * @module tests/modules/consent/schemas
 * @description Tests for consent validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createConsentSchema,
  updateConsentSchema,
  consentIdParamsSchema,
  listConsentsQuerySchema
} = require('@validations/consent/consent.schema');

describe('Consent Schemas', () => {
  describe('createConsentSchema', () => {
    const validData = {
      patient_id: '550e8400-e29b-41d4-a716-446655440000',
      consent_type: 'TREATMENT',
      status: 'GRANTED',
      granted_at: '2026-01-19T10:00:00.000Z',
      revoked_at: null
    };

    it('should validate correct consent data', () => {
      const result = createConsentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require consent_type', () => {
      const data = { ...validData };
      delete data.consent_type;
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate consent_type enum values', () => {
      const data = { ...validData, consent_type: 'INVALID' };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid consent_type values', () => {
      const types = ['TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER'];
      types.forEach(consent_type => {
        const data = { ...validData, consent_type };
        const result = createConsentSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['GRANTED', 'REVOKED', 'PENDING'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createConsentSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional granted_at', () => {
      const data = { ...validData };
      delete data.granted_at;
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional revoked_at', () => {
      const data = { ...validData };
      delete data.revoked_at;
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null granted_at', () => {
      const data = { ...validData, granted_at: null };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null revoked_at', () => {
      const data = { ...validData, revoked_at: null };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for granted_at', () => {
      const data = { ...validData, granted_at: 'invalid-date' };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for revoked_at', () => {
      const data = { ...validData, revoked_at: 'invalid-date' };
      const result = createConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateConsentSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        consent_type: 'DATA_SHARING',
        status: 'REVOKED',
        revoked_at: '2026-01-19T10:00:00.000Z'
      };
      const result = updateConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow all fields to be optional', () => {
      const result = updateConsentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate consent_type enum if provided', () => {
      const data = { consent_type: 'INVALID' };
      const result = updateConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID' };
      const result = updateConsentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow null for granted_at', () => {
      const data = { granted_at: null };
      const result = updateConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null for revoked_at', () => {
      const data = { revoked_at: null };
      const result = updateConsentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('consentIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = consentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = consentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = consentIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listConsentsQuerySchema', () => {
    it('should validate correct query params', () => {
      const query = {
        page: 1,
        limit: 10,
        sort_by: 'created_at',
        order: 'desc',
        patient_id: '550e8400-e29b-41d4-a716-446655440000',
        consent_type: 'TREATMENT',
        status: 'GRANTED'
      };
      const result = listConsentsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should allow all fields to be optional', () => {
      const result = listConsentsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate patient_id UUID format if provided', () => {
      const query = { patient_id: 'invalid-uuid' };
      const result = listConsentsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate consent_type enum if provided', () => {
      const query = { consent_type: 'INVALID' };
      const result = listConsentsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate status enum if provided', () => {
      const query = { status: 'INVALID' };
      const result = listConsentsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should accept valid consent_type values', () => {
      const types = ['TREATMENT', 'DATA_SHARING', 'RESEARCH', 'BILLING', 'OTHER'];
      types.forEach(consent_type => {
        const query = { consent_type };
        const result = listConsentsQuerySchema.safeParse(query);
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid status values', () => {
      const statuses = ['GRANTED', 'REVOKED', 'PENDING'];
      statuses.forEach(status => {
        const query = { status };
        const result = listConsentsQuerySchema.safeParse(query);
        expect(result.success).toBe(true);
      });
    });
  });
});
