jest.mock('@repositories/system-change-log/system-change-log.repository');
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

const systemChangeLogService = require('@services/system-change-log/system-change-log.service');
const systemChangeLogRepository = require('@repositories/system-change-log/system-change-log.repository');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

const buildRawSystemChangeLog = (overrides = {}) => ({
  id: '550e8400-e29b-41d4-a716-446655440000',
  human_friendly_id: 'SCL0000001',
  tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  user_id: '550e8400-e29b-41d4-a716-446655440002',
  change_type: 'DATABASE_MIGRATION',
  details: 'Added new column to users table',
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

describe('System Change Log Service', () => {
  const actor = {
    id: '550e8400-e29b-41d4-a716-446655440002',
    human_friendly_id: 'USR0000001',
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

  it('lists system change logs with scoped filters and serialized output', async () => {
    const rawRecord = buildRawSystemChangeLog();
    systemChangeLogRepository.findMany.mockResolvedValue([rawRecord]);
    systemChangeLogRepository.count.mockResolvedValue(1);

    const result = await systemChangeLogService.listSystemChangeLogs(
      {
        change_type: 'DATABASE',
        search: 'users',
        from_date: '2026-03-01T00:00:00.000Z',
        to_date: '2026-03-31T23:59:59.999Z',
      },
      1,
      20,
      'created_at',
      'asc',
      actor
    );

    expect(systemChangeLogRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        change_type: { contains: 'DATABASE' },
        created_at: {
          gte: expect.any(Date),
          lte: expect.any(Date),
        },
        OR: expect.any(Array),
      }),
      0,
      20,
      { created_at: 'asc' },
      expect.any(Object)
    );
    expect(result.systemChangeLogs[0]).toEqual(
      expect.objectContaining({
        id: 'SCL0000001',
        tenant_id: 'TEN0000001',
        user_id: 'USR0000001',
        user_label: 'Jane Doe',
      })
    );
  });

  it('loads a single system change log by scoped identifier', async () => {
    const rawRecord = buildRawSystemChangeLog();
    resolveModelIdByIdentifier.mockResolvedValueOnce(rawRecord.id);
    systemChangeLogRepository.findMany.mockResolvedValue([rawRecord]);

    const result = await systemChangeLogService.getSystemChangeLogById(
      'SCL0000001',
      actor
    );

    expect(result).toEqual(expect.objectContaining({ id: 'SCL0000001' }));
  });

  it('creates a system change log within the actor tenant and records an audit event', async () => {
    const rawRecord = buildRawSystemChangeLog();
    systemChangeLogRepository.create.mockResolvedValue({
      id: rawRecord.id,
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      change_type: 'DATABASE_MIGRATION',
      details: 'Added new column to users table',
    });
    systemChangeLogRepository.findMany.mockResolvedValue([rawRecord]);

    const result = await systemChangeLogService.createSystemChangeLog(
      {
        change_type: 'DATABASE_MIGRATION',
        details: 'Added new column to users table',
      },
      actor,
      '127.0.0.1'
    );

    expect(systemChangeLogRepository.create).toHaveBeenCalledWith({
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      change_type: 'DATABASE_MIGRATION',
      details: 'Added new column to users table',
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        user_id: actor.id,
        action: 'CREATE',
        entity: 'system_change_log',
      })
    );
    expect(result).toEqual(expect.objectContaining({ id: 'SCL0000001' }));
  });

  it('approves a system change by appending approval metadata and auditing it as an update', async () => {
    const before = buildRawSystemChangeLog();
    const after = buildRawSystemChangeLog({
      details:
        'Added new column to users table\n\n[APPROVED] {"approved_by":"USR0000001"}',
    });
    systemChangeLogRepository.findMany
      .mockResolvedValueOnce([before])
      .mockResolvedValueOnce([after]);
    systemChangeLogRepository.update.mockResolvedValue({
      id: before.id,
      details: after.details,
    });

    const result = await systemChangeLogService.approveSystemChangeLog(
      'SCL0000001',
      'Approved after CAB review',
      actor,
      '127.0.0.1'
    );

    expect(systemChangeLogRepository.update).toHaveBeenCalledWith(
      before.id,
      expect.objectContaining({
        details: expect.stringContaining('[APPROVED]'),
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'system_change_log',
        entity_id: before.id,
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        details: expect.stringContaining('[APPROVED]'),
      })
    );
  });

  it('implements a system change by appending implementation metadata', async () => {
    const before = buildRawSystemChangeLog();
    const after = buildRawSystemChangeLog({
      details:
        'Added new column to users table\n\n[IMPLEMENTED] {"implemented_by":"USR0000001"}',
    });
    systemChangeLogRepository.findMany
      .mockResolvedValueOnce([before])
      .mockResolvedValueOnce([after]);
    systemChangeLogRepository.update.mockResolvedValue({
      id: before.id,
      details: after.details,
    });

    const result = await systemChangeLogService.implementSystemChangeLog(
      'SCL0000001',
      'Released to production',
      actor,
      '127.0.0.1'
    );

    expect(systemChangeLogRepository.update).toHaveBeenCalledWith(
      before.id,
      expect.objectContaining({
        details: expect.stringContaining('[IMPLEMENTED]'),
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'system_change_log',
        entity_id: before.id,
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        details: expect.stringContaining('[IMPLEMENTED]'),
      })
    );
  });

  it('throws for missing scoped records on delete', async () => {
    systemChangeLogRepository.findMany.mockResolvedValue([]);

    await expect(
      systemChangeLogService.deleteSystemChangeLog(
        'SCL9999999',
        actor,
        '127.0.0.1'
      )
    ).rejects.toThrow(HttpError);
  });
});
