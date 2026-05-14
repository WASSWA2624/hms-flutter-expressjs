jest.mock('@modules/phi-access-log/repositories/phi-access-log.repository');
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

const phiAccessLogService = require('@modules/phi-access-log/services/phi-access-log.service');
const phiAccessLogRepository = require('@modules/phi-access-log/repositories/phi-access-log.repository');
const { createAuditLog } = require('@lib/audit');
const identifiers = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

const buildRawPhiAccessLog = (overrides = {}) => ({
  id: '550e8400-e29b-41d4-a716-446655440000',
  human_friendly_id: 'PAL0000001',
  tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  user_id: '550e8400-e29b-41d4-a716-446655440002',
  patient_id: '550e8400-e29b-41d4-a716-446655440003',
  access_scope: 'PATIENT',
  reason: 'Clinical review',
  accessed_at: new Date('2026-03-08T10:00:00.000Z'),
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
  patient: {
    id: '550e8400-e29b-41d4-a716-446655440003',
    human_friendly_id: 'PAT0000001',
    first_name: 'John',
    last_name: 'Doe',
  },
  ...overrides,
});

describe('PHI Access Log Service', () => {
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

  it('loads a single PHI access log and serializes public identifiers', async () => {
    const rawLog = buildRawPhiAccessLog();
    resolveModelIdByIdentifier.mockResolvedValueOnce(rawLog.id);
    phiAccessLogRepository.findMany.mockResolvedValue([rawLog]);

    const result = await phiAccessLogService.getPhiAccessLogById('PAL0000001', actor);

    expect(resolveModelIdByIdentifier).toHaveBeenCalledWith({
      model: 'phi_access_log',
      identifier: 'PAL0000001',
      where: { tenant_id: actor.tenant_id },
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'PAL0000001',
        tenant_id: 'TEN0000001',
        user_id: 'USR0000001',
        user_label: 'Jane Doe',
        patient_id: 'PAT0000001',
        patient_label: 'John Doe',
      })
    );
  });

  it('applies scoped filters and date ranges when listing PHI access logs', async () => {
    const rawLog = buildRawPhiAccessLog();
    phiAccessLogRepository.findMany.mockResolvedValue([rawLog]);
    phiAccessLogRepository.count.mockResolvedValue(1);

    const result = await phiAccessLogService.getPhiAccessLogs(
      {
        patient_id: 'PAT0000001',
        access_scope: 'PATIENT',
        date_from: '2026-03-01T00:00:00.000Z',
        date_to: '2026-03-31T23:59:59.999Z',
      },
      1,
      20,
      'accessed_at',
      'desc',
      actor
    );

    expect(identifiers.resolveIdentifierForFilter).toHaveBeenCalledWith({
      value: 'PAT0000001',
      model: 'patient',
      where: { tenant_id: actor.tenant_id, deleted_at: null },
    });
    expect(phiAccessLogRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        patient_id: 'PAT0000001',
        access_scope: 'PATIENT',
        accessed_at: {
          gte: expect.any(Date),
          lte: expect.any(Date),
        },
      }),
      0,
      20,
      { accessed_at: 'desc' },
      expect.any(Object)
    );
    expect(result.data[0]).toEqual(expect.objectContaining({ id: 'PAL0000001' }));
  });

  it('creates a PHI access log with actor scope, resolved patient payload, and audit metadata', async () => {
    identifiers.resolveIdentifierForPayload.mockImplementation(async ({ field }) => {
      if (field === 'patient_id') return '550e8400-e29b-41d4-a716-446655440003';
      return undefined;
    });
    const createdLog = buildRawPhiAccessLog();
    phiAccessLogRepository.create.mockResolvedValue({
      id: createdLog.id,
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      patient_id: '550e8400-e29b-41d4-a716-446655440003',
      access_scope: 'PATIENT',
      reason: 'Clinical review',
    });
    phiAccessLogRepository.findMany.mockResolvedValue([createdLog]);

    const result = await phiAccessLogService.createPhiAccessLog(
      {
        patient_id: 'PAT0000001',
        access_scope: 'PATIENT',
        reason: 'Clinical review',
      },
      actor,
      '192.168.1.1'
    );

    expect(phiAccessLogRepository.create).toHaveBeenCalledWith({
      tenant_id: actor.tenant_id,
      user_id: actor.id,
      patient_id: '550e8400-e29b-41d4-a716-446655440003',
      access_scope: 'PATIENT',
      reason: 'Clinical review',
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: actor.tenant_id,
        user_id: actor.id,
        action: 'CREATE',
        entity: 'phi_access_log',
      })
    );
    expect(result).toEqual(expect.objectContaining({ id: 'PAL0000001' }));
  });

  it('updates and deletes PHI access logs via scoped lookups', async () => {
    const existingLog = buildRawPhiAccessLog();
    const updatedLog = buildRawPhiAccessLog({ access_scope: 'FACILITY' });
    phiAccessLogRepository.findMany
      .mockResolvedValueOnce([existingLog])
      .mockResolvedValueOnce([updatedLog])
      .mockResolvedValueOnce([existingLog]);
    phiAccessLogRepository.update.mockResolvedValue({
      id: existingLog.id,
      access_scope: 'FACILITY',
    });
    phiAccessLogRepository.softDelete.mockResolvedValue({ id: existingLog.id });

    const updated = await phiAccessLogService.updatePhiAccessLog(
      'PAL0000001',
      { access_scope: 'FACILITY' },
      actor,
      '192.168.1.1'
    );
    expect(phiAccessLogRepository.update).toHaveBeenCalledWith(existingLog.id, {
      access_scope: 'FACILITY',
    });
    expect(updated).toEqual(expect.objectContaining({ access_scope: 'FACILITY' }));

    const deleted = await phiAccessLogService.deletePhiAccessLog(
      'PAL0000001',
      actor,
      '192.168.1.1'
    );
    expect(phiAccessLogRepository.softDelete).toHaveBeenCalledWith(existingLog.id);
    expect(deleted).toEqual(expect.objectContaining({ id: 'PAL0000001' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'phi_access_log',
        entity_id: existingLog.id,
      })
    );
  });

  it('throws when a scoped PHI access log cannot be found for update', async () => {
    phiAccessLogRepository.findMany.mockResolvedValue([]);

    await expect(
      phiAccessLogService.updatePhiAccessLog(
        'PAL9999999',
        { access_scope: 'FACILITY' },
        actor,
        '192.168.1.1'
      )
    ).rejects.toThrow(HttpError);
  });
});
