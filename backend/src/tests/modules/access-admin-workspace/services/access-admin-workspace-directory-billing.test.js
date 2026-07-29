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

describe('access-admin-workspace directory billing scan', () => {
  const tenantUser = {
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const userRecord = {
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
          name: 'BILLING',
        },
      },
    ],
    profile: {
      first_name: 'Jordan',
      last_name: 'Demo',
    },
    staff_profile: null,
    permissions: [
      {
        permission: {
          id: 'perm-billing-uuid',
          human_friendly_id: 'PRM0099',
          name: 'billing:write',
        },
      },
    ],
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
    repository.findUsers.mockResolvedValue({
      items: [userRecord],
      total: 1,
    });
    repository.findUserByIdentifier.mockResolvedValue(userRecord);
    repository.isDemoUser.mockReturnValue(false);
  });

  it('directory users workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'directory', resource: 'users' },
      1,
      20,
      tenantUser
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].email).toBe('doctor@hosspi.com');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('directory user detail does not mutate billing ledgers', async () => {
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

  it('directory GET is idempotent on replay', async () => {
    const query = { panel: 'directory', resource: 'users' };
    const first = await service.getWorkspace(query, 1, 20, tenantUser);
    const second = await service.getWorkspace(query, 1, 20, tenantUser);

    expect(first.items).toEqual(second.items);
    expect(repository.findUsers).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('serializes users without local paid flags or orphan amounts', async () => {
    const data = await service.getWorkspace(
      { panel: 'directory', resource: 'users' },
      1,
      20,
      tenantUser
    );

    const item = data.items[0];
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount');
    expect(item).not.toHaveProperty('paid');
  });

  it('directory user detail is idempotent on replay', async () => {
    const first = await service.getUserDetail(
      'USR0001',
      { tenant_id: 'tenant-uuid' },
      tenantUser
    );
    const second = await service.getUserDetail(
      'USR0001',
      { tenant_id: 'tenant-uuid' },
      tenantUser
    );

    expect(first.email).toBe(second.email);
    expect(first.effective_permissions).toEqual(second.effective_permissions);
    expect(repository.findUserByIdentifier).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('directory workspace read for clinical actor sets can_write false without billing posts', async () => {
    const data = await service.getWorkspace(
      { panel: 'directory', resource: 'users' },
      1,
      20,
      {
        roles: ['DOCTOR'],
        permissions: ['clinical:read'],
        tenant_id: 'tenant-uuid',
      }
    );

    expect(data.state).toBe('ready');
    expect(data.permissions.can_write).toBe(false);
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
