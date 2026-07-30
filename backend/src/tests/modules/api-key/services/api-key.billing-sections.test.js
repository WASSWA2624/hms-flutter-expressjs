/**
 * Billing & sections scan for Integrations API keys tab.
 *
 * API key CRUD and permission grants are developer-credential ops and must
 * never post patient Billing ledger rows. Granting billing:* permission codes
 * is access metadata only (NOT_BILLED). Interop order/payment posting lives on
 * Billing clinical-request / receive-payment paths — not this module.
 */

jest.mock('@repositories/api-key/api-key.repository');
jest.mock('@repositories/api-key-permission/api-key-permission.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/crypto', () => ({
  hashApiKey: jest.fn().mockResolvedValue('$argon2id$mocked'),
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/authorization/assignable-access', () => ({
  assertPermissionIdHasRequiredRead: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@prisma/client', () => ({
  api_key_permission: {
    findMany: jest.fn().mockResolvedValue([]),
  },
}));

const apiKeyRepository = require('@repositories/api-key/api-key.repository');
const apiKeyPermissionRepository = require('@repositories/api-key-permission/api-key-permission.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const {
  listApiKeys,
  getApiKeyById,
  createApiKey,
  updateApiKey,
  deleteApiKey,
} = require('@services/api-key/api-key.service');
const {
  createApiKeyPermission,
  deleteApiKeyPermission,
} = require('@services/api-key-permission/api-key-permission.service');

const assertNoPatientBillingTouch = () => {
  expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
};

