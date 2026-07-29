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

describe('access-admin-workspace demo billing scan', () => {
  const tenantUser = {
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const demoUsersPayload = {
    items: [
      {
        id: 'user-uuid',
        human_friendly_id: 'USR0001',
        email: 'doctor@hosspi.com',
        position_title: 'Demo Nurse',
        status: 'ACTIVE',
        tenant_id: 'tenant-uuid',
        facility_id: 'facility-uuid',
        roles: [
          {
            role: {
              id: 'role-uuid',
              human_friendly_id: 'ROL0001',
              name: 'BILLING',
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
  };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
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
    repository.findUsers.mockResolvedValue(demoUsersPayload);
    repository.isDemoUser.mockImplementation((user) =>
      String(user.email || '').trim().toLowerCase() === 'doctor@hosspi.com'
    );
  });

  it('demo-users workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'demo', resource: 'demo-users' },
      1,
      20,
      tenantUser
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].is_demo).toBe(true);
    expect(data.items[0].email).toBe('doctor@hosspi.com');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('demo-users GET is idempotent on replay', async () => {
    const query = { panel: 'demo', resource: 'demo-users' };
    const first = await service.getWorkspace(query, 1, 20, tenantUser);
    const second = await service.getWorkspace(query, 1, 20, tenantUser);

    expect(first.items).toEqual(second.items);
    expect(repository.findUsers).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('reset demo password does not post billing records', async () => {
    repository.findUserByIdentifier.mockResolvedValue({
      id: 'user-uuid',
      human_friendly_id: 'USR0001',
      email: 'doctor@hosspi.com',
    });
    repository.resetDemoUserPassword.mockResolvedValue({});

    const data = await service.resetDemoUserPassword('USR0001', tenantUser);

    expect(data.user_id).toBe('USR0001');
    expect(repository.resetDemoUserPassword).toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('denies demo reset for unauthorized HR actor without billing side effects', async () => {
    await expect(
      service.resetDemoUserPassword('USR0001', { roles: ['HR'] })
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes demo users without local paid flags or orphan amounts', async () => {
    const data = await service.getWorkspace(
      { panel: 'demo', resource: 'demo-users' },
      1,
      20,
      tenantUser
    );

    const item = data.items[0];
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount');
    expect(item).not.toHaveProperty('balance_due');
    expect(item.is_demo).toBe(true);
  });

  it('demo user detail exposes billing grants without ledger mutation', async () => {
    repository.findUserByIdentifier.mockResolvedValue({
      id: 'user-uuid',
      human_friendly_id: 'USR0001',
      email: 'doctor@hosspi.com',
      status: 'ACTIVE',
      tenant_id: 'tenant-uuid',
      facility_id: 'facility-uuid',
      roles: [
        {
          role: {
            id: 'role-uuid',
            human_friendly_id: 'ROL0001',
            name: 'BILLING',
          },
        },
      ],
      profile: { first_name: 'Jordan', last_name: 'Demo' },
      permissions: [
        {
          permission: {
            id: 'perm-billing-uuid',
            human_friendly_id: 'PRM0099',
            name: 'billing:write',
          },
        },
      ],
    });

    const detail = await service.getUserDetail(
      'USR0001',
      { tenant_id: 'tenant-uuid' },
      tenantUser
    );

    expect(detail.email).toBe('doctor@hosspi.com');
    expect(detail.effective_permissions).toEqual(
      expect.arrayContaining(['billing:write'])
    );
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('clinical actor workspace read omits write without billing side effects', async () => {
    const data = await service.getWorkspace(
      { panel: 'demo', resource: 'demo-users' },
      1,
      20,
      { roles: ['DOCTOR'], permissions: ['clinical:read'], tenant_id: 'tenant-uuid' }
    );

    expect(data.permissions.can_write).toBe(false);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
