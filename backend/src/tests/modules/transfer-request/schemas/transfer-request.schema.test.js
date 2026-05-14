/**
 * Transfer request schema tests
 *
 * @module tests/modules/transfer-request/schemas
 * @description Tests for transfer request validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createTransferRequestSchema,
  updateTransferRequestSchema,
  transferRequestIdParamsSchema,
  listTransferRequestsQuerySchema
} = require('@validations/transfer-request/transfer-request.schema');

describe('Transfer Request Schemas', () => {
  describe('createTransferRequestSchema', () => {
    const validData = {
      admission_id: '550e8400-e29b-41d4-a716-446655440000',
      from_ward_id: '550e8400-e29b-41d4-a716-446655440001',
      to_ward_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'REQUESTED',
      requested_at: '2026-01-19T00:00:00.000Z'
    };

    it('should validate correct transfer request data', () => {
      const result = createTransferRequestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require admission_id', () => {
      const data = { ...validData };
      delete data.admission_id;
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional from_ward_id', () => {
      const data = { ...validData };
      delete data.from_ward_id;
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional to_ward_id', () => {
      const data = { ...validData };
      delete data.to_ward_id;
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional requested_at', () => {
      const data = { ...validData };
      delete data.requested_at;
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - REQUESTED', () => {
      const data = { ...validData, status: 'REQUESTED' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - APPROVED', () => {
      const data = { ...validData, status: 'APPROVED' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - IN_PROGRESS', () => {
      const data = { ...validData, status: 'IN_PROGRESS' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - COMPLETED', () => {
      const data = { ...validData, status: 'COMPLETED' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - CANCELLED', () => {
      const data = { ...validData, status: 'CANCELLED' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status enum', () => {
      const data = { ...validData, status: 'INVALID_STATUS' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid admission_id UUID', () => {
      const data = { ...validData, admission_id: 'invalid-uuid' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid from_ward_id UUID', () => {
      const data = { ...validData, from_ward_id: 'invalid-uuid' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid to_ward_id UUID', () => {
      const data = { ...validData, to_ward_id: 'invalid-uuid' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null from_ward_id', () => {
      const data = { ...validData, from_ward_id: null };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null to_ward_id', () => {
      const data = { ...validData, to_ward_id: null };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid datetime format for requested_at', () => {
      const data = { ...validData, requested_at: 'invalid-date' };
      const result = createTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateTransferRequestSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateTransferRequestSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates with admission_id', () => {
      const data = { admission_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate partial updates with status', () => {
      const data = { status: 'APPROVED' };
      const result = updateTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = updateTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID fields when provided', () => {
      const data = { from_ward_id: 'invalid-uuid' };
      const result = updateTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null for optional ward fields', () => {
      const data = { from_ward_id: null, to_ward_id: null };
      const result = updateTransferRequestSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('transferRequestIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = transferRequestIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = transferRequestIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = transferRequestIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listTransferRequestsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listTransferRequestsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filter params', () => {
      const data = {
        admission_id: '550e8400-e29b-41d4-a716-446655440000',
        from_ward_id: '550e8400-e29b-41d4-a716-446655440001',
        to_ward_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'REQUESTED',
        search: 'test'
      };
      const result = listTransferRequestsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum in query', () => {
      const data = { status: 'INVALID_STATUS' };
      const result = listTransferRequestsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID filter fields', () => {
      const data = { admission_id: 'invalid-uuid' };
      const result = listTransferRequestsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all status enum values in query', () => {
      const statuses = ['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { status };
        const result = listTransferRequestsQuerySchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should trim search string', () => {
      const data = { search: '  test query  ' };
      const result = listTransferRequestsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test query');
      }
    });
  });
});
