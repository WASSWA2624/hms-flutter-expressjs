/**
 * Asset schema tests
 *
 * @module tests/modules/asset/schemas
 * @description Tests for asset Zod validation schemas
 */

const {
  createAssetSchema,
  updateAssetSchema,
  assetIdParamsSchema,
  listAssetsQuerySchema,
  maintenanceStatusEnum
} = require('../../../../modules/asset/schemas/asset.schema');

describe('Asset Schemas', () => {
  describe('maintenanceStatusEnum', () => {
    it('should accept valid maintenance status values', () => {
      const validStatuses = ['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
      validStatuses.forEach(status => {
        expect(() => maintenanceStatusEnum.parse(status)).not.toThrow();
      });
    });

    it('should reject invalid maintenance status values', () => {
      expect(() => maintenanceStatusEnum.parse('INVALID')).toThrow();
      expect(() => maintenanceStatusEnum.parse('pending')).toThrow();
    });
  });

  describe('createAssetSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Medical Equipment',
        asset_tag: 'MED-001',
        status: 'OPEN'
      };

      expect(() => createAssetSchema.parse(validData)).not.toThrow();
    });

    it('should validate minimal create data', () => {
      const minimalData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Equipment',
        status: 'OPEN'
      };

      expect(() => createAssetSchema.parse(minimalData)).not.toThrow();
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      expect(() => createAssetSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Equipment',
        status: 'OPEN'
      };

      expect(() => createAssetSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Equipment',
        status: 'INVALID_STATUS'
      };

      expect(() => createAssetSchema.parse(invalidData)).toThrow();
    });

    it('should accept null for optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Equipment',
        asset_tag: null,
        status: 'OPEN'
      };

      expect(() => createAssetSchema.parse(validData)).not.toThrow();
    });

    it('should reject name exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(256),
        status: 'OPEN'
      };

      expect(() => createAssetSchema.parse(invalidData)).toThrow();
    });
  });

  describe('updateAssetSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        name: 'Updated Equipment',
        asset_tag: 'MED-002',
        status: 'COMPLETED'
      };

      expect(() => updateAssetSchema.parse(validData)).not.toThrow();
    });

    it('should allow empty update object', () => {
      expect(() => updateAssetSchema.parse({})).not.toThrow();
    });

    it('should allow partial updates', () => {
      const partialData = {
        status: 'IN_PROGRESS'
      };

      expect(() => updateAssetSchema.parse(partialData)).not.toThrow();
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };

      expect(() => updateAssetSchema.parse(invalidData)).toThrow();
    });
  });

  describe('assetIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      expect(() => assetIdParamsSchema.parse(validParams)).not.toThrow();
    });

    it('should reject invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      expect(() => assetIdParamsSchema.parse(invalidParams)).toThrow();
    });

    it('should reject missing id', () => {
      expect(() => assetIdParamsSchema.parse({})).toThrow();
    });
  });

  describe('listAssetsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Equipment',
        asset_tag: 'MED-001',
        status: 'OPEN',
        search: 'medical',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      expect(() => listAssetsQuerySchema.parse(validQuery)).not.toThrow();
    });

    it('should validate query with minimal parameters', () => {
      expect(() => listAssetsQuerySchema.parse({})).not.toThrow();
    });

    it('should reject invalid status in query', () => {
      const invalidQuery = {
        status: 'INVALID_STATUS'
      };

      expect(() => listAssetsQuerySchema.parse(invalidQuery)).toThrow();
    });

    it('should reject invalid UUID in query', () => {
      const invalidQuery = {
        tenant_id: 'not-a-uuid'
      };

      expect(() => listAssetsQuerySchema.parse(invalidQuery)).toThrow();
    });
  });
});
