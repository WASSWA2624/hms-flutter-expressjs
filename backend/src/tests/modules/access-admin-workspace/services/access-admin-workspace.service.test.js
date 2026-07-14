jest.mock('@repositories/access-admin-workspace/access-admin-workspace.repository');
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => {
    const match = values.find((value) => value != null && String(value).trim() !== '');
    return match == null ? null : String(match);
  }),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || null),
}));
jest.mock('@lib/authorization/permission-catalog-sync', () => ({
  ensureTenantAccessCatalog: jest.fn().mockResolvedValue({
    permissions: 62,
    roles: 40,
  }),
  ensureTenantPermissionCatalog: jest.fn().mockResolvedValue([
    {
      id: 'perm-uuid',
      human_friendly_id: 'PRM0001',
      name: 'clinical:read',
      display_name: 'Clinical Read',
    },
  ]),
  restoreTenantRolePermissionDefaults: jest.fn().mockResolvedValue({
    permissions: 62,
    roles: 40,
    role_permissions_added: 2,
    role_permissions_removed: 1,
    before: { DOCTOR: ['clinical:read', 'billing:write'] },
    after: { DOCTOR: ['clinical:read'] },
  }),
}));
jest.mock('@middlewares/live-access.middleware', () => ({
  clearLiveAccessCaches: jest.fn(),
}));

const repository = require('@repositories/access-admin-workspace/access-admin-workspace.repository');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { ensureTenantAccessCatalog, ensureTenantPermissionCatalog } = require('@lib/authorization/permission-catalog-sync');
const service = require('../../../../modules/access-admin-workspace/services/access-admin-workspace.service');

describe('access-admin-workspace service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value || null);

    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: { tenant_id: 'tenant-uuid', facility_id: 'facility-uuid' },
    });
    repository.findSummary.mockResolvedValue({
      total_users: 12,
      active_users: 10,
      inactive_users: 2,
      total_roles: 8,
      total_permissions: 40,
      total_assignments: 15,
      demo_users: 3,
    });
    repository.findLookups.mockResolvedValue({
      tenants: [
        {
          id: 'tenant-uuid',
          human_friendly_id: 'TEN0001',
          name: 'DemoCare General Hospital',
        },
      ],
      facilities: [
        {
          id: 'facility-uuid',
          human_friendly_id: 'FAC0001',
          name: 'Main Campus',
          facility_type: 'HOSPITAL',
        },
      ],
      roles: [
        {
          id: 'role-uuid',
          human_friendly_id: 'ROL0001',
          name: 'DOCTOR',
          facility_id: 'facility-uuid',
        },
      ],
      permissions: [
        {
          id: 'perm-uuid',
          human_friendly_id: 'PRM0001',
          name: 'clinical:read',
        },
      ],
    });
    repository.findUsers.mockResolvedValue({
      items: [
        {
          id: 'user-uuid',
          human_friendly_id: 'USR0001',
          email: 'doctor@hosspi.com',
          position_title: 'Consultant Physician',
          status: 'ACTIVE',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          roles: [
            {
              role: {
                id: 'role-uuid',
                human_friendly_id: 'ROL0001',
                name: 'DOCTOR',
              },
            },
          ],
          profile: {
            first_name: 'Jordan',
            last_name: 'Demo',
          },
          staff_profile: null,
        },
      ],
      total: 1,
    });
    repository.findModuleEntitlements.mockResolvedValue({
      items: [],
      total: 0,
      subscription: null,
    });
    repository.isDemoUser.mockImplementation((user) =>
      String(user.email || '').trim().toLowerCase() === 'doctor@hosspi.com'
    );
  });

  it('returns workspace payload for users resource', async () => {
    const data = await service.getWorkspace(
      { panel: 'directory', resource: 'users' },
      1,
      20,
      { roles: ['TENANT_ADMIN'], tenant_id: 'tenant-uuid' }
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].email).toBe('doctor@hosspi.com');
    expect(data.items[0].is_demo).toBe(true);
    expect(data.permissions.can_write).toBe(true);
    expect(ensureTenantAccessCatalog).toHaveBeenCalledWith('tenant-uuid');
    expect(data.lookups.permissions.length).toBeGreaterThan(0);
    expect(repository.findUsers).toHaveBeenCalled();
  });

  it('syncs catalog before returning reference data for scoped tenant', async () => {
    const lookups = await service.getReferenceData(
      { tenantId: 'tenant-uuid' },
      { roles: ['TENANT_ADMIN'], tenant_id: 'tenant-uuid' }
    );

    expect(ensureTenantPermissionCatalog).toHaveBeenCalledWith('tenant-uuid');
    expect(lookups.permissions.length).toBeGreaterThan(0);
  });

  it('syncs catalog for explicit tenant when super admin requests reference data', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'tenant_context_required',
      scope: null,
    });
    repository.findLookups.mockResolvedValue({
      tenants: [
        {
          id: 'tenant-uuid',
          human_friendly_id: 'TEN0001',
          name: 'DemoCare General Hospital',
        },
      ],
      facilities: [],
      roles: [],
      permissions: [
        {
          id: 'perm-uuid',
          human_friendly_id: 'PRM0001',
          name: 'clinical:read',
          display_name: 'Clinical Read',
        },
      ],
    });

    const lookups = await service.getReferenceData(
      { tenantId: 'TEN0001' },
      { roles: ['SUPER_ADMIN'] }
    );

    expect(ensureTenantPermissionCatalog).toHaveBeenCalledWith('TEN0001');
    expect(lookups.permissions).toHaveLength(1);
    expect(lookups.tenants).toHaveLength(1);
  });

  it('returns empty permissions when tenant context is required', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'tenant_context_required',
      scope: null,
    });
    repository.findLookups.mockResolvedValue({
      tenants: [
        {
          id: 'tenant-uuid',
          human_friendly_id: 'TEN0001',
          name: 'DemoCare General Hospital',
        },
      ],
      facilities: [],
      roles: [],
      permissions: [
        {
          id: 'perm-uuid',
          human_friendly_id: 'PRM0001',
          name: 'clinical:read',
        },
      ],
    });

    const lookups = await service.getReferenceData({}, { roles: ['SUPER_ADMIN'] });

    expect(ensureTenantPermissionCatalog).not.toHaveBeenCalled();
    expect(lookups.tenants).toHaveLength(1);
    expect(lookups.permissions).toEqual([]);
  });

  it('returns tenant context required state without scope', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'tenant_context_required',
      scope: null,
    });

    const data = await service.getWorkspace({}, 1, 20, { roles: ['SUPER_ADMIN'] });

    expect(data.state).toBe('tenant_context_required');
    expect(data.items).toEqual([]);
  });

  it('resets demo user password outside production', async () => {
    repository.findUserByIdentifier.mockResolvedValue({
      id: 'user-uuid',
      human_friendly_id: 'USR0001',
      email: 'doctor@hosspi.com',
    });
    repository.resetDemoUserPassword.mockResolvedValue({});

    const data = await service.resetDemoUserPassword('USR0001', {
      roles: ['TENANT_ADMIN'],
      tenant_id: 'tenant-uuid',
    });

    expect(data.user_id).toBe('USR0001');
    expect(repository.resetDemoUserPassword).toHaveBeenCalled();
  });

  it('rejects demo reset in production', async () => {
    process.env.NODE_ENV = 'production';

    await expect(
      service.resetDemoUserPassword('USR0001', { roles: ['TENANT_ADMIN'] })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('denies HR write access to platform access admin mutations', async () => {
    await expect(
      service.resetDemoUserPassword('USR0001', { roles: ['HR'] })
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});
