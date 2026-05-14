/**
 * Webhook subscription service tests
 *
 * @module tests/modules/webhook-subscription/services
 * @description Tests for webhook subscription service functions
 */

jest.mock('@repositories/webhook-subscription/webhook-subscription.repository');
jest.mock('@repositories/integration-log/integration-log.repository', () => ({
  create: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
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

const webhookSubscriptionService = require('@services/webhook-subscription/webhook-subscription.service');
const webhookSubscriptionRepository = require('@repositories/webhook-subscription/webhook-subscription.repository');
const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const identifiers = require('@lib/billing/identifiers');
const { withRetry } = require('@lib/resilience/retry');
const originalFetch = global.fetch;

const buildRawWebhookSubscription = (overrides = {}) => ({
  id: '123e4567-e89b-12d3-a456-426614174000',
  human_friendly_id: 'WHS0000001',
  tenant_id: '223e4567-e89b-12d3-a456-426614174000',
  integration_id: '323e4567-e89b-12d3-a456-426614174000',
  event: 'patient.created',
  target_url: 'https://hooks.example.test/patient-created',
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
    name: 'ADT Feed',
    integration_type: 'HL7',
    status: 'ACTIVE',
  },
  ...overrides,
});

describe('Webhook Subscription Service', () => {
  beforeEach(() => {
    createAuditLog.mockResolvedValue({});
    integrationLogRepository.create.mockResolvedValue({});
    global.fetch = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
    global.fetch = originalFetch;
  });

  describe('getWebhookSubscriptionById', () => {
    it('returns a serialized webhook subscription with public IDs', async () => {
      const rawWebhookSubscription = buildRawWebhookSubscription();
      webhookSubscriptionRepository.findById.mockResolvedValue(rawWebhookSubscription);

      const result = await webhookSubscriptionService.getWebhookSubscriptionById('WHS0000001');

      expect(identifiers.resolveEntityId).toHaveBeenCalledWith({
        model: 'webhook_subscription',
        identifier: 'WHS0000001',
      });
      expect(result).toEqual(
        expect.objectContaining({
          id: 'WHS0000001',
          tenant_id: 'TEN0000001',
          integration_id: 'INT0000001',
          integration_label: 'ADT Feed',
          target_host: 'hooks.example.test',
          is_active: true,
        })
      );
    });

    it('throws HttpError when the webhook subscription is missing', async () => {
      webhookSubscriptionRepository.findById.mockResolvedValue(null);

      await expect(
        webhookSubscriptionService.getWebhookSubscriptionById('missing-id')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('listWebhookSubscriptions', () => {
    it('resolves filters and serializes the collection', async () => {
      const rawWebhookSubscription = buildRawWebhookSubscription();
      webhookSubscriptionRepository.findMany.mockResolvedValue([rawWebhookSubscription]);
      webhookSubscriptionRepository.count.mockResolvedValue(1);

      const result = await webhookSubscriptionService.listWebhookSubscriptions(
        {
          tenant_id: 'TEN0000001',
          integration_id: 'INT0000001',
          event: 'patient',
          is_active: true,
          search: 'hook',
        },
        1,
        20
      );

      expect(identifiers.resolveIdentifierForFilter).toHaveBeenNthCalledWith(1, {
        value: 'TEN0000001',
        model: 'tenant',
      });
      expect(identifiers.resolveIdentifierForFilter).toHaveBeenNthCalledWith(2, {
        value: 'INT0000001',
        model: 'integration',
        where: { tenant_id: 'TEN0000001' },
      });
      expect(webhookSubscriptionRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'TEN0000001',
          integration_id: 'INT0000001',
          event: { contains: 'patient' },
          is_active: true,
          OR: [
            { event: { contains: 'hook' } },
            { target_url: { contains: 'hook' } },
            { human_friendly_id: { contains: 'HOOK' } },
            { integration: { name: { contains: 'hook' } } },
          ],
        }),
        0,
        20,
        { created_at: 'desc' },
        expect.any(Object)
      );
      expect(result.data[0]).toEqual(expect.objectContaining({ id: 'WHS0000001' }));
    });

    it('returns an empty page when a related filter cannot be resolved', async () => {
      identifiers.resolveIdentifierForFilter.mockResolvedValueOnce(null);

      const result = await webhookSubscriptionService.listWebhookSubscriptions(
        { tenant_id: 'TEN9999999' },
        1,
        20
      );

      expect(webhookSubscriptionRepository.findMany).not.toHaveBeenCalled();
      expect(result.data).toEqual([]);
      expect(result.pagination.total).toBe(0);
    });
  });

  describe('createWebhookSubscription', () => {
    it('resolves identifiers, reloads relations, and returns the serialized record', async () => {
      const rawWebhookSubscription = buildRawWebhookSubscription();
      webhookSubscriptionRepository.create.mockResolvedValue({
        id: rawWebhookSubscription.id,
        tenant_id: rawWebhookSubscription.tenant_id,
        integration_id: rawWebhookSubscription.integration_id,
      });
      webhookSubscriptionRepository.findById.mockResolvedValue(rawWebhookSubscription);

      const result = await webhookSubscriptionService.createWebhookSubscription(
        {
          tenant_id: 'TEN0000001',
          integration_id: 'INT0000001',
          event: 'patient.created',
          target_url: 'https://hooks.example.test/patient-created',
          is_active: true,
        },
        { user_id: 'USR0000001' }
      );

      expect(identifiers.resolveIdentifierForPayload).toHaveBeenNthCalledWith(1, {
        value: 'TEN0000001',
        field: 'tenant_id',
        model: 'tenant',
      });
      expect(identifiers.resolveIdentifierForPayload).toHaveBeenNthCalledWith(2, {
        value: 'INT0000001',
        field: 'integration_id',
        model: 'integration',
        where: { tenant_id: 'TEN0000001' },
        nullable: true,
      });
      expect(result).toEqual(expect.objectContaining({ id: 'WHS0000001', integration_id: 'INT0000001' }));
    });
  });

  describe('updateWebhookSubscription', () => {
    it('updates using the resolved UUID and serializes the response', async () => {
      const existingWebhookSubscription = buildRawWebhookSubscription({
        id: 'webhook-uuid',
        human_friendly_id: 'WHS0000002',
      });
      const updatedWebhookSubscription = buildRawWebhookSubscription({
        id: 'webhook-uuid',
        human_friendly_id: 'WHS0000002',
        event: 'patient.updated',
        is_active: false,
      });

      identifiers.resolveEntityId.mockResolvedValueOnce('webhook-uuid');
      webhookSubscriptionRepository.findById
        .mockResolvedValueOnce(existingWebhookSubscription)
        .mockResolvedValueOnce(updatedWebhookSubscription);
      webhookSubscriptionRepository.update.mockResolvedValue({
        id: 'webhook-uuid',
        event: 'patient.updated',
        is_active: false,
      });

      const result = await webhookSubscriptionService.updateWebhookSubscription(
        'WHS0000002',
        { event: 'patient.updated', is_active: false },
        { user_id: 'USR0000001' }
      );

      expect(webhookSubscriptionRepository.update).toHaveBeenCalledWith('webhook-uuid', {
        event: 'patient.updated',
        is_active: false,
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity_id: 'webhook-uuid',
        })
      );
      expect(result).toEqual(expect.objectContaining({ id: 'WHS0000002', is_active: false }));
    });

    it('throws HttpError when the webhook subscription is missing', async () => {
      webhookSubscriptionRepository.findById.mockResolvedValue(null);

      await expect(
        webhookSubscriptionService.updateWebhookSubscription('missing-id', {}, {})
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteWebhookSubscription', () => {
    it('soft deletes using the resolved UUID', async () => {
      const existingWebhookSubscription = buildRawWebhookSubscription({
        id: 'webhook-uuid',
        human_friendly_id: 'WHS0000003',
      });
      const deletedWebhookSubscription = {
        ...existingWebhookSubscription,
        deleted_at: '2026-03-08T15:00:00.000Z',
      };

      identifiers.resolveEntityId.mockResolvedValueOnce('webhook-uuid');
      webhookSubscriptionRepository.findById.mockResolvedValue(existingWebhookSubscription);
      webhookSubscriptionRepository.softDelete.mockResolvedValue(deletedWebhookSubscription);

      const result = await webhookSubscriptionService.deleteWebhookSubscription('WHS0000003', {
        user_id: 'USR0000001',
      });

      expect(webhookSubscriptionRepository.softDelete).toHaveBeenCalledWith('webhook-uuid');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'DELETE',
          entity_id: 'webhook-uuid',
        })
      );
      expect(result).toEqual(deletedWebhookSubscription);
    });
  });

  describe('replayWebhookSubscription', () => {
    it('delivers the replay payload and returns delivery metadata', async () => {
      const rawWebhookSubscription = buildRawWebhookSubscription();
      webhookSubscriptionRepository.findById.mockResolvedValue(rawWebhookSubscription);
      global.fetch.mockResolvedValue({
        ok: true,
        status: 202,
        text: jest.fn(async () => 'accepted'),
      });

      const result = await webhookSubscriptionService.replayWebhookSubscription(
        'WHS0000001',
        { payload_json: { attempt: 2 }, notes: 'manual retry' },
        { user_id: 'USR0000001' }
      );

      expect(result).toEqual(
        expect.objectContaining({
          webhook_subscription_id: 'WHS0000001',
          webhook_subscription_display_id: 'WHS0000001',
          integration_id: 'INT0000001',
          integration_display_id: 'INT0000001',
          integration_label: 'ADT Feed',
          replayed: true,
          signed: false,
          http_status: 202,
          payload_json: { attempt: 2 },
          notes: 'manual retry',
        })
      );
      expect(withRetry).toHaveBeenCalled();
      expect(global.fetch).toHaveBeenCalledWith(
        'https://hooks.example.test/patient-created',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'content-type': 'application/json',
            'x-hms-webhook-event': 'patient.created',
          }),
        })
      );
      expect(integrationLogRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          integration_id: '323e4567-e89b-12d3-a456-426614174000',
          status: 'ACTIVE',
        })
      );
    });

    it('surfaces replay delivery failures as service unavailable errors', async () => {
      const rawWebhookSubscription = buildRawWebhookSubscription();
      webhookSubscriptionRepository.findById.mockResolvedValue(rawWebhookSubscription);
      global.fetch.mockResolvedValue({
        ok: false,
        status: 503,
        text: jest.fn(async () => 'downstream unavailable'),
      });

      await expect(
        webhookSubscriptionService.replayWebhookSubscription(
          'WHS0000001',
          { payload_json: { attempt: 2 } },
          { user_id: 'USR0000001' }
        )
      ).rejects.toMatchObject({
        statusCode: 503,
        messageKey: 'errors.service.unavailable',
      });

      expect(integrationLogRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          integration_id: '323e4567-e89b-12d3-a456-426614174000',
          status: 'ERROR',
        })
      );
    });
  });
});
