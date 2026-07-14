jest.mock('@lib/subscriptions/tenant-entitlements', () => ({
  resolveTenantModuleEntitlements: jest.fn(),
}));
jest.mock('@repositories/auth/auth.repository', () => ({
  findUserById: jest.fn(),
}));

const {
  resolveTenantModuleEntitlements,
} = require('@lib/subscriptions/tenant-entitlements');
const authRepository = require('@repositories/auth/auth.repository');
const {
  clearLiveAccessCaches,
  hydrateLiveAccess,
} = require('@middlewares/live-access.middleware');
const { ROLES } = require('@config/roles');

describe('live-access.middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    clearLiveAccessCaches();
    authRepository.findUserById.mockResolvedValue({
      id: 'user-1',
      tenant_id: 'tenant-1',
      status: 'ACTIVE',
      roles: [ROLES.DOCTOR],
      role_permissions: ['clinical:read', 'billing:write', 'lab:read'],
    });
  });

  it('re-gates JWT permissions against live subscription modules', async () => {
    resolveTenantModuleEntitlements.mockResolvedValue([
      { module_slug: 'encounters-vitals', is_active: true },
    ]);

    const req = {
      user: {
        id: 'user-1',
        tenant_id: 'tenant-1',
        roles: [ROLES.DOCTOR],
        permissions: ['clinical:read', 'billing:write', 'lab:read'],
      },
    };
    const next = jest.fn();

    await hydrateLiveAccess()(req, {}, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user.permissions).toContain('clinical:read');
    expect(req.user.permissions).not.toContain('billing:write');
    expect(req.user.permissions).not.toContain('lab:read');
    expect(req.user.module_entitlements).toHaveLength(1);
  });

  it('plan-gates super admins when operating in a tenant', async () => {
    authRepository.findUserById.mockResolvedValue({
      id: 'user-1',
      tenant_id: 'tenant-1',
      status: 'ACTIVE',
      roles: [ROLES.SUPER_ADMIN],
      role_permissions: ['clinical:read', 'billing:write'],
    });
    resolveTenantModuleEntitlements.mockResolvedValue([
      { module_slug: 'encounters-vitals', is_active: true },
    ]);
    const req = {
      user: {
        id: 'user-1',
        tenant_id: 'tenant-1',
        roles: [ROLES.SUPER_ADMIN],
        permissions: ['clinical:read', 'billing:write'],
      },
    };
    const next = jest.fn();

    await hydrateLiveAccess()(req, {}, next);

    expect(resolveTenantModuleEntitlements).toHaveBeenCalledWith('tenant-1');
    expect(req.user.permissions).toContain('clinical:read');
    expect(req.user.permissions).not.toContain('billing:write');
    expect(next).toHaveBeenCalledWith();
  });

  it('removes permissions revoked after the JWT was issued', async () => {
    authRepository.findUserById.mockResolvedValue({
      id: 'user-1',
      tenant_id: 'tenant-1',
      status: 'ACTIVE',
      roles: [ROLES.DOCTOR],
      role_permissions: ['clinical:read'],
    });
    resolveTenantModuleEntitlements.mockResolvedValue([
      { module_slug: 'encounters-vitals', is_active: true },
    ]);
    const req = {
      user: {
        id: 'user-1',
        tenant_id: 'tenant-1',
        roles: [ROLES.DOCTOR],
        permissions: ['clinical:read', 'clinical:write'],
      },
    };
    const next = jest.fn();

    await hydrateLiveAccess()(req, {}, next);

    expect(req.user.permissions).toEqual(['clinical:read']);
    expect(req.user.permissions).not.toContain('clinical:write');
    expect(next).toHaveBeenCalledWith();
  });
});
