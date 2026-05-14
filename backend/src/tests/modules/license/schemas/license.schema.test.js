/**
 * License schema validation tests
 *
 * @module tests/modules/license/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createLicenseSchema,
  updateLicenseSchema,
  licenseIdParamsSchema,
  listLicensesQuerySchema
} = require('@validations/license/license.schema');

describe('License Schema Validation', () => {
  const validUuid = '123e4567-e89b-12d3-a456-426614174000';
  const validDatetime = '2026-01-19T12:00:00.000Z';

  describe('createLicenseSchema', () => {
    it('should validate correct license data', () => {
      const validData = {
        tenant_id: validUuid,
        license_type: 'PER_USER',
        status: 'ACTIVE',
        issued_at: validDatetime,
        expires_at: validDatetime
      };
      const result = createLicenseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data', () => {
      const validData = {
        tenant_id: validUuid,
        license_type: 'ENTERPRISE',
        status: 'TRIAL'
      };
      const result = createLicenseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        license_type: 'PER_USER',
        status: 'ACTIVE'
      };
      const result = createLicenseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid license_type', () => {
      const invalidData = {
        tenant_id: validUuid,
        license_type: 'INVALID',
        status: 'ACTIVE'
      };
      const result = createLicenseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: validUuid,
        license_type: 'PER_USER',
        status: 'INVALID'
      };
      const result = createLicenseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateLicenseSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        tenant_id: validUuid,
        license_type: 'PER_FACILITY',
        status: 'PAST_DUE',
        expires_at: validDatetime
      };
      const result = updateLicenseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};
      const result = updateLicenseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('licenseIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = { id: validUuid };
      const result = licenseIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'not-a-uuid' };
      const result = licenseIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listLicensesQuerySchema', () => {
    it('should validate with all filters', () => {
      const validData = {
        tenant_id: validUuid,
        license_type: 'PER_USER',
        status: 'ACTIVE',
        page: 1,
        limit: 20
      };
      const result = listLicensesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty query', () => {
      const validData = {};
      const result = listLicensesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });
});
