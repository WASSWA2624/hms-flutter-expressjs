const {
  extractStorageKeyFromLogoUrl,
  resolveFacilityLogoUploadKey,
  deleteFacilityLogoFromStorage,
  buildStableFacilityLogoKey,
  buildFacilityLogoPublicPath,
  MAX_FACILITY_LOGO_BASENAME} = require('@lib/storage/facility-logo-storage');

describe('facility-logo-storage', () => {
  describe('buildStableFacilityLogoKey', () => {
    it('builds a short stable key within 32 characters', () => {
      const key = buildStableFacilityLogoKey(
        'fbb67a68-8fea-4eed-a072-4869585d8466'
      );
      expect(key).toBe('logo-585d8466.png');
      expect(key.length).toBeLessThanOrEqual(MAX_FACILITY_LOGO_BASENAME);
    });
  });

  describe('extractStorageKeyFromLogoUrl', () => {
    it('returns sanitized relative keys', () => {
      expect(extractStorageKeyFromLogoUrl('logo-4869585d.png')).toBe(
        'logo-4869585d.png'
      );
    });

    it('strips query strings and uploads prefix', () => {
      expect(
        extractStorageKeyFromLogoUrl('/uploads/logo-4869585d.png?v=123')
      ).toBe('logo-4869585d.png');
    });

    it('extracts the filename from absolute URLs', () => {
      expect(
        extractStorageKeyFromLogoUrl(
          'https://cdn.example.com/uploads/logo-4869585d.png?v=9'
        )
      ).toBe('logo-4869585d.png');
    });
  });

  describe('resolveFacilityLogoUploadKey', () => {
    it('always targets the stable short key', () => {
      const result = resolveFacilityLogoUploadKey({
        facilityId: 'fbb67a68-8fea-4eed-a072-4869585d8466',
        existingLogoUrl: null});
      expect(result.storageKey).toBe('logo-585d8466.png');
      expect(result.previousKey).toBeNull();
    });

    it('returns previousKey when migrating from a long legacy name', () => {
      const result = resolveFacilityLogoUploadKey({
        facilityId: 'fbb67a68-8fea-4eed-a072-4869585d8466',
        existingLogoUrl:
          'facilities_tenant_fbb67a68-8fea-4eed-a072-4869585d8466_branding_logo.png?v=1'});
      expect(result.storageKey).toBe('logo-585d8466.png');
      expect(result.previousKey).toBe(
        'facilities_tenant_fbb67a68-8fea-4eed-a072-4869585d8466_branding_logo.png'
      );
    });
  });

  describe('buildFacilityLogoPublicPath', () => {
    it('builds an /uploads public path with cache busting', () => {
      expect(
        buildFacilityLogoPublicPath('logo-4869585d.png', { cacheBust: 99 })
      ).toBe('/uploads/logo-4869585d.png?v=99');
    });
  });

  describe('deleteFacilityLogoFromStorage', () => {
    it('deletes the resolved storage key', async () => {
      const storage = {
        delete: jest.fn().mockResolvedValue(true)};

      const deleted = await deleteFacilityLogoFromStorage(
        storage,
        '/uploads/logo-4869585d.png?v=2'
      );

      expect(deleted).toBe(true);
      expect(storage.delete).toHaveBeenCalledWith('logo-4869585d.png');
    });

    it('returns false when delete fails', async () => {
      const storage = {
        delete: jest.fn().mockRejectedValue(new Error('boom'))};

      await expect(
        deleteFacilityLogoFromStorage(storage, 'logo-4869585d.png')
      ).resolves.toBe(false);
    });
  });
});