describe('integrations API keys billing-sections scan', () => {
  const userId = '123e4567-e89b-12d3-a456-426614174099';
  const ipAddress = '127.0.0.1';

  const apiKeyRecord = {
    id: '123e4567-e89b-12d3-a456-426614174001',
    human_friendly_id: 'KEY-TEST1234',
    name: 'Billing Export Key',
    tenant_id: '123e4567-e89b-12d3-a456-426614174010',
    user_id: userId,
    key_hash: '$argon2id$secret',
    is_active: true,
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    deleted_at: null,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    apiKeyRepository.createPublicId.mockReturnValue('KEY-TEST1234');
  });

  it('list API keys stays NOT_BILLED (no patient ledger post)', async () => {
    apiKeyRepository.findMany.mockResolvedValue([apiKeyRecord]);
    apiKeyRepository.count.mockResolvedValue(1);

    const result = await listApiKeys({}, 1, 20, undefined, 'desc', userId, ipAddress);

    expect(result.api_keys).toHaveLength(1);
    expect(result.api_keys[0]).not.toHaveProperty('key_hash');
    expect(result.api_keys[0]).not.toHaveProperty('payment_status');
    expect(result.api_keys[0]).not.toHaveProperty('balance');
    expect(result.api_keys[0]).not.toHaveProperty('amount_due');
    expect(result.api_keys[0]).not.toHaveProperty('invoice_id');
    assertNoPatientBillingTouch();
  });

  it('list API keys is idempotent on replay (no double billing post)', async () => {
    apiKeyRepository.findMany.mockResolvedValue([apiKeyRecord]);
    apiKeyRepository.count.mockResolvedValue(1);

    const first = await listApiKeys({}, 1, 20, undefined, 'desc', userId, ipAddress);
    const second = await listApiKeys({}, 1, 20, undefined, 'desc', userId, ipAddress);

    expect(first.api_keys).toEqual(second.api_keys);
    expect(apiKeyRepository.findMany).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('getApiKeyById read stays NOT_BILLED', async () => {
    apiKeyRepository.findById.mockResolvedValue(apiKeyRecord);

    const result = await getApiKeyById(apiKeyRecord.id, userId, ipAddress);

    expect(result.id).toBe(apiKeyRecord.id);
    expect(result).not.toHaveProperty('key_hash');
    expect(result).not.toHaveProperty('paid');
    assertNoPatientBillingTouch();
  });

  it('Create API key stays NOT_BILLED (no patient ledger post)', async () => {
    apiKeyRepository.create.mockResolvedValue(apiKeyRecord);

    const result = await createApiKey(
      { name: 'Billing Export Key', tenant_id: apiKeyRecord.tenant_id, user_id: userId },
      userId,
      ipAddress
    );

    expect(result.api_key).toEqual(expect.stringContaining('KEY-TEST1234.'));
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('invoice_id');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'api_key',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('Create API key replay creates distinct credentials (no orphan ledger)', async () => {
    apiKeyRepository.create
      .mockResolvedValueOnce(apiKeyRecord)
      .mockResolvedValueOnce({
        ...apiKeyRecord,
        id: '123e4567-e89b-12d3-a456-426614174002',
        human_friendly_id: 'KEY-TEST5678',
      });
    apiKeyRepository.createPublicId
      .mockReturnValueOnce('KEY-TEST1234')
      .mockReturnValueOnce('KEY-TEST5678');

    const first = await createApiKey({ name: 'Key A' }, userId, ipAddress);
    const second = await createApiKey({ name: 'Key B' }, userId, ipAddress);

    expect(first.api_key).not.toEqual(second.api_key);
    expect(apiKeyRepository.create).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('Enable / disable update stays NOT_BILLED', async () => {
    apiKeyRepository.findById.mockResolvedValue(apiKeyRecord);
    apiKeyRepository.update.mockResolvedValue({ ...apiKeyRecord, is_active: false });

    const result = await updateApiKey(
      apiKeyRecord.id,
      { is_active: false },
      userId,
      ipAddress
    );

    expect(result.is_active).toBe(false);
    expect(result).not.toHaveProperty('balance');
    assertNoPatientBillingTouch();
  });

  it('Revoke (soft delete) stays NOT_BILLED', async () => {
    apiKeyRepository.findById.mockResolvedValue(apiKeyRecord);
    apiKeyRepository.softDelete.mockResolvedValue(undefined);

    await deleteApiKey(apiKeyRecord.id, userId, ipAddress);

    expect(apiKeyRepository.softDelete).toHaveBeenCalledWith(apiKeyRecord.id);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'api_key',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('billing:* permission grant stays NOT_BILLED access metadata', async () => {
    const grant = {
      id: 'grant-1',
      api_key_id: apiKeyRecord.id,
      permission_id: 'perm-billing-write',
    };
    apiKeyPermissionRepository.create.mockResolvedValue(grant);

    const result = await createApiKeyPermission(
      { api_key_id: apiKeyRecord.id, permission_id: 'perm-billing-write' },
      userId,
      ipAddress
    );

    expect(result.permission_id).toBe('perm-billing-write');
    expect(result).not.toHaveProperty('amount');
    expect(result).not.toHaveProperty('invoice_id');
    assertNoPatientBillingTouch();
  });

  it('permission grant remove stays NOT_BILLED', async () => {
    const grant = {
      id: 'grant-1',
      api_key_id: apiKeyRecord.id,
      permission_id: 'perm-billing-write',
    };
    apiKeyPermissionRepository.findById.mockResolvedValue(grant);
    apiKeyPermissionRepository.softDelete.mockResolvedValue(undefined);

    await deleteApiKeyPermission(grant.id, userId, ipAddress);

    expect(apiKeyPermissionRepository.softDelete).toHaveBeenCalledWith(grant.id);
    assertNoPatientBillingTouch();
  });

  it('status parity: is_active remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    apiKeyRepository.findMany.mockResolvedValue([apiKeyRecord]);
    apiKeyRepository.count.mockResolvedValue(1);

    const result = await listApiKeys({}, 1, 20, undefined, 'desc', userId, ipAddress);

    expect(result.api_keys[0].is_active).toBe(true);
    expect(result.api_keys[0]).not.toHaveProperty('payment_status');
    assertNoPatientBillingTouch();
  });

  it('unauthorized collect/adjust path is absent (module never imports Billing)', () => {
    // API key services do not export receive-payment / adjustment entry points.
    const apiKeyService = require('@services/api-key/api-key.service');
    expect(apiKeyService.receivePayment).toBeUndefined();
    expect(apiKeyService.adjustInvoice).toBeUndefined();
    expect(apiKeyService.createInvoice).toBeUndefined();
    assertNoPatientBillingTouch();
  });
});
