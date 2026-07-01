const {
  resolveHeaderState,
  resolveDaysUntil,
  resolvePlatformAdminContact,
} = require('@lib/subscriptions/tenant-subscription-summary');

describe('tenant-subscription-summary', () => {
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
});
