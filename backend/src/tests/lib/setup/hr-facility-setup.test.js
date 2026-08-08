const {
  HR_FACILITY_SETUP_MODULE_IDS,
  canAccessHrFacilitySetup,
  canAccessSettingsWorkspace,
  canWriteHrFacilitySetup,
  canWriteSetupModule,
  filterSetupModulesForUser,
  isAdminSetupUser,
  isHrSetupOnlyUser} = require('@lib/setup/hr-facility-setup');

describe('hr-facility-setup policy', () => {
  const hrUser = {
    roles: ['HR'],
    permissions: ['hr:read', 'hr:write', 'unit:manage']};

  const facilityAdminUser = {
    roles: ['FACILITY_ADMIN'],
    permissions: ['facility:admin']};

  it('identifies HR-only setup users', () => {
    expect(isHrSetupOnlyUser(hrUser)).toBe(true);
    expect(isHrSetupOnlyUser(facilityAdminUser)).toBe(false);
  });

  it('limits visible setup modules for HR-only users', () => {
    const modules = [
      { id: 'tenant' },
      { id: 'department' },
      { id: 'unit' },
      { id: 'user' },
      { id: 'role' },
      { id: 'permission' }];

    expect(filterSetupModulesForUser(modules, hrUser).map((entry) => entry.id)).toEqual(
      ['user', 'role', 'permission'],
    );
    expect(HR_FACILITY_SETUP_MODULE_IDS).toEqual(
      expect.arrayContaining(['user', 'role', 'permission']),
    );
    expect(filterSetupModulesForUser(modules, facilityAdminUser)).toHaveLength(6);
  });

  it('allows HR write only on HR facility setup modules', () => {
    expect(canWriteSetupModule(hrUser, 'user')).toBe(true);
    expect(canWriteSetupModule(hrUser, 'role')).toBe(true);
    expect(canWriteSetupModule(hrUser, 'permission')).toBe(true);
    expect(canWriteSetupModule(hrUser, 'department')).toBe(false);
    expect(canWriteSetupModule(hrUser, 'tenant')).toBe(false);
    expect(canWriteSetupModule(facilityAdminUser, 'tenant')).toBe(true);
  });

  it('gates settings workspace access for HR and admins', () => {
    expect(canAccessSettingsWorkspace(hrUser)).toBe(true);
    expect(canAccessSettingsWorkspace(facilityAdminUser)).toBe(true);
    expect(canAccessHrFacilitySetup(hrUser)).toBe(true);
    expect(canWriteHrFacilitySetup(hrUser)).toBe(true);
    expect(isAdminSetupUser(hrUser)).toBe(false);
  });
});
