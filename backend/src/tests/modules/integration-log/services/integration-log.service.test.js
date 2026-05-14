/**
 * Integration log service tests
 *
 * @module tests/modules/integration-log/services
 * @description Tests for integration log service functions
 */

jest.mock('@repositories/integration-log/integration-log.repository');
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
}));

const integrationLogService = require('@services/integration-log/integration-log.service');
const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
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

describe('Integration Log Service', () => {
  beforeEach(() => {
    createAuditLog.mockResolvedValue({});
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getIntegrationLogById', () => {
    it('returns a serialized log with public identifiers', async () => {
      const rawLog = buildRawIntegrationLog();
      integrationLogRepository.findById.mockResolvedValue(rawLog);

      const result = await integrationLogService.getIntegrationLogById('ILG0000001');

      expect(identifiers.resolveEntityId).toHaveBeenCalledWith({
        model: 'integration_log',
        identifier: 'ILG0000001',
      });
      expect(result).toEqual(
        expect.objectContaining({
          id: 'ILG0000001',
          integration_id: 'INT0000001',
          integration_display_id: 'INT0000001',
          integration_label: 'ADT Feed',
          tenant_id: 'TEN0000001',
          requires_attention: true,
        })
      );
    });

    it('throws HttpError when the log is not found', async () => {
      integrationLogRepository.findById.mockResolvedValue(null);

      await expect(integrationLogService.getIntegrationLogById('missing-id')).rejects.toThrow(
        HttpError
      );
    });
  });

  describe('getIntegrationLogsByIntegrationId', () => {
    it('resolves public integration IDs before listing logs', async () => {
      const rawLog = buildRawIntegrationLog();
      integrationLogRepository.findMany.mockResolvedValue([rawLog]);
      integrationLogRepository.count.mockResolvedValue(1);

      const result = await integrationLogService.getIntegrationLogsByIntegrationId(
        'INT0000001',
        1,
        20
      );

      expect(identifiers.resolveIdentifierForFilter).toHaveBeenCalledWith({
        value: 'INT0000001',
        model: 'integration',
      });
      expect(integrationLogRepository.findMany).toHaveBeenCalledWith(
        { integration_id: 'INT0000001' },
        0,
        20,
        { logged_at: 'desc' },
        expect.any(Object)
      );
      expect(result.data[0]).toEqual(expect.objectContaining({ id: 'ILG0000001' }));
    });

    it('returns an empty page when the integration filter cannot be resolved', async () => {
      identifiers.resolveIdentifierForFilter.mockResolvedValueOnce(null);

      const result = await integrationLogService.getIntegrationLogsByIntegrationId(
        'INT9999999',
        1,
        20
      );

      expect(integrationLogRepository.findMany).not.toHaveBeenCalled();
      expect(result.data).toEqual([]);
      expect(result.pagination.total).toBe(0);
    });
  });

  describe('listIntegrationLogs', () => {
    it('applies filters and serializes results', async () => {
      const rawLog = buildRawIntegrationLog();
      integrationLogRepository.findMany.mockResolvedValue([rawLog]);
      integrationLogRepository.count.mockResolvedValue(1);

      const result = await integrationLogService.listIntegrationLogs(
        {
          integration_id: 'INT0000001',
          status: 'ERROR',
          search: 'timeout',
        },
        1,
        20,
        'created_at',
        'asc'
      );

      expect(integrationLogRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          integration_id: 'INT0000001',
          status: 'ERROR',
          OR: [
            { message: { contains: 'timeout' } },
            { human_friendly_id: { contains: 'TIMEOUT' } },
            { integration: { name: { contains: 'timeout' } } },
          ],
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
      expect(result.data[0]).toEqual(expect.objectContaining({ id: 'ILG0000001' }));
    });
  });

  describe('replayIntegrationLog', () => {
    it('creates a replayed log and returns the serialized copy', async () => {
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
        integration_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'ERROR',
        message: '[REPLAY] Remote endpoint timed out',
      });

      const result = await integrationLogService.replayIntegrationLog(
        'ILG0000005',
        { notes: 'Retry after transport recovery' },
        { user_id: 'USR0000001', tenant_id: 'TEN0000001' }
      );

      expect(integrationLogRepository.create).toHaveBeenCalledWith({
        integration_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'ERROR',
        message: '[REPLAY] Remote endpoint timed out',
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'REPLAY',
          entity: 'integration_log',
          entity_id: 'new-log-uuid',
        })
      );
      expect(result).toEqual(expect.objectContaining({ id: 'ILG0000006' }));
    });
  });
});
