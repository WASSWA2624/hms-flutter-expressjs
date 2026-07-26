const {
  createFacilitySchema,
  updateFacilitySchema,
  facilityIdParamsSchema,
  listFacilitiesQuerySchema,
  facilityTypeEnum} = require('../../../../modules/facility/schemas/facility.schema');

describe('Facility Schema Validation', () => {
  describe('createFacilitySchema', () => {
    it('validates a complete facility payload including extension_json', () => {
      const result = createFacilitySchema.safeParse({
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Main Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        extension_json: {
          logo_url: 'https://example.com/facility-logo.png',
          timezone: 'Africa/Kampala',
          currency: 'UGX'}});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.extension_json).toEqual({
          logo_url: 'https://example.com/facility-logo.png',
          timezone: 'Africa/Kampala',
          currency: 'UGX'});
      }
    });

    it('allows null extension_json', () => {
      const result = createFacilitySchema.safeParse({
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Satellite Clinic',
        facility_type: 'CLINIC',
        extension_json: null});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.extension_json).toBeNull();
      }
    });

    it('rejects an invalid facility type', () => {
      const result = createFacilitySchema.safeParse({
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Unknown Facility',
        facility_type: 'INVALID'});

      expect(result.success).toBe(false);
    });
  });

  describe('updateFacilitySchema', () => {
    it('validates partial updates including branding metadata', () => {
      const result = updateFacilitySchema.safeParse({
        name: 'Updated Facility',
        extension_json: {
          website: 'https://facility.example.com',
          email: 'frontdesk@example.com'}});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.extension_json).toEqual({
          website: 'https://facility.example.com',
          email: 'frontdesk@example.com'});
      }
    });

    it('allows clearing extension_json during updates', () => {
      const result = updateFacilitySchema.safeParse({
        extension_json: null});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.extension_json).toBeNull();
      }
    });

    it('accepts confirm_similar and contact fields for similarity review', () => {
      const result = updateFacilitySchema.safeParse({
        name: 'Updated Facility',
        confirm_similar: true,
        phone: '+256700000000',
        email: 'ops@example.com',
        city: 'Kampala',
        country: 'UG'
      });

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.confirm_similar).toBe(true);
        expect(result.data.phone).toBe('+256700000000');
        expect(result.data.city).toBe('Kampala');
      }
    });
  });

  describe('facilityIdParamsSchema', () => {
    it('accepts valid facility ids', () => {
      const result = facilityIdParamsSchema.safeParse({
        id: '123e4567-e89b-12d3-a456-426614174000'});

      expect(result.success).toBe(true);
    });

    it('accepts friendly facility ids', () => {
      const result = facilityIdParamsSchema.safeParse({
        id: 'FAC0001'});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.id).toBe('FAC0001');
      }
    });

    it('rejects invalid facility ids', () => {
      const result = facilityIdParamsSchema.safeParse({
        id: 'not-a-valid-id'});

      expect(result.success).toBe(false);
    });
  });

  describe('listFacilitiesQuerySchema', () => {
    it('validates list filters and pagination', () => {
      const result = listFacilitiesQuerySchema.safeParse({
        page: '2',
        limit: '25',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_type: 'LAB',
        is_active: 'true',
        search: 'Main',
        phone: '700',
        email: 'ops@example.com',
        city: 'Kampala',
        country: 'UG'});

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(25);
        expect(result.data.facility_type).toBe('LAB');
        expect(result.data.phone).toBe('700');
        expect(result.data.city).toBe('Kampala');
      }
    });

    it('rejects invalid active filters', () => {
      const result = listFacilitiesQuerySchema.safeParse({
        is_active: 'maybe'});

      expect(result.success).toBe(false);
    });
  });

  describe('facilityTypeEnum', () => {
    it('exports the expected facility types', () => {
      expect(facilityTypeEnum.options).toEqual(['HOSPITAL', 'CLINIC', 'LAB', 'PHARMACY', 'OTHER']);
    });
  });
});
