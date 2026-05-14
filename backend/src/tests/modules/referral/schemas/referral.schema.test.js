/**
 * Referral schema tests
 *
 * @module tests/modules/referral/schemas
 * @description Tests for referral validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createReferralSchema,
  updateReferralSchema,
  referralIdParamsSchema,
  listReferralsQuerySchema
} = require('@validations/referral/referral.schema');

describe('Referral Schemas', () => {
  describe('createReferralSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      from_department_id: '550e8400-e29b-41d4-a716-446655440001',
      to_department_id: '550e8400-e29b-41d4-a716-446655440002',
      reason: 'Specialist consultation required',
      status: 'REQUESTED'
    };

    it('should validate correct referral data', () => {
      const result = createReferralSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should apply default status when omitted', () => {
      const data = { ...validData };
      delete data.status;
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data.status).toBe('REQUESTED');
    });

    it('should allow optional from_department_id', () => {
      const data = { ...validData };
      delete data.from_department_id;
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional to_department_id', () => {
      const data = { ...validData };
      delete data.to_department_id;
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional reason', () => {
      const data = { ...validData };
      delete data.reason;
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { 
          encounter_id: '550e8400-e29b-41d4-a716-446655440000',
          status 
        };
        const result = createReferralSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid UUIDs', () => {
      const data = { ...validData, encounter_id: 'not-a-uuid' };
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce reason max length', () => {
      const data = { ...validData, reason: 'x'.repeat(10001) };
      const result = createReferralSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateReferralSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        status: 'APPROVED',
        reason: 'Updated reason'
      };
      const result = updateReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { status: 'REQUESTED' };
      const result = updateReferralSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty object', () => {
      const result = updateReferralSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('referralIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = referralIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'not-a-uuid' };
      const result = referralIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = referralIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listReferralsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const data = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'REQUESTED',
        page: '1',
        limit: '20'
      };
      const result = listReferralsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional filters', () => {
      const data = { page: '1', limit: '20' };
      const result = listReferralsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status', () => {
      const data = { status: 'INVALID', page: '1', limit: '20' };
      const result = listReferralsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
