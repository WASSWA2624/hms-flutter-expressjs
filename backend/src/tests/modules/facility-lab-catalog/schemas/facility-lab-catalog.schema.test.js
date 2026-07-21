/**
 * Facility lab catalog schema validation tests
 */

const {
  listFacilityLabCatalogQuerySchema,
  searchFacilityLabCatalogQuerySchema,
  facilityLabTestParamsSchema} = require('@validations/facility-lab-catalog/facility-lab-catalog.schema');

describe('Facility Lab Catalog Schema Validation', () => {
  describe('listFacilityLabCatalogQuerySchema', () => {
    it('should accept friendly tenant and facility identifiers with limit 100', () => {
      const result = listFacilityLabCatalogQuerySchema.safeParse({
        tenant_id: 'TEN0000001',
        facility_id: 'FAC0000001',
        limit: '100',
        page: '1'});

      expect(result.success).toBe(true);
    });

    it('should accept UUID tenant and facility identifiers', () => {
      const result = listFacilityLabCatalogQuerySchema.safeParse({
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '223e4567-e89b-12d3-a456-426614174001',
        limit: 100});

      expect(result.success).toBe(true);
    });

    it('should reject limit above the shared pagination maximum', () => {
      const result = listFacilityLabCatalogQuerySchema.safeParse({
        tenant_id: 'TEN0000001',
        facility_id: 'FAC0000001',
        limit: '200'});

      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant identifiers', () => {
      const result = listFacilityLabCatalogQuerySchema.safeParse({
        tenant_id: 'not-a-valid-id',
        facility_id: 'FAC0000001'});

      expect(result.success).toBe(false);
    });
  });

  describe('searchFacilityLabCatalogQuerySchema', () => {
    it('should accept friendly scope identifiers', () => {
      const result = searchFacilityLabCatalogQuerySchema.safeParse({
        tenant_id: 'TEN0000001',
        facility_id: 'FAC0000001',
        term_type: 'LAB_TEST',
        q: 'cbc'});

      expect(result.success).toBe(true);
    });
  });

  describe('facilityLabTestParamsSchema', () => {
    it('should accept standard catalog lab test identifiers', () => {
      const result = facilityLabTestParamsSchema.safeParse({
        lab_test_id: 'STD_LAB_TEST:CBC'});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.lab_test_id).toBe('STD_LAB_TEST:CBC');
      }
    });

    it('should accept friendly lab test identifiers', () => {
      const result = facilityLabTestParamsSchema.safeParse({
        lab_test_id: 'LBT0000001'});

      expect(result.success).toBe(true);
    });

    it('should reject invalid lab test identifiers', () => {
      const result = facilityLabTestParamsSchema.safeParse({
        lab_test_id: 'not-a-valid-id'});

      expect(result.success).toBe(false);
    });
  });
});
