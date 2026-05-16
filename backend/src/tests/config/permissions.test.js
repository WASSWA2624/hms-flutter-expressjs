const { ROLES, normalizeRoleName } = require('@config/roles');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');

describe('permissions config', () => {
  it('includes AMBULANCE_OPERATOR in the canonical role catalog', () => {
    expect(ROLES.AMBULANCE_OPERATOR).toBe('AMBULANCE_OPERATOR');
    expect(ROLE_PERMISSIONS[ROLES.AMBULANCE_OPERATOR]).toBeDefined();
  });

  it('includes RADIOLOGY_TECH in the canonical role catalog', () => {
    expect(ROLES.RADIOLOGY_TECH).toBe('RADIOLOGY_TECH');
    expect(ROLE_PERMISSIONS[ROLES.RADIOLOGY_TECH]).toEqual(
      expect.arrayContaining([PERMISSIONS.RADIOLOGY_READ, PERMISSIONS.RADIOLOGY_WRITE, PERMISSIONS.PATIENT_READ])
    );
  });

  it('grants emergency read/write and not emergency delete to AMBULANCE_OPERATOR', () => {
    const permissions = ROLE_PERMISSIONS[ROLES.AMBULANCE_OPERATOR] || [];

    expect(permissions).toEqual(
      expect.arrayContaining([PERMISSIONS.PROFILE_READ, PERMISSIONS.EMERGENCY_READ, PERMISSIONS.EMERGENCY_WRITE])
    );
    expect(permissions).not.toContain(PERMISSIONS.EMERGENCY_DELETE);
  });

  it('grants emergency delete to admin roles', () => {
    const superAdminPermissions = ROLE_PERMISSIONS[ROLES.SUPER_ADMIN] || [];
    const tenantAdminPermissions = ROLE_PERMISSIONS[ROLES.TENANT_ADMIN] || [];
    const facilityAdminPermissions = ROLE_PERMISSIONS[ROLES.FACILITY_ADMIN] || [];

    expect(superAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
    expect(tenantAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
    expect(facilityAdminPermissions).toContain(PERMISSIONS.EMERGENCY_DELETE);
  });

  it('normalizes ambulance legacy aliases to AMBULANCE_OPERATOR', () => {
    expect(normalizeRoleName('ambulance_driver')).toBe(ROLES.AMBULANCE_OPERATOR);
    expect(normalizeRoleName('EMT')).toBe(ROLES.AMBULANCE_OPERATOR);
    expect(normalizeRoleName('paramedic')).toBe(ROLES.AMBULANCE_OPERATOR);
  });

  it('normalizes radiology legacy aliases to RADIOLOGY_TECH', () => {
    expect(normalizeRoleName('radiographer')).toBe(ROLES.RADIOLOGY_TECH);
    expect(normalizeRoleName('radiology_technician')).toBe(ROLES.RADIOLOGY_TECH);
    expect(normalizeRoleName('imaging_tech')).toBe(ROLES.RADIOLOGY_TECH);
  });

  it('normalizes display-form administrator roles to canonical roles', () => {
    expect(normalizeRoleName('Super Admin')).toBe(ROLES.SUPER_ADMIN);
    expect(normalizeRoleName('super-admin')).toBe(ROLES.SUPER_ADMIN);
    expect(normalizeRoleName('superadmin')).toBe(ROLES.SUPER_ADMIN);
    expect(normalizeRoleName('Administrator')).toBe(ROLES.TENANT_ADMIN);
  });
});
