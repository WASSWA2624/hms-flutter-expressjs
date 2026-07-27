/**
 * @jest-environment node
 */

const {
  canActorCreatePlatformRole,
  canActorCreateTenantWideRole,
  filterPermissionRecordsByCeiling,
  isRoleWithinActorCeiling,
  resolveActorAssignablePermissionNames,
  buildRoleScopeWhere} = require('@lib/authorization/assignable-access');
const { ROLES } = require('@config/roles');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');

describe('assignable-access', () => {
  describe('canActorCreateTenantWideRole', () => {
    it('allows super and tenant admins', () => {
      expect(canActorCreateTenantWideRole({ roles: [ROLES.SUPER_ADMIN] })).toBe(true);
      expect(canActorCreateTenantWideRole({ roles: [ROLES.TENANT_ADMIN] })).toBe(true);
    });

    it('blocks facility admins', () => {
      expect(canActorCreateTenantWideRole({ roles: [ROLES.FACILITY_ADMIN] })).toBe(false);
    });
  });

  describe('canActorCreatePlatformRole', () => {
    it('allows super admins only', () => {
      expect(canActorCreatePlatformRole({ roles: [ROLES.SUPER_ADMIN] })).toBe(true);
      expect(canActorCreatePlatformRole({ roles: [ROLES.TENANT_ADMIN] })).toBe(false);
      expect(canActorCreatePlatformRole({ roles: [ROLES.FACILITY_ADMIN] })).toBe(false);
    });
  });

  describe('resolveActorAssignablePermissionNames', () => {
    it('unions role permission maps for the actor', () => {
      const names = resolveActorAssignablePermissionNames({
        roles: [ROLES.FACILITY_ADMIN]});
      expect(names.has(PERMISSIONS.FACILITY_ADMIN)).toBe(true);
      expect(names.has(PERMISSIONS.TENANT_ADMIN)).toBe(false);
      expect(names.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(false);
    });

    it('includes tenant:admin for tenant admins', () => {
      const names = resolveActorAssignablePermissionNames({
        roles: [ROLES.TENANT_ADMIN]});
      expect(names.has(PERMISSIONS.TENANT_ADMIN)).toBe(true);
      expect(names.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(false);
    });

    it('keeps a full ceiling for super admins even when JWT permissions are plan-gated', () => {
      const names = resolveActorAssignablePermissionNames({
        roles: [ROLES.SUPER_ADMIN],
        permissions: [PERMISSIONS.PROFILE_READ, PERMISSIONS.PATIENT_READ]});
      expect(names.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(true);
      expect(names.has(PERMISSIONS.MORTUARY_READ)).toBe(true);
      expect(names.has(PERMISSIONS.LAB_WRITE)).toBe(true);
    });
  });

  describe('filterPermissionRecordsByCeiling', () => {
    it('keeps only permissions within the actor ceiling', () => {
      const filtered = filterPermissionRecordsByCeiling(
        [
          { id: '1', name: PERMISSIONS.FACILITY_ADMIN },
          { id: '2', name: PERMISSIONS.TENANT_ADMIN },
          { id: '3', name: PERMISSIONS.SYSTEM_ADMIN }],
        { roles: [ROLES.FACILITY_ADMIN] }
      );
      expect(filtered.map((entry) => entry.name)).toEqual([PERMISSIONS.FACILITY_ADMIN]);
    });

    it('also drops module-scoped permissions outside the plan', () => {
      const filtered = filterPermissionRecordsByCeiling(
        [
          { id: '1', name: PERMISSIONS.LAB_READ },
          { id: '2', name: PERMISSIONS.PROFILE_READ },
          { id: '3', name: PERMISSIONS.PHARMACY_READ }],
        { roles: [ROLES.FACILITY_ADMIN] },
        new Set(['lab-workflows'])
      );
      expect(filtered.map((entry) => entry.name)).toEqual([
        PERMISSIONS.LAB_READ,
        PERMISSIONS.PROFILE_READ]);
    });
  });

  describe('isRoleWithinActorCeiling', () => {
    it('rejects higher-ranked built-in roles', () => {
      expect(
        isRoleWithinActorCeiling(
          { name: ROLES.TENANT_ADMIN },
          { roles: [ROLES.FACILITY_ADMIN] }
        )
      ).toBe(false);
    });

    it('accepts custom roles whose permissions are within the ceiling', () => {
      expect(
        isRoleWithinActorCeiling(
          {
            name: 'WARD_CLERK',
            permissions: [
              { permission: { name: PERMISSIONS.PATIENT_READ } },
              { permission: { name: PERMISSIONS.PROFILE_READ } }]},
          { roles: [ROLES.FACILITY_ADMIN] }
        )
      ).toBe(true);
    });

    it('does not invent built-in packs for empty custom roles named like system roles', () => {
      expect(
        isRoleWithinActorCeiling(
          {
            name: 'DOCTOR',
            permissions: []},
          { roles: [ROLES.FACILITY_ADMIN] }
        )
      ).toBe(true);
    });

    it('rejects custom roles that include above-ceiling permissions', () => {
      expect(
        isRoleWithinActorCeiling(
          {
            name: 'CUSTOM_ADMIN',
            permissions: [{ permission: { name: PERMISSIONS.SYSTEM_ADMIN } }]},
          { roles: [ROLES.TENANT_ADMIN] }
        )
      ).toBe(false);
    });
  });

  describe('buildRoleScopeWhere', () => {
    it('includes tenant-wide and facility roles when facility scoped', () => {
      expect(
        buildRoleScopeWhere({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1'})
      ).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
        OR: [{ facility_id: 'facility-1' }, { facility_id: null }]});
    });

    it('filters by tenant only when facility is absent', () => {
      expect(buildRoleScopeWhere({ tenant_id: 'tenant-1' })).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1'});
    });

    it('excludes tenant-wide roles for facility-only actors', () => {
      expect(
        buildRoleScopeWhere(
          { tenant_id: 'tenant-1', facility_id: 'facility-1' },
          { includeTenantWide: false }
        )
      ).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'});
    });

    it('supports explicit tenant and facility roleScope filters', () => {
      expect(
        buildRoleScopeWhere(
          { tenant_id: 'tenant-1', facility_id: 'facility-1' },
          { roleScope: 'tenant' }
        )
      ).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
        facility_id: null});
      expect(
        buildRoleScopeWhere(
          { tenant_id: 'tenant-1', facility_id: 'facility-1' },
          { roleScope: 'facility' }
        )
      ).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'});
    });
  });

  describe('ROLE_PERMISSIONS hierarchy', () => {
    it('keeps facility admin below tenant admin', () => {
      const facility = new Set(ROLE_PERMISSIONS[ROLES.FACILITY_ADMIN] || []);
      const tenant = new Set(ROLE_PERMISSIONS[ROLES.TENANT_ADMIN] || []);
      expect(facility.has(PERMISSIONS.TENANT_ADMIN)).toBe(false);
      expect(tenant.has(PERMISSIONS.TENANT_ADMIN)).toBe(true);
      expect(tenant.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(false);
    });
  });
});
