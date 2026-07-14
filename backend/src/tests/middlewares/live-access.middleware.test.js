jest.mock('@lib/subscriptions/tenant-entitlements', () => ({
  resolveTenantModuleEntitlements: jest.fn(),
}));

const {
  resolveTenantModuleEntitlements,
} = require('@lib/subscriptions/tenant-entitlements');
const {
  clearLiveAccessCaches,
  hydrateLiveAccess,
} = require('@middlewares/live-access.middleware');
const { ROLES } = require('@config/roles');

describe('live-access.middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    clearLiveAccessCaches();
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

  it('skips plan gating for super admins', async () => {
    const req = {
      user: {
        id: 'user-1',
        tenant_id: 'tenant-1',
        roles: [ROLES.SUPER_ADMIN],
        permissions: ['billing:write'],
      },
    };
    const next = jest.fn();

    await hydrateLiveAccess()(req, {}, next);

    expect(resolveTenantModuleEntitlements).not.toHaveBeenCalled();
    expect(req.user.permissions).toEqual(['billing:write']);
    expect(next).toHaveBeenCalledWith();
  });
});
