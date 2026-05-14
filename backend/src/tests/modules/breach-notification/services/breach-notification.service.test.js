jest.mock('@repositories/breach-notification/breach-notification.repository');
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

const breachNotificationService = require('@services/breach-notification/breach-notification.service');
const breachNotificationRepository = require('@repositories/breach-notification/breach-notification.repository');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

const buildRawBreachNotification = (overrides = {}) => ({
  id: '550e8400-e29b-41d4-a716-446655440000',
  human_friendly_id: 'BRN0000001',
  tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  severity: 'HIGH',
  status: 'OPEN',
  description: 'Security breach detected',
  reported_at: new Date('2026-03-01T10:00:00.000Z'),
  resolved_at: null,
  created_at: new Date('2026-03-01T10:00:00.000Z'),
  updated_at: new Date('2026-03-01T10:05:00.000Z'),
  tenant: {
    id: '550e8400-e29b-41d4-a716-446655440001',
    human_friendly_id: 'TEN0000001',
    name: 'Acme Health',
  },
  ...overrides,
});

describe('Breach Notification Service', () => {
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

  it('lists breach notifications with scoped filters and serialized identifiers', async () => {
    const rawRecord = buildRawBreachNotification();
    breachNotificationRepository.findMany.mockResolvedValue([rawRecord]);
    breachNotificationRepository.count.mockResolvedValue(1);

    const result = await breachNotificationService.listBreachNotifications(
      {
        severity: 'HIGH',
        status: 'OPEN',
        search: 'security',
        from_date: '2026-03-01T00:00:00.000Z',
        to_date: '2026-03-31T23:59:59.999Z',
      },
      1,
      20,
      'reported_at',
      'desc',
      actor
    );

    expect(breachNotificationRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        severity: 'HIGH',
        status: 'OPEN',
        reported_at: {
          gte: expect.any(Date),
          lte: expect.any(Date),
        },
        OR: expect.any(Array),
      }),
      0,
      20,
      { reported_at: 'desc' },
      expect.any(Object)
    );
    expect(result.breachNotifications[0]).toEqual(
      expect.objectContaining({
        id: 'BRN0000001',
        tenant_id: 'TEN0000001',
      })
    );
    expect(result.pagination).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
      })
    );
  });

  it('loads a single breach notification by scoped identifier', async () => {
    const rawRecord = buildRawBreachNotification();
    resolveModelIdByIdentifier.mockResolvedValueOnce(rawRecord.id);
    breachNotificationRepository.findMany.mockResolvedValue([rawRecord]);

    const result = await breachNotificationService.getBreachNotificationById(
      'BRN0000001',
      actor
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'BRN0000001',
        status: 'OPEN',
        tenant_id: 'TEN0000001',
      })
    );
  });

  it('creates a breach notification within the actor tenant and records an audit event', async () => {
    const rawRecord = buildRawBreachNotification();
    breachNotificationRepository.create.mockResolvedValue({
      id: rawRecord.id,
      tenant_id: actor.tenant_id,
      severity: 'HIGH',
      status: 'OPEN',
      description: 'Security breach detected',
    });
    breachNotificationRepository.findMany.mockResolvedValue([rawRecord]);

    const result = await breachNotificationService.createBreachNotification(
      {
        severity: 'HIGH',
        description: 'Security breach detected',
      },
      actor,
      '127.0.0.1'
    );

    expect(breachNotificationRepository.create).toHaveBeenCalledWith({
      tenant_id: actor.tenant_id,
      severity: 'HIGH',
      status: 'OPEN',
      description: 'Security breach detected',
      reported_at: undefined,
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        user_id: actor.id,
        action: 'CREATE',
        entity: 'breach_notification',
      })
    );
    expect(result).toEqual(expect.objectContaining({ id: 'BRN0000001' }));
  });

  it('resolves a breach notification, sets resolved_at, and audits it as an update', async () => {
    const before = buildRawBreachNotification();
    const after = buildRawBreachNotification({
      status: 'RESOLVED',
      resolved_at: new Date('2026-03-08T12:00:00.000Z'),
    });
    breachNotificationRepository.findMany
      .mockResolvedValueOnce([before])
      .mockResolvedValueOnce([after]);
    breachNotificationRepository.update.mockResolvedValue({
      id: before.id,
      status: 'RESOLVED',
      resolved_at: after.resolved_at,
    });

    const result = await breachNotificationService.resolveBreachNotification(
      'BRN0000001',
      after.resolved_at,
      actor,
      '127.0.0.1'
    );

    expect(breachNotificationRepository.update).toHaveBeenCalledWith(before.id, {
      status: 'RESOLVED',
      resolved_at: after.resolved_at,
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'breach_notification',
        entity_id: before.id,
      })
    );
    expect(result).toEqual(expect.objectContaining({ status: 'RESOLVED' }));
  });

  it('throws for missing or already resolved breach notifications', async () => {
    breachNotificationRepository.findMany.mockResolvedValueOnce([]);
    await expect(
      breachNotificationService.resolveBreachNotification(
        'BRN9999999',
        null,
        actor,
        '127.0.0.1'
      )
    ).rejects.toThrow(HttpError);

    breachNotificationRepository.findMany.mockResolvedValueOnce([
      buildRawBreachNotification({ status: 'RESOLVED' }),
    ]);
    await expect(
      breachNotificationService.resolveBreachNotification(
        'BRN0000001',
        null,
        actor,
        '127.0.0.1'
      )
    ).rejects.toThrow(HttpError);
  });
});
