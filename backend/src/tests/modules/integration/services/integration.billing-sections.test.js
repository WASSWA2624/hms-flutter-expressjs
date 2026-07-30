/**
 * Billing & sections scan for Integrations workspace Integrations tab.
 *
 * Connector create/update/test/sync/delete must never post patient Billing
 * ledger rows. `@lib/billing/identifiers` is used only for tenant/entity id
 * resolution — not clinical-request billing or receive-payment.
 */

jest.mock('@repositories/integration/integration.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: jest.fn((value) => (typeof value === 'string' ? value.trim() : '')),
  resolvePublicIdentifier: jest.fn((...values) => {
    for (const value of values) {
      if (typeof value !== 'string') continue;
      const normalized = value.trim();
      if (!normalized) continue;
      if (!/^[0-9a-f]{8}-/i.test(normalized)) return normalized;
    }
    return null;
  }),
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
}));

const integrationService = require('@services/integration/integration.service');
const integrationRepository = require('@repositories/integration/integration.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');

const buildRawIntegration = (overrides = {}) => ({
  id: '123e4567-e89b-12d3-a456-426614174000',
  human_friendly_id: 'INT0000001',
  tenant_id: '223e4567-e89b-12d3-a456-426614174000',
  integration_type: 'HL7',
  status: 'ACTIVE',
  name: 'ADT Feed',
  config_json: { endpoint: 'https://hl7.example.test' },
  created_at: '2026-03-08T12:00:00.000Z',
  updated_at: '2026-03-08T12:30:00.000Z',
  version: 3,
  tenant: {
    id: '223e4567-e89b-12d3-a456-426614174000',
    human_friendly_id: 'TEN0000001',
    name: 'Acme Health',
  },
  _count: {
    logs: 4,
    webhooks: 2,
  },
  ...overrides,
});

const auditContext = {
  user_id: 'user-123',
  tenant_id: 'tenant-123',
  ip_address: '127.0.0.1',
};

describe('integration Integrations-tab billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  const expectNoPatientBillingTouch = () => {
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  };

  it('list integrations does not touch patient billing ledger', async () => {
    const raw = buildRawIntegration();
    integrationRepository.findMany.mockResolvedValue([raw]);
    integrationRepository.count.mockResolvedValue(1);

    const result = await integrationService.listIntegrations({}, 1, 20);

    expect(result.data).toHaveLength(1);
    expect(result.data[0].name).toBe('ADT Feed');
    expectNoPatientBillingTouch();
  });

  it('create integration resolves tenant id only — no ledger post', async () => {
    const raw = buildRawIntegration();
    integrationRepository.create.mockResolvedValue(raw);
    integrationRepository.findById.mockResolvedValue(raw);

    const result = await integrationService.createIntegration(
      {
        tenant_id: 'TEN0000001',
        name: 'ADT Feed',
        integration_type: 'BILLING',
        status: 'ACTIVE',
        config_json: { endpoint: 'https://billing-connector.example' },
      },
      auditContext
    );

    expect(identifiers.resolveIdentifierForPayload).toHaveBeenCalledWith(
      expect.objectContaining({
        field: 'tenant_id',
        model: 'tenant',
      })
    );
    expect(result.integration_type).toBe('BILLING');
    expect(result.name).toBe('ADT Feed');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'integration',
      })
    );
    expectNoPatientBillingTouch();
  });

  it('create is idempotent on replay (no double billing post)', async () => {
    const raw = buildRawIntegration();
    integrationRepository.create.mockResolvedValue(raw);
    integrationRepository.findById.mockResolvedValue(raw);

    const payload = {
      tenant_id: 'TEN0000001',
      name: 'ADT Feed',
      integration_type: 'HL7',
      status: 'ACTIVE',
    };

    await integrationService.createIntegration(payload, auditContext);
    await integrationService.createIntegration(payload, auditContext);

    expect(integrationRepository.create).toHaveBeenCalledTimes(2);
    expectNoPatientBillingTouch();
  });

  it('update / enable status stays NOT_BILLED connector ops', async () => {
    const existing = buildRawIntegration({ status: 'INACTIVE' });
    const updated = buildRawIntegration({ status: 'ACTIVE' });
    integrationRepository.findById
      .mockResolvedValueOnce(existing)
      .mockResolvedValueOnce(updated);
    integrationRepository.update.mockResolvedValue(updated);

    const result = await integrationService.updateIntegration(
      'INT0000001',
      { status: 'ACTIVE' },
      auditContext
    );

    expect(result.status).toBe('ACTIVE');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'integration',
      })
    );
    expectNoPatientBillingTouch();
  });

  it('test connection and sync now never settle or charge', async () => {
    const raw = buildRawIntegration();
    integrationRepository.findById.mockResolvedValue(raw);

    const testResult = await integrationService.testIntegrationConnection(
      'INT0000001',
      { dry_run: true },
      auditContext
    );
    const syncResult = await integrationService.syncIntegrationNow(
      'INT0000001',
      { force: true },
      auditContext
    );

    expect(testResult.connected).toBe(true);
    expect(testResult.dry_run).toBe(true);
    expect(syncResult.queued).toBe(true);
    expectNoPatientBillingTouch();
  });

  it('delete soft-delete does not touch patient billing', async () => {
    const raw = buildRawIntegration();
    integrationRepository.findById.mockResolvedValue(raw);
    integrationRepository.softDelete.mockResolvedValue(raw);

    await integrationService.deleteIntegration('INT0000001', auditContext);

    expect(integrationRepository.softDelete).toHaveBeenCalled();
    expectNoPatientBillingTouch();
  });

  it('serializes integrations without local paid flags or balances', async () => {
    const raw = buildRawIntegration({
      integration_type: 'BILLING',
    });
    integrationRepository.findById.mockResolvedValue(raw);

    const item = await integrationService.getIntegrationById('INT0000001');

    expect(item.integration_type).toBe('BILLING');
    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
    expect(item).not.toHaveProperty('amount');
    expectNoPatientBillingTouch();
  });

  it('status parity: connector ACTIVE is ops status (NOT_BILLED), not ledger', async () => {
    const raw = buildRawIntegration({ status: 'ACTIVE' });
    integrationRepository.findById.mockResolvedValue(raw);

    const item = await integrationService.getIntegrationById('INT0000001');

    expect(item.status).toBe('ACTIVE');
    expect(item.has_config).toBe(true);
    expectNoPatientBillingTouch();
  });

  it('billing:write alone does not invent connector cash collection path', async () => {
    const raw = buildRawIntegration();
    integrationRepository.findMany.mockResolvedValue([raw]);
    integrationRepository.count.mockResolvedValue(1);

    // Service layer has no billing:write branch — list remains connector-only.
    await integrationService.listIntegrations({}, 1, 20);

    expectNoPatientBillingTouch();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('identifiers helper is not a ledger billing entrypoint', async () => {
    const raw = buildRawIntegration();
    integrationRepository.create.mockResolvedValue(raw);
    integrationRepository.findById.mockResolvedValue(raw);

    await integrationService.createIntegration(
      {
        tenant_id: 'TEN0000001',
        name: 'ADT Feed',
        integration_type: 'HL7',
        status: 'ACTIVE',
      },
      auditContext
    );

    expect(identifiers.resolveIdentifierForPayload).toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
