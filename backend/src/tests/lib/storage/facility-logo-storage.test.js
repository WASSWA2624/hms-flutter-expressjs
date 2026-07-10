const {
  extractStorageKeyFromLogoUrl,
  resolveFacilityLogoUploadKey,
  deleteFacilityLogoFromStorage,
} = require('@lib/storage/facility-logo-storage');

describe('facility-logo-storage', () => {
  describe('extractStorageKeyFromLogoUrl', () => {
    it('returns sanitized relative keys', () => {
      expect(
        extractStorageKeyFromLogoUrl(
          'facilities_tenant_facility_branding_main-campus-logo.png'
        )
      ).toBe('facilities_tenant_facility_branding_main-campus-logo.png');
    });

    it('strips query strings and uploads prefix', () => {
      expect(
        extractStorageKeyFromLogoUrl(
          '/uploads/facilities_tenant_facility_branding_logo.png?v=123'
        )
      ).toBe('facilities_tenant_facility_branding_logo.png');
    });

    it('extracts the filename from absolute URLs', () => {
      expect(
        extractStorageKeyFromLogoUrl(
          'https://cdn.example.com/files/facilities_tenant_facility_branding_logo.png?v=9'
        )
      ).toBe('facilities_tenant_facility_branding_logo.png');
    });
  });

  describe('resolveFacilityLogoUploadKey', () => {
    it('reuses the existing facility logo key on replace', () => {
      const key = resolveFacilityLogoUploadKey({
        facilityId: 'facility-uuid',
        existingLogoUrl:
          'facilities_tenant_facility-uuid_branding_old-name-logo.png?v=1',
        fallbackKey:
          'facilities/tenant/facility-uuid/branding/new-name-logo.png',
      });

      expect(key).toBe(
        'facilities_tenant_facility-uuid_branding_old-name-logo.png'
      );
    });

    it('falls back to the canonical key when no existing logo', () => {
      const key = resolveFacilityLogoUploadKey({
        facilityId: 'facility-uuid',
        existingLogoUrl: null,
        fallbackKey:
          'facilities/tenant/facility-uuid/branding/main-campus-logo.png',
      });

      expect(key).toBe(
        'facilities_tenant_facility-uuid_branding_main-campus-logo.png'
      );
    });
  });

  describe('deleteFacilityLogoFromStorage', () => {
    it('deletes the resolved storage key', async () => {
      const storage = {
        delete: jest.fn().mockResolvedValue(true),
      };

      const deleted = await deleteFacilityLogoFromStorage(
        storage,
        'facilities_tenant_facility_branding_logo.png?v=2'
      );

      expect(deleted).toBe(true);
      expect(storage.delete).toHaveBeenCalledWith(
        'facilities_tenant_facility_branding_logo.png'
      );
    });

    it('returns false when delete fails', async () => {
      const storage = {
        delete: jest.fn().mockRejectedValue(new Error('boom')),
      };

      await expect(
        deleteFacilityLogoFromStorage(storage, 'facilities_x_logo.png')
      ).resolves.toBe(false);
    });
  });
});
