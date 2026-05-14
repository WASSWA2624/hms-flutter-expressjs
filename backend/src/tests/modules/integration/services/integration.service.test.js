/**
 * Integration service tests
 *
 * @module tests/modules/integration/services
 * @description Tests for integration service functions
 */

jest.mock('@repositories/integration/integration.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
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
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
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

describe('Integration Service', () => {
  beforeEach(() => {
    createAuditLog.mockResolvedValue({});
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getIntegrationById', () => {
    it('returns a public-facing integration payload', async () => {
      const rawIntegration = buildRawIntegration();
      integrationRepository.findById.mockResolvedValue(rawIntegration);

      const result = await integrationService.getIntegrationById('INT0000001');

      expect(identifiers.resolveEntityId).toHaveBeenCalledWith({
        model: 'integration',
        identifier: 'INT0000001',
      });
      expect(integrationRepository.findById).toHaveBeenCalledWith(
        'INT0000001',
        expect.objectContaining({
          tenant: expect.any(Object),
          _count: expect.any(Object),
        })
      );
      expect(result).toEqual(
        expect.objectContaining({
          id: 'INT0000001',
          human_friendly_id: 'INT0000001',
          display_id: 'INT0000001',
          tenant_id: 'TEN0000001',
          tenant_label: 'Acme Health',
          name: 'ADT Feed',
          log_count: 4,
          webhook_subscription_count: 2,
          has_config: true,
        })
      );
    });

    it('redacts sensitive integration config values from API payloads', async () => {
      const rawIntegration = buildRawIntegration({
        config_json: {
          endpoint: 'https://hl7.example.test',
          signing_secret: 'super-secret-value',
          nested: {
            api_key: 'hidden-key',
          },
        },
      });
      integrationRepository.findById.mockResolvedValue(rawIntegration);

      const result = await integrationService.getIntegrationById('INT0000001');

      expect(result.config_json).toEqual({
        endpoint: 'https://hl7.example.test',
        signing_secret: '[REDACTED]',
        nested: {
          api_key: '[REDACTED]',
        },
      });
    });

    it('throws HttpError when the integration is not found', async () => {
      integrationRepository.findById.mockResolvedValue(null);

      await expect(integrationService.getIntegrationById('missing-id')).rejects.toThrow(HttpError);
    });
  });

  describe('listIntegrations', () => {
    it('resolves friendly filters and serializes the list', async () => {
      const rawIntegration = buildRawIntegration();
      integrationRepository.findMany.mockResolvedValue([rawIntegration]);
      integrationRepository.count.mockResolvedValue(1);

      const result = await integrationService.listIntegrations(
        {
          tenant_id: 'TEN0000001',
          integration_type: 'HL7',
          status: 'ACTIVE',
          name: 'ADT',
          search: 'feed',
        },
        1,
        20
      );

      expect(identifiers.resolveIdentifierForFilter).toHaveBeenCalledWith({
        value: 'TEN0000001',
        model: 'tenant',
      });
      expect(integrationRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'TEN0000001',
          integration_type: 'HL7',
          status: 'ACTIVE',
          name: { contains: 'ADT' },
          OR: [
            { name: { contains: 'feed' } },
            { human_friendly_id: { contains: 'FEED' } },
          ],
        }),
        0,
        20,
        { created_at: 'desc' },
        expect.any(Object)
      );
      expect(result.data[0]).toEqual(expect.objectContaining({ id: 'INT0000001' }));
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('returns an empty page when a filter cannot be resolved', async () => {
      identifiers.resolveIdentifierForFilter.mockResolvedValueOnce(null);

      const result = await integrationService.listIntegrations({ tenant_id: 'TEN9999999' }, 2, 20);

      expect(integrationRepository.findMany).not.toHaveBeenCalled();
      expect(result).toEqual({
        data: [],
        pagination: {
          page: 2,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: true,
        },
      });
    });
  });

  describe('createIntegration', () => {
    it('resolves foreign keys, reloads relations, and returns the serialized record', async () => {
      const rawIntegration = buildRawIntegration();
      integrationRepository.create.mockResolvedValue({
        id: rawIntegration.id,
        tenant_id: rawIntegration.tenant_id,
      });
      integrationRepository.findById.mockResolvedValue(rawIntegration);

      const result = await integrationService.createIntegration(
        {
          tenant_id: 'TEN0000001',
          integration_type: 'HL7',
          status: 'ACTIVE',
          name: 'ADT Feed',
        },
        {
          user_id: 'USR0000001',
          tenant_id: 'TEN0000001',
          ip_address: '127.0.0.1',
        }
      );

      expect(identifiers.resolveIdentifierForPayload).toHaveBeenCalledWith({
        value: 'TEN0000001',
        field: 'tenant_id',
        model: 'tenant',
      });
      expect(integrationRepository.create).toHaveBeenCalledWith({
        tenant_id: 'TEN0000001',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'ADT Feed',
      });
      expect(result).toEqual(expect.objectContaining({ id: 'INT0000001', tenant_id: 'TEN0000001' }));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'integration',
          entity_id: rawIntegration.id,
        })
      );
    });
  });

  describe('updateIntegration', () => {
    it('updates by underlying UUID even when routed by public ID', async () => {
      const existingIntegration = buildRawIntegration({
        id: 'integration-uuid',
        human_friendly_id: 'INT0000020',
      });
      const updatedIntegration = buildRawIntegration({
        id: 'integration-uuid',
        human_friendly_id: 'INT0000020',
        name: 'Updated Feed',
        status: 'ERROR',
      });

      identifiers.resolveEntityId.mockResolvedValueOnce('integration-uuid');
      integrationRepository.findById
        .mockResolvedValueOnce(existingIntegration)
        .mockResolvedValueOnce(updatedIntegration);
      integrationRepository.update.mockResolvedValue({
        id: 'integration-uuid',
        name: 'Updated Feed',
        status: 'ERROR',
      });

      const result = await integrationService.updateIntegration(
        'INT0000020',
        { name: 'Updated Feed', status: 'ERROR' },
        { user_id: 'USR0000001' }
      );

      expect(integrationRepository.update).toHaveBeenCalledWith('integration-uuid', {
        name: 'Updated Feed',
        status: 'ERROR',
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity_id: 'integration-uuid',
        })
      );
      expect(result).toEqual(expect.objectContaining({ id: 'INT0000020', status: 'ERROR' }));
    });

    it('throws HttpError when the integration is missing', async () => {
      integrationRepository.findById.mockResolvedValue(null);

      await expect(integrationService.updateIntegration('missing-id', {}, {})).rejects.toThrow(
        HttpError
      );
    });
  });

  describe('deleteIntegration', () => {
    it('soft deletes using the resolved primary key', async () => {
      const existingIntegration = buildRawIntegration({
        id: 'integration-uuid',
        human_friendly_id: 'INT0000021',
      });
      const deletedIntegration = {
        ...existingIntegration,
        deleted_at: '2026-03-08T14:00:00.000Z',
      };

      identifiers.resolveEntityId.mockResolvedValueOnce('integration-uuid');
      integrationRepository.findById.mockResolvedValue(existingIntegration);
      integrationRepository.softDelete.mockResolvedValue(deletedIntegration);

      const result = await integrationService.deleteIntegration('INT0000021', {
        user_id: 'USR0000001',
      });

      expect(integrationRepository.softDelete).toHaveBeenCalledWith('integration-uuid');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'DELETE',
          entity_id: 'integration-uuid',
        })
      );
      expect(result).toEqual(deletedIntegration);
    });
  });

  describe('testIntegrationConnection', () => {
    it('returns public identifiers in the action payload', async () => {
      const rawIntegration = buildRawIntegration();
      integrationRepository.findById.mockResolvedValue(rawIntegration);

      const result = await integrationService.testIntegrationConnection('INT0000001', {
        timeout_ms: 5000,
        dry_run: true,
      });

      expect(result).toEqual(
        expect.objectContaining({
          integration_id: 'INT0000001',
          integration_display_id: 'INT0000001',
          integration_label: 'ADT Feed',
          connected: true,
          timeout_ms: 5000,
          dry_run: true,
        })
      );
    });
  });

  describe('syncIntegrationNow', () => {
    it('returns public identifiers in the sync payload', async () => {
      const rawIntegration = buildRawIntegration();
      integrationRepository.findById.mockResolvedValue(rawIntegration);

      const result = await integrationService.syncIntegrationNow('INT0000001', {
        force: true,
        scope: 'delta',
      });

      expect(result).toEqual(
        expect.objectContaining({
          integration_id: 'INT0000001',
          integration_display_id: 'INT0000001',
          integration_label: 'ADT Feed',
          queued: true,
          forced: true,
          scope: 'delta',
        })
      );
    });
  });
});
