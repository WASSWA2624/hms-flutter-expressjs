/**
 * Created user access tests
 *
 * @module tests/modules/user/created-access
 * @description A newly created account's effective permissions come only from
 * the roles and direct grants assigned to it. A job title, a missing role, or
 * stale rows on a system role never add access.
 */

const { resolveEffectiveAccess } = require('@lib/authorization/effective-access');
const { ROLE_PERMISSIONS, PERMISSIONS } = require('@config/permissions');

const baseUser = {
  id: 'user-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  status: 'ACTIVE',
  position_title: 'Medical Director',
  permissions: [],
  module_assignments: []};

const roleEntry = (name, permissionNames = []) => ({
  role: {
    name,
    permissions: permissionNames.map((permissionName) => ({
      permission: { name: permissionName }}))}});

describe('created user access', () => {
  it('grants nothing when no role or direct permission is assigned', () => {
    const access = resolveEffectiveAccess({ ...baseUser, roles: [] });

    expect(access.permissions).toEqual([]);
  });

  it('grants only the permissions attached to an assigned custom role', () => {
    const customPermissions = [PERMISSIONS.PATIENT_READ, PERMISSIONS.CLINICAL_READ];
    // The subscription plan gate is exercised elsewhere; switch it off here so
    // the assertion isolates what the role itself grants.
    const access = resolveEffectiveAccess(
      { ...baseUser, roles: [roleEntry('WARD_CLERK_CUSTOM', customPermissions)] },
      { applyPlanGate: false }
    );

    expect([...access.grant_union].sort()).toEqual([...customPermissions].sort());
    // reports:read is the documented platform-wide reporting baseline added for
    // every user holding a role (effective-access.js); it is the only addition.
    expect([...access.permissions].sort()).toEqual(
      [...customPermissions, PERMISSIONS.REPORTS_READ].sort()
    );
  });

  it('withholds role permissions for modules outside the tenant subscription', () => {
    const access = resolveEffectiveAccess(
      {
        ...baseUser,
        roles: [roleEntry('WARD_CLERK_CUSTOM', [PERMISSIONS.PATIENT_READ, PERMISSIONS.CLINICAL_READ])]},
      { moduleEntitlements: [] }
    );

    expect(access.permissions).not.toContain(PERMISSIONS.PATIENT_READ);
    expect(access.permissions).not.toContain(PERMISSIONS.CLINICAL_READ);
  });

  it('limits a system role to its catalog pack even when stale rows grant more', () => {
    const pack = new Set(ROLE_PERMISSIONS.NURSE);
    const access = resolveEffectiveAccess({
      ...baseUser,
      roles: [roleEntry('NURSE', [PERMISSIONS.PLATFORM_ADMIN, PERMISSIONS.TENANT_ADMIN])]});

    expect(access.permissions.length).toBeGreaterThan(0);
    expect(access.permissions.every((permission) => pack.has(permission))).toBe(true);
    expect(access.permissions).not.toContain(PERMISSIONS.PLATFORM_ADMIN);
    expect(access.permissions).not.toContain(PERMISSIONS.TENANT_ADMIN);
  });
});
