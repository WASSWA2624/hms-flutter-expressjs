/**
 * @jest-environment node
 */

const {
  canActorCreateTenantWideRole,
  filterPermissionRecordsByCeiling,
  isRoleWithinActorCeiling,
  resolveActorAssignablePermissionNames,
  buildRoleScopeWhere,
} = require('@lib/authorization/assignable-access');
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

  describe('resolveActorAssignablePermissionNames', () => {
    it('unions role permission maps for the actor', () => {
      const names = resolveActorAssignablePermissionNames({
        roles: [ROLES.FACILITY_ADMIN],
      });
      expect(names.has(PERMISSIONS.FACILITY_ADMIN)).toBe(true);
      expect(names.has(PERMISSIONS.TENANT_ADMIN)).toBe(false);
      expect(names.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(false);
    });

    it('includes tenant:admin for tenant admins', () => {
      const names = resolveActorAssignablePermissionNames({
        roles: [ROLES.TENANT_ADMIN],
      });
      expect(names.has(PERMISSIONS.TENANT_ADMIN)).toBe(true);
      expect(names.has(PERMISSIONS.SYSTEM_ADMIN)).toBe(false);
    });
  });

  describe('filterPermissionRecordsByCeiling', () => {
    it('keeps only permissions within the actor ceiling', () => {
      const filtered = filterPermissionRecordsByCeiling(
        [
          { id: '1', name: PERMISSIONS.FACILITY_ADMIN },
          { id: '2', name: PERMISSIONS.TENANT_ADMIN },
          { id: '3', name: PERMISSIONS.SYSTEM_ADMIN },
        ],
        { roles: [ROLES.FACILITY_ADMIN] }
      );
      expect(filtered.map((entry) => entry.name)).toEqual([PERMISSIONS.FACILITY_ADMIN]);
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
              { permission: { name: PERMISSIONS.PROFILE_READ } },
            ],
          },
          { roles: [ROLES.FACILITY_ADMIN] }
        )
      ).toBe(true);
    });

    it('rejects custom roles that include above-ceiling permissions', () => {
      expect(
        isRoleWithinActorCeiling(
          {
            name: 'CUSTOM_ADMIN',
            permissions: [{ permission: { name: PERMISSIONS.SYSTEM_ADMIN } }],
          },
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
          facility_id: 'facility-1',
        })
      ).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
        OR: [{ facility_id: 'facility-1' }, { facility_id: null }],
      });
    });

    it('filters by tenant only when facility is absent', () => {
      expect(buildRoleScopeWhere({ tenant_id: 'tenant-1' })).toEqual({
        deleted_at: null,
        tenant_id: 'tenant-1',
      });
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
