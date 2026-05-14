/**
 * Asset service log schema tests
 *
 * @module tests/modules/asset-service-log/schemas
 * @description Tests for asset service log Zod validation schemas
 */

const {
  createAssetServiceLogSchema,
  updateAssetServiceLogSchema,
  assetServiceLogIdParamsSchema,
  listAssetServiceLogsQuerySchema
} = require('../../../../modules/asset-service-log/schemas/asset-service-log.schema');

describe('Asset Service Log Schemas', () => {
  describe('createAssetServiceLogSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000',
        serviced_at: '2026-01-19T10:00:00Z',
        notes: 'Routine maintenance performed'
      };

      expect(() => createAssetServiceLogSchema.parse(validData)).not.toThrow();
    });

    it('should validate minimal create data', () => {
      const minimalData = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      expect(() => createAssetServiceLogSchema.parse(minimalData)).not.toThrow();
    });

    it('should reject missing required asset_id', () => {
      const invalidData = {
        notes: 'Some notes'
      };

      expect(() => createAssetServiceLogSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid UUID format for asset_id', () => {
      const invalidData = {
        asset_id: 'invalid-uuid'
      };

      expect(() => createAssetServiceLogSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid datetime format', () => {
      const invalidData = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000',
        serviced_at: 'not-a-datetime'
      };

      expect(() => createAssetServiceLogSchema.parse(invalidData)).toThrow();
    });

    it('should accept null for optional fields', () => {
      const validData = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000',
        notes: null
      };

      expect(() => createAssetServiceLogSchema.parse(validData)).not.toThrow();
    });
  });

  describe('updateAssetServiceLogSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        serviced_at: '2026-01-19T15:00:00Z',
        notes: 'Updated service notes'
      };

      expect(() => updateAssetServiceLogSchema.parse(validData)).not.toThrow();
    });

    it('should allow empty update object', () => {
      expect(() => updateAssetServiceLogSchema.parse({})).not.toThrow();
    });

    it('should allow partial updates', () => {
      const partialData = {
        notes: 'Just updating notes'
      };

      expect(() => updateAssetServiceLogSchema.parse(partialData)).not.toThrow();
    });

    it('should reject invalid datetime format', () => {
      const invalidData = {
        serviced_at: 'not-a-valid-datetime'
      };

      expect(() => updateAssetServiceLogSchema.parse(invalidData)).toThrow();
    });
  });

  describe('assetServiceLogIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      expect(() => assetServiceLogIdParamsSchema.parse(validParams)).not.toThrow();
    });

    it('should reject invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      expect(() => assetServiceLogIdParamsSchema.parse(invalidParams)).toThrow();
    });

    it('should reject missing id', () => {
      expect(() => assetServiceLogIdParamsSchema.parse({})).toThrow();
    });
  });

  describe('listAssetServiceLogsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000',
        search: 'maintenance',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      expect(() => listAssetServiceLogsQuerySchema.parse(validQuery)).not.toThrow();
    });

    it('should validate query with minimal parameters', () => {
      expect(() => listAssetServiceLogsQuerySchema.parse({})).not.toThrow();
    });

    it('should reject invalid UUID in query', () => {
      const invalidQuery = {
        asset_id: 'not-a-uuid'
      };

      expect(() => listAssetServiceLogsQuerySchema.parse(invalidQuery)).toThrow();
    });
  });
});
