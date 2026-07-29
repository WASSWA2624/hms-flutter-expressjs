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

describe('access-admin-workspace permissions billing scan', () => {
  const tenantUser = {
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const permissionsPayload = {
    items: [
      {
        id: 'perm-billing-uuid',
        human_friendly_id: 'PRM0099',
        name: 'billing:write',
        display_name: 'Billing Write',
        description: 'Allows write access within billing.',
      },
      {
        id: 'perm-clinical-uuid',
        human_friendly_id: 'PRM0001',
        name: 'clinical:read',
        display_name: 'Clinical Read',
        description: 'Allows read access within clinical.',
      },
    ],
    total: 2,
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
    repository.findPermissions.mockResolvedValue(permissionsPayload);
  });

  it('permissions catalog read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'permissions', resource: 'permissions' },
      1,
      20,
      tenantUser
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(2);
    expect(data.items[0].name).toBe('billing:write');
    expect(data.items[0].display_name).toBe('Billing Write');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('permissions GET is idempotent on replay', async () => {
    const query = { panel: 'permissions', resource: 'permissions' };
    const first = await service.getWorkspace(query, 1, 20, tenantUser);
    const second = await service.getWorkspace(query, 1, 20, tenantUser);

    expect(first.items).toEqual(second.items);
    expect(repository.findPermissions).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('denies billing collection for unauthorized clinical actor', async () => {
    await expect(
      service.resetDemoUserPassword('USR0001', { roles: ['DOCTOR'], permissions: ['clinical:read'] })
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes permission catalog without local paid flags', async () => {
    const data = await service.getWorkspace(
      { panel: 'permissions', resource: 'permissions' },
      1,
      20,
      tenantUser
    );

    const billingPermission = data.items.find((item) => item.name === 'billing:write');
    expect(billingPermission).toBeDefined();
    expect(billingPermission).not.toHaveProperty('payment_status');
    expect(billingPermission).not.toHaveProperty('balance');
    expect(billingPermission).not.toHaveProperty('amount');
    expect(billingPermission.display_name).toBe('Billing Write');
  });

  it('permissions panel read for unauthorized actor does not expose write billing side effects', async () => {
    repository.findPermissions.mockResolvedValue({ items: [], total: 0 });

    const data = await service.getWorkspace(
      { panel: 'permissions', resource: 'permissions' },
      1,
      20,
      { roles: ['DOCTOR'], permissions: ['clinical:read'], tenant_id: 'tenant-uuid' }
    );

    expect(data.permissions.can_write).toBe(false);
    expect(repository.findPermissions).toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
