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

describe('access-admin-workspace entitlements billing scan', () => {
  const tenantUser = {
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const moduleEntitlementsPayload = {
    items: [
      {
        id: 'ms-uuid',
        human_friendly_id: 'MES0001',
        module_id: 'mod-uuid',
        is_active: true,
        entitlement_denied: false,
        entitlement_denial_reason: null,
        updated_at: '2026-01-01T00:00:00.000Z',
        module: {
          id: 'mod-uuid',
          human_friendly_id: 'MOD0001',
          name: 'Patient Registry',
          slug: 'patient-registry',
          module_group: 'Clinical',
        },
      },
    ],
    total: 1,
    subscription: {
      id: 'sub-uuid',
      human_friendly_id: 'SUB0001',
      plan: { name: 'Basic' },
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
    repository.findModuleEntitlements.mockResolvedValue(moduleEntitlementsPayload);
  });

  it('module-entitlements workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'entitlements', resource: 'module-entitlements' },
      1,
      20,
      tenantUser
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].module_label).toBe('Patient Registry');
    expect(data.items[0].plan_label).toBe('Basic');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('module-entitlements GET is idempotent on replay', async () => {
    const query = { panel: 'entitlements', resource: 'module-entitlements' };
    const first = await service.getWorkspace(query, 1, 20, tenantUser);
    const second = await service.getWorkspace(query, 1, 20, tenantUser);

    expect(first.items).toEqual(second.items);
    expect(repository.findModuleEntitlements).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('denies billing collection for unauthorized HR actor', async () => {
    await expect(
      service.resetDemoUserPassword('USR0001', { roles: ['HR'] })
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes entitlement metadata without local paid flags', async () => {
    const data = await service.getWorkspace(
      { panel: 'entitlements', resource: 'module-entitlements' },
      1,
      20,
      tenantUser
    );

    const item = data.items[0];
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount');
    expect(item.is_active).toBe(true);
    expect(item.entitlement_denied).toBe(false);
  });
});
