const { ROLES } = require('@config/roles');
const { resolveDashboardRole, resolveEffectiveRole } = require('@lib/dashboard/summary');

describe('dashboard summary role resolution', () => {
  it('resolveDashboardRole prefers operational role over manager overlay', () => {
    expect(
      resolveDashboardRole({ roles: [ROLES.DOCTOR, ROLES.THEATRE_MANAGER] })
    ).toBe(ROLES.DOCTOR);
    expect(
      resolveDashboardRole({
        roles: [ROLES.NURSE, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER],
      })
    ).toBe(ROLES.NURSE);
    expect(
      resolveDashboardRole({ roles: [ROLES.BIOMED, ROLES.BIOMED_MANAGER] })
    ).toBe(ROLES.BIOMED);
    expect(
      resolveDashboardRole({
        roles: [ROLES.HOUSE_KEEPER, ROLES.HOUSEKEEPING_MANAGER],
      })
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
