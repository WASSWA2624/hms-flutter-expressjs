jest.mock('@repositories/access-admin-workspace/access-admin-workspace.repository');
jest.mock('@repositories/auth/auth.repository');
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
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/subscriptions/tenant-onboarding', () => ({
  provisionTrialSubscription: jest.fn().mockResolvedValue({ id: 'sub-uuid' }),
}));

const repository = require('@repositories/access-admin-workspace/access-admin-workspace.repository');
const authRepository = require('@repositories/auth/auth.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const { provisionTrialSubscription } = require('@lib/subscriptions/tenant-onboarding');
const service = require('../../../../modules/access-admin-workspace/services/access-admin-workspace.service');

describe('access-admin-workspace registrations billing scan', () => {
  const superAdmin = {
    id: 'admin-uuid',
    roles: ['SUPER_ADMIN'],
    permissions: ['system:admin'],
  };

  const tenantAdmin = {
    id: 'tenant-admin-uuid',
    roles: ['TENANT_ADMIN'],
    tenant_id: 'tenant-uuid',
    permissions: ['tenant:admin'],
  };

  const pendingUser = {
    id: 'user-uuid',
    human_friendly_id: 'USR0001',
    email: 'pending@example.com',
    phone: '+15551234567',
    status: 'PENDING',
    email_verified_at: '2026-01-01T00:00:00.000Z',
    tenant_id: 'tenant-uuid',
    facility_id: 'facility-uuid',
    facility: { name: 'Main Campus', facility_type: 'HOSPITAL' },
    tenant: { id: 'tenant-uuid', name: 'DemoCare' },
  };

  const registrationQueuePayload = {
    items: [
      {
        email: pendingUser.email,
        phone: pendingUser.phone,
        user: pendingUser,
        facility_name: pendingUser.facility.name,
        facility_type: pendingUser.facility.facility_type,
        tenant: pendingUser.tenant,
        facility: pendingUser.facility,
        account_status: 'PENDING',
        status: 'PENDING',
        updated_at: '2026-01-01T00:00:00.000Z',
      },
    ],
    total: 1,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: { tenant_id: null, facility_id: null },
    });
    repository.findSummary.mockResolvedValue({});
    repository.findLookups.mockResolvedValue({
      tenants: [],
      facilities: [],
      roles: [],
      permissions: [],
    });
    authRepository.findPendingRegistrationApprovals.mockResolvedValue(
      registrationQueuePayload
    );
    repository.findUserByIdentifier.mockResolvedValue({
      id: pendingUser.id,
      human_friendly_id: pendingUser.human_friendly_id,
    });
    authRepository.findUserById.mockResolvedValue(pendingUser);
    authRepository.updateUserStatus.mockResolvedValue({});
    authRepository.updateRegistrationFollowUpStatus.mockResolvedValue({});
  });

  it('registration-follow-ups workspace read does not touch patient billing ledger', async () => {
    const data = await service.getWorkspace(
      { panel: 'registrations', resource: 'registration-follow-ups' },
      1,
      20,
      superAdmin
    );

    expect(data.state).toBe('ready');
    expect(data.items).toHaveLength(1);
    expect(data.items[0].email).toBe('pending@example.com');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('registration-follow-ups GET is idempotent on replay', async () => {
    const query = { panel: 'registrations', resource: 'registration-follow-ups' };
    const first = await service.getWorkspace(query, 1, 20, superAdmin);
    const second = await service.getWorkspace(query, 1, 20, superAdmin);

    expect(first.items).toEqual(second.items);
    expect(authRepository.findPendingRegistrationApprovals).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('activate registration provisions trial subscription, not patient billing', async () => {
    await service.activateRegistration('USR0001', superAdmin, '127.0.0.1');

    expect(authRepository.updateUserStatus).toHaveBeenCalledWith(pendingUser.id, 'ACTIVE');
    expect(provisionTrialSubscription).toHaveBeenCalledWith('tenant-uuid');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('activate registration is idempotent when replayed for same pending user', async () => {
    await service.activateRegistration('USR0001', superAdmin);
    await service.activateRegistration('USR0001', superAdmin);

    expect(authRepository.updateUserStatus).toHaveBeenCalledTimes(2);
    expect(provisionTrialSubscription).toHaveBeenCalledTimes(2);
    expect(provisionTrialSubscription).toHaveBeenCalledWith('tenant-uuid');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('reject registration updates status without billing ledger mutation', async () => {
    const data = await service.rejectRegistration('USR0001', superAdmin, '127.0.0.1');

    expect(data.status).toBe('INACTIVE');
    expect(authRepository.updateUserStatus).toHaveBeenCalledWith(pendingUser.id, 'INACTIVE');
    expect(provisionTrialSubscription).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('denies activate/reject for non-elevated tenant admin', async () => {
    await expect(
      service.activateRegistration('USR0001', tenantAdmin)
    ).rejects.toMatchObject({ statusCode: 403 });
    await expect(
      service.rejectRegistration('USR0001', tenantAdmin)
    ).rejects.toMatchObject({ statusCode: 403 });

    expect(provisionTrialSubscription).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('denies registration queue read for non-elevated tenant admin', async () => {
    await expect(
      service.getWorkspace(
        { panel: 'registrations', resource: 'registration-follow-ups' },
        1,
        20,
        tenantAdmin
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('serializes registration rows without local paid flags or balances', async () => {
    const data = await service.getWorkspace(
      { panel: 'registrations', resource: 'registration-follow-ups' },
      1,
      20,
      superAdmin
    );

    const item = data.items[0];
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount');
    expect(item).not.toHaveProperty('invoice_id');
  });
});
