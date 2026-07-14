const {
  resolveHeaderState,
  resolveDaysUntil,
  resolveNextTierCode,
  resolvePlatformAdminContact,
  resolvePlatformBankTransferDetails,
  COMMERCIAL_TIER_LADDER,
} = require('@lib/subscriptions/tenant-subscription-summary');

describe('tenant-subscription-summary', () => {
  describe('resolveNextTierCode', () => {
    it('walks the commercial ladder and stops at Custom', () => {
      expect(COMMERCIAL_TIER_LADDER).toEqual([
        'FREE',
        'BASIC',
        'ADVANCED',
        'PRO',
        'CUSTOM',
      ]);
      expect(resolveNextTierCode('FREE')).toBe('BASIC');
      expect(resolveNextTierCode('basic')).toBe('ADVANCED');
      expect(resolveNextTierCode('ADVANCED')).toBe('PRO');
      expect(resolveNextTierCode('PRO')).toBe('CUSTOM');
      expect(resolveNextTierCode('CUSTOM')).toBeNull();
      expect(resolveNextTierCode('DEVELOPER')).toBeNull();
    });
  });

  describe('resolveHeaderState', () => {
    it('returns active for healthy subscriptions', () => {
      expect(
        resolveHeaderState({
          status: 'ACTIVE',
          daysUntilExpiry: 30,
          expiringSoonDays: 14,
        })
      ).toBe('active');
    });

    it('returns expiring_soon within threshold', () => {
      expect(
        resolveHeaderState({
          status: 'TRIAL',
          daysUntilExpiry: 10,
          expiringSoonDays: 14,
        })
      ).toBe('expiring_soon');
    });

    it('returns expired for past due status', () => {
      expect(
        resolveHeaderState({
          status: 'PAST_DUE',
          daysUntilExpiry: 5,
          expiringSoonDays: 14,
        })
      ).toBe('expired');
    });
  });

  describe('resolveDaysUntil', () => {
    it('returns null when end date is missing', () => {
      expect(resolveDaysUntil(null)).toBeNull();
    });
  });

  describe('resolvePlatformAdminContact', () => {
    it('returns email and phone fields', () => {
      const contact = resolvePlatformAdminContact();
      expect(contact).toEqual({
        email: contact.email,
        phone: contact.phone,
      });
    });
  });

  describe('resolvePlatformBankTransferDetails', () => {
    it('returns null when bank details are not configured', () => {
      expect(resolvePlatformBankTransferDetails()).toBeNull();
    });
  });
});
