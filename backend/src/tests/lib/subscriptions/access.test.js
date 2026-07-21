const { HttpError } = require('@lib/errors');
const {
  canManageSubscriptionBilling,
  resolveBillingTenantScope} = require('@lib/subscriptions/access');

describe('subscription access helpers', () => {
  test('canManageSubscriptionBilling allows tenant and facility admins', () => {
    expect(
      canManageSubscriptionBilling({ roles: ['TENANT_ADMIN'], tenant_id: 'tenant-1' })
    ).toBe(true);
    expect(
      canManageSubscriptionBilling({ roles: ['FACILITY_ADMIN'], tenant_id: 'tenant-1' })
    ).toBe(true);
    expect(
      canManageSubscriptionBilling({ roles: ['NURSE'], tenant_id: 'tenant-1' })
    ).toBe(false);
  });

  test('resolveBillingTenantScope pins tenant admins to their own tenant', () => {
    expect(() =>
      resolveBillingTenantScope(
        { roles: ['TENANT_ADMIN'], tenant_id: 'tenant-1' },
        { tenant_id: 'tenant-2' }
      )
    ).toThrow(HttpError);

    expect(
      resolveBillingTenantScope(
        { roles: ['TENANT_ADMIN'], tenant_id: 'tenant-1' },
        {}
      )
    ).toBe('tenant-1');
  });

  test('resolveBillingTenantScope rejects cross-tenant payment payloads', () => {
    try {
      resolveBillingTenantScope(
        { roles: ['FACILITY_ADMIN'], tenant_id: 'tenant-1' },
        { tenantId: 'tenant-9' }
      );
      throw new Error('expected scope mismatch');
    } catch (error) {
      expect(error).toBeInstanceOf(HttpError);
      expect(error.messageKey).toBe('errors.auth.scope_mismatch');
      expect(error.statusCode).toBe(403);
    }
  });
});
