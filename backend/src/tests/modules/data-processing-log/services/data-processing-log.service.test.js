jest.mock('@modules/data-processing-log/repositories/data-processing-log.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => {
    for (const value of values) {
      if (typeof value !== 'string') continue;
      const normalized = value.trim();
      if (!normalized) continue;
      if (!/^[0-9a-f]{8}-/i.test(normalized)) return normalized;
    }
    return null;
  }),
  resolveIdentifierForFilter: jest.fn(async ({ value }) =>
    value === undefined ? undefined : value
  ),
  resolveIdentifierForPayload: jest.fn(async ({ value, nullable = false }) =>
    value === undefined ? (nullable ? null : value) : value
  ),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const dataProcessingLogService = require('@modules/data-processing-log/services/data-processing-log.service');
const dataProcessingLogRepository = require('@modules/data-processing-log/repositories/data-processing-log.repository');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

const buildRawDataProcessingLog = (overrides = {}) => ({
  id: '550e8400-e29b-41d4-a716-446655440000',
  human_friendly_id: 'DPL0000001',
  tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  user_id: '550e8400-e29b-41d4-a716-446655440002',
  purpose: 'TREATMENT',
  legal_basis: 'CONSENT',
  details: 'Processed lab request data',
  processed_at: new Date('2026-03-08T10:00:00.000Z'),
  created_at: new Date('2026-03-08T10:00:00.000Z'),
  updated_at: new Date('2026-03-08T10:05:00.000Z'),
  tenant: {
    id: '550e8400-e29b-41d4-a716-446655440001',
    human_friendly_id: 'TEN0000001',
    name: 'Acme Health',
  },
  user: {
    id: '550e8400-e29b-41d4-a716-446655440002',
    human_friendly_id: 'USR0000001',
    email: 'jane.doe@example.com',
    first_name: 'Jane',
    last_name: 'Doe',
  },
  ...overrides,
});

describe('Data Processing Log Service', () => {
  const actor = {
    id: '550e8400-e29b-41d4-a716-446655440002',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    identifiers.resolveIdentifierForFilter.mockImplementation(async ({ value }) =>
      value === undefined ? undefined : value
    );
    identifiers.resolveIdentifierForPayload.mockImplementation(
      async ({ value, nullable = false }) =>
        value === undefined ? (nullable ? null : value) : value
    );
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
  });

  it('loads and serializes a single data processing log by scoped identifier', async () => {
    const rawLog = buildRawDataProcessingLog();
    resolveModelIdByIdentifier.mockResolvedValueOnce(rawLog.id);
    dataProcessingLogRepository.findMany.mockResolvedValue([rawLog]);

    const result = await dataProcessingLogService.getDataProcessingLogById(
      'DPL0000001',
      actor
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'DPL0000001',
        tenant_id: 'TEN0000001',
        user_id: 'USR0000001',
        user_label: 'Jane Doe',
      })
    );
    expect(dataProcessingLogRepository.findMany).toHaveBeenCalledWith(
      { id: rawLog.id, tenant_id: actor.tenant_id },
      0,
      1,
      { processed_at: 'desc' },
      expect.any(Object)
    );
  });

  it('applies scoped filters and serializes paginated data processing logs', async () => {
    const rawLog = buildRawDataProcessingLog();
    dataProcessingLogRepository.findMany.mockResolvedValue([rawLog]);
    dataProcessingLogRepository.count.mockResolvedValue(1);

    const result = await dataProcessingLogService.getDataProcessingLogs(
      {
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT',
        date_from: '2026-03-01T00:00:00.000Z',
        date_to: '2026-03-31T23:59:59.999Z',
        search: 'lab',
      },
      1,
      20,
      'processed_at',
      'desc',
      actor
    );

    expect(dataProcessingLogRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT',
        processed_at: {
          gte: expect.any(Date),
          lte: expect.any(Date),
        },
        OR: expect.any(Array),
      }),
      0,
      20,
      { processed_at: 'desc' },
      expect.any(Object)
    );
    expect(result).toEqual(
      expect.objectContaining({
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1,
      })
    );
  });

  it('creates a data processing log within the actor tenant and records an audit entry', async () => {
    const createdLog = buildRawDataProcessingLog();
    dataProcessingLogRepository.create.mockResolvedValue({
      id: createdLog.id,
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      purpose: 'TREATMENT',
      legal_basis: 'CONSENT',
      details: 'Processed lab request data',
    });
    dataProcessingLogRepository.findMany.mockResolvedValue([createdLog]);

    const result = await dataProcessingLogService.createDataProcessingLog(
      {
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT',
        details: 'Processed lab request data',
      },
      actor,
      '192.168.1.1'
    );

    expect(dataProcessingLogRepository.create).toHaveBeenCalledWith({
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      purpose: 'TREATMENT',
      legal_basis: 'CONSENT',
      details: 'Processed lab request data',
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        user_id: actor.id,
        action: 'CREATE',
        entity: 'data_processing_log',
      })
    );
    expect(result).toEqual(expect.objectContaining({ id: 'DPL0000001' }));
  });

  it('updates scoped records and resolves a replacement user identifier when provided', async () => {
    const existingLog = buildRawDataProcessingLog();
    const updatedLog = buildRawDataProcessingLog({
      purpose: 'OPERATIONS',
      legal_basis: 'CONTRACT',
    });
    identifiers.resolveIdentifierForPayload.mockImplementation(async ({ field }) => {
      if (field === 'user_id') return '550e8400-e29b-41d4-a716-446655440009';
      return undefined;
    });
    dataProcessingLogRepository.findMany
      .mockResolvedValueOnce([existingLog])
      .mockResolvedValueOnce([updatedLog]);
    dataProcessingLogRepository.update.mockResolvedValue({ id: existingLog.id });

    const result = await dataProcessingLogService.updateDataProcessingLog(
      'DPL0000001',
      {
        purpose: 'OPERATIONS',
        legal_basis: 'CONTRACT',
        user_id: 'USR0000009',
      },
      actor,
      '192.168.1.1'
    );

    expect(dataProcessingLogRepository.update).toHaveBeenCalledWith(existingLog.id, {
      purpose: 'OPERATIONS',
      legal_basis: 'CONTRACT',
      user_id: '550e8400-e29b-41d4-a716-446655440009',
    });
    expect(result).toEqual(expect.objectContaining({ purpose: 'OPERATIONS' }));
  });

  it('throws for missing records and records soft deletes for scoped matches', async () => {
    dataProcessingLogRepository.findMany.mockResolvedValueOnce([]);
    await expect(
      dataProcessingLogService.deleteDataProcessingLog(
        'DPL9999999',
        actor,
        '192.168.1.1'
      )
    ).rejects.toThrow(HttpError);

    const existingLog = buildRawDataProcessingLog();
    dataProcessingLogRepository.findMany.mockResolvedValueOnce([existingLog]);
    dataProcessingLogRepository.softDelete.mockResolvedValue({ id: existingLog.id });

    const deleted = await dataProcessingLogService.deleteDataProcessingLog(
      'DPL0000001',
      actor,
      '192.168.1.1'
    );

    expect(dataProcessingLogRepository.softDelete).toHaveBeenCalledWith(existingLog.id);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'data_processing_log',
        entity_id: existingLog.id,
      })
    );
    expect(deleted).toEqual(expect.objectContaining({ id: 'DPL0000001' }));
  });
});
