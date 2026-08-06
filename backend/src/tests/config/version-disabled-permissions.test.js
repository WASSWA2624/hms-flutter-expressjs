const {
  VERSION_DISABLED_PERMISSION_DOMAINS,
  filterVersionDisabledPermissionNames,
  isVersionDisabledPermission,
} = require('@config/version-disabled-permissions');
const {
  resolveEffectiveAccess,
  resolveRequestPermissionNames,
} = require('@lib/authorization/effective-access');
const { PLAN_PERMISSION_CAPS } = require('@lib/subscriptions/subscription-permission-caps');
const { ROLES } = require('@config/roles');

describe('version-disabled-permissions', () => {
  test('lists the deferred shell domains', () => {
    expect(VERSION_DISABLED_PERMISSION_DOMAINS).toEqual(
      expect.arrayContaining([
        'emergency',
        'rooms_beds',
        'physiotherapy',
        'operations',
        'housekeeping',
        'biomed',
        'mortuary',
        'communications',
        'integration',
      ])
    );
  });

  test('filters deferred permission names', () => {
    expect(
      filterVersionDisabledPermissionNames([
        'clinical:read',
        'emergency:read',
        'biomed:write',
        'reports:read',
      ])
    ).toEqual(['clinical:read', 'reports:read']);
    expect(isVersionDisabledPermission('rooms_beds:read')).toBe(true);
    expect(isVersionDisabledPermission('theater:read')).toBe(false);
  });

  test('omits deferred domains from every plan permission cap', () => {
    for (const names of Object.values(PLAN_PERMISSION_CAPS)) {
      for (const name of names) {
        expect(isVersionDisabledPermission(name)).toBe(false);
      }
    }
  });

  test('strips deferred grants from effective access for all roles', () => {
    const access = resolveEffectiveAccess(
      {
        roles: [ROLES.TENANT_ADMIN],
        role_permissions: [
          'clinical:read',
          'emergency:read',
          'rooms_beds:read',
          'physiotherapy:read',
          'operations:read',
          'housekeeping:read',
          'biomed:read',
          'mortuary:read',
          'communications:read',
          'integration:read',
          'theater:read',
        ],
        tenant_id: 'tenant-1',
      },
      {
        moduleEntitlements: [
          { module_slug: 'encounters-vitals', is_active: true, plan_tier_code: 'PRO' },
          { module_slug: 'scheduling-queue', is_active: true, plan_tier_code: 'PRO' },
          {
            module_slug: 'inpatient-bed-management',
            is_active: true,
            plan_tier_code: 'PRO',
          },
          { module_slug: 'physiotherapy', is_active: true, plan_tier_code: 'PRO' },
          {
            module_slug: 'facilities-maintenance',
            is_active: true,
            plan_tier_code: 'PRO',
          },
          {
            module_slug: 'biomedical-engineering-suite',
            is_active: true,
            plan_tier_code: 'PRO',
          },
          { module_slug: 'mortuary', is_active: true, plan_tier_code: 'PRO' },
          {
            module_slug: 'notifications-communications',
            is_active: true,
            plan_tier_code: 'PRO',
          },
          { module_slug: 'integrations-core', is_active: true, plan_tier_code: 'PRO' },
          { module_slug: 'theatre-anesthesia', is_active: true, plan_tier_code: 'PRO' },
        ],
      }
    );

    expect(access.permissions).toContain('clinical:read');
    expect(access.permissions).toContain('theater:read');
    expect(access.permissions).not.toContain('emergency:read');
    expect(access.permissions).not.toContain('rooms_beds:read');
    expect(access.permissions).not.toContain('physiotherapy:read');
    expect(access.permissions).not.toContain('operations:read');
    expect(access.permissions).not.toContain('housekeeping:read');
    expect(access.permissions).not.toContain('biomed:read');
    expect(access.permissions).not.toContain('mortuary:read');
    expect(access.permissions).not.toContain('communications:read');
    expect(access.permissions).not.toContain('integration:read');
  });

  test('strips deferred grants from platform super-admin JWT path', () => {
    const permissions = resolveRequestPermissionNames({
      roles: [ROLES.SUPER_ADMIN],
      permissions: ['system:admin', 'emergency:read', 'biomed:read'],
    });

    expect(permissions).toContain('system:admin');
    expect(permissions).toContain('reports:read');
    expect(permissions).not.toContain('emergency:read');
    expect(permissions).not.toContain('biomed:read');
  });
});
