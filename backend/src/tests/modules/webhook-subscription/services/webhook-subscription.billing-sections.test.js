/**
 * Billing & sections scan for Integrations Webhooks tab.
 *
 * Webhook subscription CRUD, enable/disable, and Replay are outbound delivery
 * ops and must never post patient Billing ledger rows. Event names such as
 * payment.completed are subscription metadata only (NOT_BILLED). Interop
 * order/payment posting and settlement acknowledgements live on Billing
 * clinical-request / receive-payment paths — not this module.
 */

jest.mock('@repositories/webhook-subscription/webhook-subscription.repository');
jest.mock('@repositories/integration-log/integration-log.repository', () => ({
  create: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/resilience/retry', () => ({
  withRetry: jest.fn(async (task) => task()),
  isTransientError: jest.fn(() => false),
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
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));

const webhookSubscriptionService = require('@services/webhook-subscription/webhook-subscription.service');
const webhookSubscriptionRepository = require('@repositories/webhook-subscription/webhook-subscription.repository');
const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');
const { withRetry } = require('@lib/resilience/retry');

const originalFetch = global.fetch;

const buildRawWebhookSubscription = (overrides = {}) => ({
  id: '123e4567-e89b-12d3-a456-426614174000',
  human_friendly_id: 'WHS0000001',
  tenant_id: '223e4567-e89b-12d3-a456-426614174000',
  integration_id: '323e4567-e89b-12d3-a456-426614174000',
  event: 'payment.completed',
  target_url: 'https://hooks.example.test/payment-completed',
  is_active: true,
  created_at: '2026-03-08T14:00:00.000Z',
  updated_at: '2026-03-08T14:30:00.000Z',
  version: 2,
  tenant: {
    id: '223e4567-e89b-12d3-a456-426614174000',
    human_friendly_id: 'TEN0000001',
    name: 'Acme Health',
  },
  integration: {
    id: '323e4567-e89b-12d3-a456-426614174000',
    human_friendly_id: 'INT0000001',
    name: 'Billing Notify',
    integration_type: 'WEBHOOK',
    status: 'ACTIVE',
    config_json: {},
  },
  ...overrides,
});

const assertNoPatientBillingTouch = () => {
  expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
};

describe('integrations Webhooks billing-sections scan', () => {
  const actor = {
    user_id: '123e4567-e89b-12d3-a456-426614174099',
    tenant_id: '223e4567-e89b-12d3-a456-426614174000',
    ip_address: '127.0.0.1',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    integrationLogRepository.create.mockResolvedValue({});
    global.fetch = jest.fn();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('list webhooks stays NOT_BILLED (no patient ledger post)', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.findMany.mockResolvedValue([raw]);
    webhookSubscriptionRepository.count.mockResolvedValue(1);

    const result = await webhookSubscriptionService.listWebhookSubscriptions(
      {},
      1,
      20
    );

    expect(result.data).toHaveLength(1);
    expect(result.data[0].event).toBe('payment.completed');
    expect(result.data[0]).not.toHaveProperty('payment_status');
    expect(result.data[0]).not.toHaveProperty('balance');
    expect(result.data[0]).not.toHaveProperty('amount_due');
    expect(result.data[0]).not.toHaveProperty('invoice_id');
    assertNoPatientBillingTouch();
  });

  it('list webhooks is idempotent on replay (no double billing post)', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.findMany.mockResolvedValue([raw]);
    webhookSubscriptionRepository.count.mockResolvedValue(1);

    const first = await webhookSubscriptionService.listWebhookSubscriptions({}, 1, 20);
    const second = await webhookSubscriptionService.listWebhookSubscriptions({}, 1, 20);

    expect(first.data).toEqual(second.data);
    expect(webhookSubscriptionRepository.findMany).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('get webhook by id stays NOT_BILLED', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.findById.mockResolvedValue(raw);

    const result = await webhookSubscriptionService.getWebhookSubscriptionById(
      'WHS0000001'
    );

    expect(result.id).toBe('WHS0000001');
    expect(result.event).toBe('payment.completed');
    expect(result).not.toHaveProperty('paid');
    expect(result).not.toHaveProperty('amount');
    assertNoPatientBillingTouch();
  });

  it('Create webhook stays NOT_BILLED (no patient ledger post)', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.create.mockResolvedValue(raw);
    webhookSubscriptionRepository.findById.mockResolvedValue(raw);

    const result = await webhookSubscriptionService.createWebhookSubscription(
      {
        tenant_id: raw.tenant_id,
        integration_id: raw.integration_id,
        event: 'payment.completed',
        target_url: raw.target_url,
        is_active: true,
      },
      actor
    );

    expect(result.event).toBe('payment.completed');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('invoice_id');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'webhook_subscription',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('Enable / disable update stays NOT_BILLED', async () => {
    const existing = buildRawWebhookSubscription({
      id: 'webhook-uuid',
      human_friendly_id: 'WHS0000002',
    });
    const updated = buildRawWebhookSubscription({
      id: 'webhook-uuid',
      human_friendly_id: 'WHS0000002',
      is_active: false,
    });

    identifiers.resolveEntityId.mockResolvedValueOnce('webhook-uuid');
    webhookSubscriptionRepository.findById
      .mockResolvedValueOnce(existing)
      .mockResolvedValueOnce(updated);
    webhookSubscriptionRepository.update.mockResolvedValue({
      id: 'webhook-uuid',
      is_active: false,
    });

    const result = await webhookSubscriptionService.updateWebhookSubscription(
      'WHS0000002',
      { is_active: false },
      actor
    );

    expect(result.is_active).toBe(false);
    expect(result).not.toHaveProperty('balance');
    assertNoPatientBillingTouch();
  });

  it('Delete webhook stays NOT_BILLED', async () => {
    const existing = buildRawWebhookSubscription({
      id: 'webhook-uuid',
      human_friendly_id: 'WHS0000003',
    });
    identifiers.resolveEntityId.mockResolvedValueOnce('webhook-uuid');
    webhookSubscriptionRepository.findById.mockResolvedValue(existing);
    webhookSubscriptionRepository.softDelete.mockResolvedValue({
      ...existing,
      deleted_at: '2026-03-08T15:00:00.000Z',
    });

    await webhookSubscriptionService.deleteWebhookSubscription('WHS0000003', actor);

    expect(webhookSubscriptionRepository.softDelete).toHaveBeenCalledWith(
      'webhook-uuid'
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'webhook_subscription',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('Replay stays NOT_BILLED delivery (no settlement / ledger post)', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.findById.mockResolvedValue(raw);
    global.fetch.mockResolvedValue({
      ok: true,
      status: 202,
      text: jest.fn(async () => 'accepted'),
    });

    const result = await webhookSubscriptionService.replayWebhookSubscription(
      'WHS0000001',
      { payload_json: { attempt: 1 }, notes: 'manual retry' },
      actor
    );

    expect(result.replayed).toBe(true);
    expect(result.event).toBe('payment.completed');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('invoice_id');
    expect(result).not.toHaveProperty('amount');
    expect(withRetry).toHaveBeenCalled();
    expect(global.fetch).toHaveBeenCalledWith(
      'https://hooks.example.test/payment-completed',
      expect.objectContaining({ method: 'POST' })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'REPLAY',
        entity: 'webhook_subscription',
      })
    );
    assertNoPatientBillingTouch();
  });

  it('Replay with payment.completed event never settles patient responsibility', async () => {
    const raw = buildRawWebhookSubscription({ event: 'payment.completed' });
    webhookSubscriptionRepository.findById.mockResolvedValue(raw);
    global.fetch.mockResolvedValue({
      ok: true,
      status: 200,
      text: jest.fn(async () => '{"acked":true}'),
    });

    const result = await webhookSubscriptionService.replayWebhookSubscription(
      'WHS0000001',
      {
        payload_json: {
          invoice_id: 'INV-SHOULD-NOT-SETTLE',
          amount: 100,
          paid: true,
        },
      },
      actor
    );

    expect(result.replayed).toBe(true);
    expect(result.payload_json.paid).toBe(true);
    // Payload is forwarded outbound only — never applied as a ledger settle.
    assertNoPatientBillingTouch();
  });

  it('Replay idempotent delivery_id differs per call (no orphan ledger)', async () => {
    const raw = buildRawWebhookSubscription();
    webhookSubscriptionRepository.findById.mockResolvedValue(raw);
    global.fetch.mockResolvedValue({
      ok: true,
      status: 202,
      text: jest.fn(async () => 'accepted'),
    });

    const first = await webhookSubscriptionService.replayWebhookSubscription(
      'WHS0000001',
      {},
      actor
    );
    const second = await webhookSubscriptionService.replayWebhookSubscription(
      'WHS0000001',
      {},
      actor
    );

    expect(first.delivery_id).not.toEqual(second.delivery_id);
    expect(global.fetch).toHaveBeenCalledTimes(2);
    assertNoPatientBillingTouch();
  });

  it('status parity: is_active remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    const raw = buildRawWebhookSubscription({ is_active: true });
    webhookSubscriptionRepository.findMany.mockResolvedValue([raw]);
    webhookSubscriptionRepository.count.mockResolvedValue(1);

    const result = await webhookSubscriptionService.listWebhookSubscriptions(
      {},
      1,
      20
    );

    expect(result.data[0].is_active).toBe(true);
    expect(result.data[0]).not.toHaveProperty('payment_status');
    assertNoPatientBillingTouch();
  });

  it('unauthorized collect/adjust path is absent (module never imports Billing cashier)', () => {
    expect(webhookSubscriptionService.receivePayment).toBeUndefined();
    expect(webhookSubscriptionService.adjustInvoice).toBeUndefined();
    expect(webhookSubscriptionService.createInvoice).toBeUndefined();
    expect(webhookSubscriptionService.acknowledgeSettlement).toBeUndefined();
    assertNoPatientBillingTouch();
  });
});
