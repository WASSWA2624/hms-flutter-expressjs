const { ROLES } = require('@config/roles');
const { resolveDashboardRole, resolveEffectiveRole } = require('@lib/dashboard/summary');

describe('dashboard summary role resolution', () => {
  it('resolveDashboardRole prefers operational role over manager overlay', () => {
    expect(
      resolveDashboardRole({ roles: [ROLES.DOCTOR, ROLES.THEATRE_MANAGER] })
    ).toBe(ROLES.DOCTOR);
    expect(
      resolveDashboardRole({
        roles: [ROLES.NURSE, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER]})
    ).toBe(ROLES.NURSE);
    expect(
      resolveDashboardRole({ roles: [ROLES.BIOMED, ROLES.BIOMED_MANAGER] })
    ).toBe(ROLES.BIOMED);
    expect(
      resolveDashboardRole({
        roles: [ROLES.HOUSE_KEEPER, ROLES.HOUSEKEEPING_MANAGER]})
    ).toBe(ROLES.HOUSE_KEEPER);
  });

  it('resolveDashboardRole keeps tenant admin over unit manager overlay', () => {
    expect(
      resolveDashboardRole({ roles: [ROLES.TENANT_ADMIN, ROLES.UNIT_MANAGER] })
    ).toBe(ROLES.TENANT_ADMIN);
  });

  it('resolveEffectiveRole still prefers highest ranked role', () => {
    expect(
      resolveEffectiveRole({ roles: [ROLES.DOCTOR, ROLES.THEATRE_MANAGER] })
    ).toBe(ROLES.THEATRE_MANAGER);
  });
});

const { ROLE_PACKS, metricsToRoleSummary } = require('@lib/dashboard/summary');

describe('super admin dashboard summary cards', () => {
  it('maps subscription health to tenant coverage instead of subscription record counts', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.SUPER_ADMIN, {
      tenantsTotal: 3,
      tenantsActive: 3,
      tenantsWithoutSubscription: 2,
      tenantsWithSubscription: 1,
      facilitiesTotal: 1,
      facilitiesActive: 1,
      subscriptionsTotal: 1,
      subscriptionsActive: 1,
      moduleEntitlementIssues: 0});

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'subscriptions_health',
          value: 1,
          secondary_value: 3,
          format: 'ratio',
          hint: '2 tenants without subscription'}),
        expect.objectContaining({
          id: 'facilities_active',
          value: 1,
          secondary_value: 1,
          format: 'ratio'})])
    );
  });
});

describe('tenant admin dashboard summary cards', () => {
  it('maps tenant facility governance metrics with ratio and percent formats', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.TENANT_ADMIN, {
      facilitiesTotal: 3,
      facilitiesActive: 2,
      activeUsers: 18,
      moduleAdoption: 75,
      subscriptionHealth: 100});

    expect(cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'facilities_active',
          value: 2,
          secondary_value: 3,
          format: 'ratio'}),
        expect.objectContaining({
          id: 'active_users',
          value: 18}),
        expect.objectContaining({
          id: 'module_adoption',
          value: 75,
          format: 'percent'}),
        expect.objectContaining({
          id: 'subscription_health',
          value: 100,
          format: 'percent'})])
    );
    expect(cards).toHaveLength(4);
  });
});
