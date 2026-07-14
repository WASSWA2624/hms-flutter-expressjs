const {
  resolveEffectiveAccess,
  resolveRequestPermissionNames,
} = require('@lib/authorization/effective-access');
const { ROLES } = require('@config/roles');

describe('effective-access', () => {
  test('reads role names from Prisma user_role embeds', () => {
    const { getRoleNames, userHasSuperAdminRole } = require('@lib/authorization/effective-access');
    const user = {
      roles: [
        { role: { name: ROLES.SUPER_ADMIN } },
        { role: { name: 'ADMINISTRATOR' } },
      ],
    };

    expect(getRoleNames(user)).toEqual(
      expect.arrayContaining([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN])
    );
    expect(userHasSuperAdminRole(user)).toBe(true);
  });

  test('intersects grant union with subscription modules', () => {
    const access = resolveEffectiveAccess(
      {
        roles: [ROLES.DOCTOR],
        role_permissions: ['clinical:read', 'clinical:write', 'billing:write'],
        tenant_id: 'tenant-1',
      },
      {
        moduleEntitlements: [
          { module_slug: 'encounters-vitals', is_active: true },
        ],
      }
    );

    expect(access.grant_union).toEqual(
      expect.arrayContaining(['clinical:read', 'clinical:write', 'billing:write'])
    );
    expect(access.permissions).toEqual(
      expect.arrayContaining(['clinical:read', 'clinical:write'])
    );
    expect(access.permissions).not.toContain('billing:write');
  });

  test('intersects with explicit assigned modules when provided', () => {
    const access = resolveEffectiveAccess(
      {
        roles: [ROLES.DOCTOR],
        role_permissions: ['clinical:read', 'lab:read'],
        module_assignments: ['encounters-vitals'],
        tenant_id: 'tenant-1',
      },
      {
        moduleEntitlements: [
          { module_slug: 'encounters-vitals', is_active: true },
          { module_slug: 'lab-workflows', is_active: true },
        ],
      }
    );

    expect(access.permissions).toContain('clinical:read');
    expect(access.permissions).not.toContain('lab:read');
  });

  test('request permissions re-apply live plan gate to JWT grants', () => {
    const permissions = resolveRequestPermissionNames({
      roles: [ROLES.DOCTOR],
      permissions: ['clinical:read', 'billing:write', 'lab:read'],
      module_entitlements: [
        { module_slug: 'encounters-vitals', is_active: true },
      ],
      tenant_id: 'tenant-1',
    });

    expect(permissions).toContain('clinical:read');
    expect(permissions).not.toContain('billing:write');
    expect(permissions).not.toContain('lab:read');
  });

  test('applies package permission caps inside an entitled module', () => {
    const permissions = resolveRequestPermissionNames({
      roles: [ROLES.DOCTOR],
      permissions: ['patient:read', 'patient:write', 'patient:delete'],
      module_entitlements: [
        {
          module_slug: 'patient-registry',
          is_active: true,
          plan_tier_code: 'FREE',
        },
      ],
      tenant_id: 'tenant-1',
    });

    expect(permissions).toContain('patient:read');
    expect(permissions).toContain('patient:write');
    expect(permissions).not.toContain('patient:delete');
  });

  test('developer package is not unrestricted in production', () => {
    const previousNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      const access = resolveEffectiveAccess(
        {
          tenant_id: 'tenant-1',
          role_permissions: ['patient:read', 'patient:delete'],
        },
        {
          moduleEntitlements: [
            {
              module_slug: 'patient-registry',
              is_active: true,
              plan_tier_code: 'DEVELOPER',
            },
          ],
        }
      );

      expect(access.permissions).toContain('patient:read');
      expect(access.permissions).not.toContain('patient:delete');
    } finally {
      process.env.NODE_ENV = previousNodeEnv;
    }
  });

  test('super admin remains plan-gated in a tenant context', () => {
    const permissions = resolveRequestPermissionNames({
      roles: [ROLES.SUPER_ADMIN],
      permissions: ['clinical:read', 'billing:write'],
      module_entitlements: [
        { module_slug: 'encounters-vitals', is_active: true },
      ],
      tenant_id: 'tenant-1',
    });

    expect(permissions).toContain('clinical:read');
    expect(permissions).not.toContain('billing:write');
  });

  test('platform super admin without tenant context keeps platform grants', () => {
    const permissions = resolveRequestPermissionNames({
      roles: [ROLES.SUPER_ADMIN],
      permissions: ['system:admin'],
    });

    expect(permissions).toEqual(['system:admin']);
  });
});
