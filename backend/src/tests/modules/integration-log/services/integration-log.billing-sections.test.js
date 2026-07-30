/**
 * Billing & sections scan for Integrations Logs tab.
 *
 * Integration log list/detail and Replay are delivery/audit ops and must never
 * post patient Billing ledger rows. Replay creates an audited log copy only
 * (NOT_BILLED). Interop order/payment posting and webhook settlement
 * acknowledgements live on Billing clinical-request / receive-payment paths —
 * not this module.
 */

jest.mock('@repositories/integration-log/integration-log.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
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
}));
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));

const integrationLogService = require('@services/integration-log/integration-log.service');
const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');

const buildRawIntegrationLog = (overrides = {}) => ({
  id: '333e4567-e89b-12d3-a456-426614174000',
  human_friendly_id: 'ILG0000001',
  integration_id: '123e4567-e89b-12d3-a456-426614174000',
  status: 'ERROR',
  message: 'Remote endpoint timed out',
  logged_at: '2026-03-08T13:00:00.000Z',
  created_at: '2026-03-08T13:00:00.000Z',
  updated_at: '2026-03-08T13:05:00.000Z',
  version: 2,
  integration: {
    id: '123e4567-e89b-12d3-a456-426614174000',
    human_friendly_id: 'INT0000001',
    tenant_id: '223e4567-e89b-12d3-a456-426614174000',
    name: 'ADT Feed',
    integration_type: 'HL7',
    status: 'ERROR',
    tenant: {
      id: '223e4567-e89b-12d3-a456-426614174000',
      human_friendly_id: 'TEN0000001',
      name: 'Acme Health',
    },
  },
  ...overrides,
});

const assertNoPatientBillingTouch = () => {
  expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
};

describe('integrations Logs billing-sections scan', () => {
  const actor = {
    user_id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '223e4567-e89b-12d3-a456-426614174000',
    ip_address: '127.0.0.1',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('list logs stays NOT_BILLED (no patient ledger post)', async () => {
    const rawLog = buildRawIntegrationLog();
    integrationLogRepository.findMany.mockResolvedValue([rawLog]);
    integrationLogRepository.count.mockResolvedValue(1);

    const result = await integrationLogService.listIntegrationLogs({}, 1, 20);

    expect(result.data).toHaveLength(1);
    expect(result.data[0]).not.toHaveProperty('payment_status');
    expect(result.data[0]).not.toHaveProperty('balance');
    expect(result.data[0]).not.toHaveProperty('amount_due');
    expect(result.data[0]).not.toHaveProperty('invoice_id');
    assertNoPatientBillingTouch();
  });

  it('list logs is idempotent on replay (no double billing post)', async () => {
    const rawLog = buildRawIntegrationLog();
    integrationLogRepository.findMany.mockResolvedValue([rawLog]);
    integrationLogRepository.count.mockResolvedValue(1);

    const first = await integrationLogService.listIntegrationLogs({}, 1, 20);
    const second = await integrationLogService.listIntegrationLogs({}, 1, 20);

    expect(first.data).toEqual(second.data);
    expect(integrationLogRepository.findMany).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('get log by id stays NOT_BILLED', async () => {
    const rawLog = buildRawIntegrationLog();
    identifiers.resolveEntityId.mockResolvedValueOnce(rawLog.id);
    integrationLogRepository.findById.mockResolvedValue(rawLog);

    const result = await integrationLogService.getIntegrationLogById('ILG0000001');

    expect(result.id).toBe('ILG0000001');
    expect(result).not.toHaveProperty('paid');
    expect(result).not.toHaveProperty('payment_status');
    assertNoPatientBillingTouch();
  });

  it('Replay stays NOT_BILLED audit copy (no patient ledger post)', async () => {
    const existingLog = buildRawIntegrationLog({
      id: 'log-uuid',
      human_friendly_id: 'ILG0000005',
    });
    const replayedLog = buildRawIntegrationLog({
      id: 'new-log-uuid',
      human_friendly_id: 'ILG0000006',
      message: '[REPLAY] Remote endpoint timed out',
    });

    identifiers.resolveEntityId.mockResolvedValueOnce('log-uuid');
    integrationLogRepository.findById
      .mockResolvedValueOnce(existingLog)
      .mockResolvedValueOnce(replayedLog);
    integrationLogRepository.create.mockResolvedValue({
      id: 'new-log-uuid',
      integration_id: existingLog.integration_id,
      status: 'ERROR',
      message: '[REPLAY] Remote endpoint timed out',
    });

    const result = await integrationLogService.replayIntegrationLog(
      'ILG0000005',
      { notes: 'Retry after transport recovery' },
      actor
    );

    expect(integrationLogRepository.create).toHaveBeenCalledWith({
      integration_id: existingLog.integration_id,
      status: 'ERROR',
      message: '[REPLAY] Remote endpoint timed out',
    });
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('invoice_id');
    expect(result).not.toHaveProperty('amount_due');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'REPLAY',
        entity: 'integration_log',
        entity_id: 'new-log-uuid',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('Replay replay creates distinct audit rows (no orphan ledger)', async () => {
    const existingLog = buildRawIntegrationLog({ id: 'log-uuid' });
    identifiers.resolveEntityId
      .mockResolvedValueOnce('log-uuid')
      .mockResolvedValueOnce('log-uuid');
    integrationLogRepository.findById
      .mockResolvedValueOnce(existingLog)
      .mockResolvedValueOnce(
        buildRawIntegrationLog({
          id: 'replay-1',
          human_friendly_id: 'ILG0000010',
          message: '[REPLAY] Remote endpoint timed out',
        })
      )
      .mockResolvedValueOnce(existingLog)
      .mockResolvedValueOnce(
        buildRawIntegrationLog({
          id: 'replay-2',
          human_friendly_id: 'ILG0000011',
          message: '[REPLAY] Remote endpoint timed out',
        })
      );
    integrationLogRepository.create
      .mockResolvedValueOnce({
        id: 'replay-1',
        integration_id: existingLog.integration_id,
        status: 'ERROR',
        message: '[REPLAY] Remote endpoint timed out',
      })
      .mockResolvedValueOnce({
        id: 'replay-2',
        integration_id: existingLog.integration_id,
        status: 'ERROR',
        message: '[REPLAY] Remote endpoint timed out',
      });

    const first = await integrationLogService.replayIntegrationLog(
      'ILG0000001',
      {},
      actor
    );
    const second = await integrationLogService.replayIntegrationLog(
      'ILG0000001',
      {},
      actor
    );

    expect(first.id).not.toEqual(second.id);
    expect(integrationLogRepository.create).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('status parity: log status remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    const rawLog = buildRawIntegrationLog({ status: 'ERROR' });
    integrationLogRepository.findMany.mockResolvedValue([rawLog]);
    integrationLogRepository.count.mockResolvedValue(1);

    const result = await integrationLogService.listIntegrationLogs({}, 1, 20);

    expect(result.data[0].status).toBe('ERROR');
    expect(result.data[0].requires_attention).toBe(true);
    expect(result.data[0]).not.toHaveProperty('payment_status');
    assertNoPatientBillingTouch();
  });

  it('unauthorized collect/adjust path is absent (module never imports Billing engine)', () => {
    expect(integrationLogService.receivePayment).toBeUndefined();
    expect(integrationLogService.adjustInvoice).toBeUndefined();
    expect(integrationLogService.createInvoice).toBeUndefined();
    expect(integrationLogService.upsertClinicalRequestBilling).toBeUndefined();
    assertNoPatientBillingTouch();
  });
});
