jest.mock('@repositories/access-admin-workspace/access-admin-workspace.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
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
  ensureTenantPermissionCatalog: jest.fn().mockResolvedValue([]),
  restoreTenantRolePermissionDefaults: jest.fn().mockResolvedValue({}),
}));

const repository = require('@repositories/access-admin-workspace/access-admin-workspace.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const service = require('../../../../modules/access-admin-workspace/services/access-admin-workspace.service');

describe('access-admin-workspace roles billing scan', () => {
  const tenantUser = {
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const roleRecord = {
    id: 'role-uuid',
    human_friendly_id: 'ROL0001',
    name: 'BILLING CLERK',
    display_name: 'Billing Clerk',
    description: 'Cashier access',
    tenant_id: 'tenant-uuid',
    facility_id: null,
    facility_name: null,
    deleted_at: null,
    updated_at: '2026-01-01T00:00:00.000Z',
    permissions: [
      {
        permission: {
          id: 'perm-billing-uuid',
          human_friendly_id: 'PRM0099',
          name: 'billing:write',
        },
      },
    ],
    _count: {
      permissions: 1,
      users: 2,
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: { tenant_id: 'tenant-uuid', facility_id: 'facility-uuid' },
    });
    repository.findSummary.mockResolvedValue({});
    repository.findLookups.mockResolvedValue({
      tenants: [],
      facilities: [],
      roles: [],
      permissions: [],
    });
    repository.findRoles.mockResolvedValue({
      items: [roleRecord],
      total: 1,
    });
    repository.findRolePermissions.mockResolvedValue({
      items: [
        {
          id: 'rp-uuid',
          human_friendly_id: 'RPR0001',
          role_id: 'role-uuid',
          permission_id: 'perm-billing-uuid',
          role: roleRecord,
          permission: {
            id: 'perm-billing-uuid',
            human_friendly_id: 'PRM0099',
            name: 'billing:write',
          },
        },
      ],
      total: 1,
    });
  });

  it('roles workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'roles', resource: 'roles' },
      1,
      20,
      tenantUser
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].name).toBe('BILLING CLERK');
    expect(data.items[0].permission_count).toBe(1);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('role-permissions catalog read does not mutate billing ledgers', async () => {
    const data = await service.getWorkspace(
      { panel: 'roles', resource: 'role-permissions', roleId: 'ROL0001' },
      1,
      20,
      tenantUser
    );

    expect(data.items).toHaveLength(1);
    expect(data.items[0].role_name).toBe('BILLING CLERK');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('roles GET is idempotent on replay', async () => {
    const query = { panel: 'roles', resource: 'roles' };
    const first = await service.getWorkspace(query, 1, 20, tenantUser);
    const second = await service.getWorkspace(query, 1, 20, tenantUser);

    expect(first.items).toEqual(second.items);
    expect(repository.findRoles).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('serializes roles without local paid flags or orphan amounts', async () => {
    const data = await service.getWorkspace(
      { panel: 'roles', resource: 'roles' },
      1,
      20,
      tenantUser
    );

    const item = data.items[0];
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount');
    expect(item).not.toHaveProperty('paid');
    expect(item.is_system_critical).toBe(false);
  });

  it('denies billing collection for unauthorized clinical actor', async () => {
    await expect(
      service.resetDemoUserPassword('USR0001', {
        roles: ['DOCTOR'],
        permissions: ['clinical:read'],
      })
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });
});
