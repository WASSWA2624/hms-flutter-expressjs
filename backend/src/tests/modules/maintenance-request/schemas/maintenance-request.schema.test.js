/**
 * Maintenance request schema tests
 *
 * @module tests/modules/maintenance-request/schemas
 * @description Tests for maintenance request Zod validation schemas
 */

const {
  createMaintenanceRequestSchema,
  updateMaintenanceRequestSchema,
  maintenanceRequestIdParamsSchema,
  listMaintenanceRequestsQuerySchema,
  maintenanceStatusEnum
} = require('../../../../modules/maintenance-request/schemas/maintenance-request.schema');

describe('Maintenance Request Schemas', () => {
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

  describe('createMaintenanceRequestSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        asset_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'OPEN',
        description: 'Broken equipment needs repair',
        reported_at: '2026-01-19T10:00:00Z'
      };

      expect(() => createMaintenanceRequestSchema.parse(validData)).not.toThrow();
    });

    it('should validate minimal create data', () => {
      const minimalData = {
        status: 'OPEN'
      };

      expect(() => createMaintenanceRequestSchema.parse(minimalData)).not.toThrow();
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };

      expect(() => createMaintenanceRequestSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid UUID format for facility_id', () => {
      const invalidData = {
        facility_id: 'invalid-uuid',
        status: 'OPEN'
      };

      expect(() => createMaintenanceRequestSchema.parse(invalidData)).toThrow();
    });

    it('should reject invalid datetime format', () => {
      const invalidData = {
        status: 'OPEN',
        reported_at: 'not-a-datetime'
      };

      expect(() => createMaintenanceRequestSchema.parse(invalidData)).toThrow();
    });

    it('should accept null for optional fields', () => {
      const validData = {
        facility_id: null,
        asset_id: null,
        status: 'OPEN',
        description: null,
        resolved_at: null
      };

      expect(() => createMaintenanceRequestSchema.parse(validData)).not.toThrow();
    });
  });

  describe('updateMaintenanceRequestSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        status: 'COMPLETED',
        description: 'Repair completed successfully',
        resolved_at: '2026-01-19T15:00:00Z'
      };

      expect(() => updateMaintenanceRequestSchema.parse(validData)).not.toThrow();
    });

    it('should allow empty update object', () => {
      expect(() => updateMaintenanceRequestSchema.parse({})).not.toThrow();
    });

    it('should allow partial updates', () => {
      const partialData = {
        status: 'IN_PROGRESS'
      };

      expect(() => updateMaintenanceRequestSchema.parse(partialData)).not.toThrow();
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };

      expect(() => updateMaintenanceRequestSchema.parse(invalidData)).toThrow();
    });
  });

  describe('maintenanceRequestIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      expect(() => maintenanceRequestIdParamsSchema.parse(validParams)).not.toThrow();
    });

    it('should reject invalid UUID', () => {
      const invalidParams = {
        id: 'invalid-uuid'
      };

      expect(() => maintenanceRequestIdParamsSchema.parse(invalidParams)).toThrow();
    });

    it('should reject missing id', () => {
      expect(() => maintenanceRequestIdParamsSchema.parse({})).toThrow();
    });
  });

  describe('listMaintenanceRequestsQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        asset_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'OPEN',
        search: 'repair',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      expect(() => listMaintenanceRequestsQuerySchema.parse(validQuery)).not.toThrow();
    });

    it('should validate query with minimal parameters', () => {
      expect(() => listMaintenanceRequestsQuerySchema.parse({})).not.toThrow();
    });

    it('should reject invalid status in query', () => {
      const invalidQuery = {
        status: 'INVALID_STATUS'
      };

      expect(() => listMaintenanceRequestsQuerySchema.parse(invalidQuery)).toThrow();
    });

    it('should reject invalid UUID in query', () => {
      const invalidQuery = {
        facility_id: 'not-a-uuid'
      };

      expect(() => listMaintenanceRequestsQuerySchema.parse(invalidQuery)).toThrow();
    });
  });
});
