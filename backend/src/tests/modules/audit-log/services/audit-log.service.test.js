jest.mock('@modules/audit-log/repositories/audit-log.repository');
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
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const auditLogService = require('@modules/audit-log/services/audit-log.service');
const auditLogRepository = require('@modules/audit-log/repositories/audit-log.repository');
const identifiers = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { HttpError } = require('@lib/errors');

const buildRawAuditLog = (overrides = {}) => ({
  id: '550e8400-e29b-41d4-a716-446655440000',
  human_friendly_id: 'AUD0000001',
  tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  user_id: '550e8400-e29b-41d4-a716-446655440002',
  action: 'CREATE',
  entity: 'patient',
  entity_id: 'PAT0000001',
  diff_json: { after: { status: 'active' } },
  ip_address: '127.0.0.1',
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

describe('Audit Log Service', () => {
  const scopedUser = {
    id: '550e8400-e29b-41d4-a716-446655440099',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    identifiers.resolveIdentifierForFilter.mockImplementation(async ({ value }) =>
      value === undefined ? undefined : value
    );
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
  });

  it('loads a single audit log by scoped identifier and serializes public fields', async () => {
    const rawAuditLog = buildRawAuditLog();
    resolveModelIdByIdentifier.mockResolvedValueOnce(rawAuditLog.id);
    auditLogRepository.findMany.mockResolvedValue([rawAuditLog]);

    const result = await auditLogService.getAuditLogById('AUD0000001', scopedUser);

    expect(resolveModelIdByIdentifier).toHaveBeenCalledWith({
      model: 'audit_log',
      identifier: 'AUD0000001',
      where: { tenant_id: scopedUser.tenant_id },
    });
    expect(auditLogRepository.findMany).toHaveBeenCalledWith(
      { id: rawAuditLog.id, tenant_id: scopedUser.tenant_id },
      0,
      1,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'AUD0000001',
        tenant_id: 'TEN0000001',
        user_id: 'USR0000001',
        user_label: 'Jane Doe',
        entity_id: 'PAT0000001',
        entity_reference: 'PAT0000001',
      })
    );
  });

  it('throws when a scoped audit log cannot be found', async () => {
    auditLogRepository.findMany.mockResolvedValue([]);

    await expect(
      auditLogService.getAuditLogById('AUD9999999', scopedUser)
    ).rejects.toThrow(HttpError);
  });

  it('applies scoped filters, pagination, and sorting when listing audit logs', async () => {
    const rawAuditLog = buildRawAuditLog();
    auditLogRepository.findMany.mockResolvedValue([rawAuditLog]);
    auditLogRepository.count.mockResolvedValue(1);

    const result = await auditLogService.getAuditLogs(
      {
        user_id: 'USR0000001',
        action: 'CREATE',
        entity: 'patient',
        entity_id: 'PAT0000001',
        search: 'jane',
      },
      2,
      10,
      'action',
      'asc',
      scopedUser
    );

    expect(identifiers.resolveIdentifierForFilter).toHaveBeenCalledWith({
      value: 'USR0000001',
      model: 'user',
      where: { tenant_id: scopedUser.tenant_id },
    });
    expect(auditLogRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: scopedUser.tenant_id,
        user_id: 'USR0000001',
        action: 'CREATE',
        entity: 'patient',
        entity_id: 'PAT0000001',
        OR: expect.any(Array),
      }),
      10,
      10,
      { action: 'asc' },
      expect.any(Object)
    );
    expect(result).toEqual(
      expect.objectContaining({
        total: 1,
        page: 2,
        limit: 10,
        totalPages: 1,
      })
    );
    expect(result.data[0]).toEqual(expect.objectContaining({ id: 'AUD0000001' }));
  });

  it('returns an empty page when a tenant filter resolves outside the current scope', async () => {
    identifiers.resolveIdentifierForFilter.mockResolvedValueOnce(
      '550e8400-e29b-41d4-a716-446655440777'
    );

    const result = await auditLogService.getAuditLogs(
      { tenant_id: 'TEN9999999' },
      1,
      20,
      'created_at',
      'desc',
      scopedUser
    );

    expect(auditLogRepository.findMany).not.toHaveBeenCalled();
    expect(result).toEqual({
      data: [],
      total: 0,
      page: 1,
      limit: 20,
      totalPages: 0,
    });
  });

  it('reuses the list path for user-specific and entity-specific helper queries', async () => {
    const rawAuditLog = buildRawAuditLog();
    auditLogRepository.findMany.mockResolvedValue([rawAuditLog]);
    auditLogRepository.count.mockResolvedValue(1);

    const byUser = await auditLogService.getAuditLogsByUserId(
      'USR0000001',
      1,
      20,
      'created_at',
      'desc',
      scopedUser
    );
    expect(auditLogRepository.findMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        tenant_id: scopedUser.tenant_id,
        user_id: 'USR0000001',
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(byUser.data[0]).toEqual(expect.objectContaining({ id: 'AUD0000001' }));

    auditLogRepository.findMany.mockResolvedValue([rawAuditLog]);
    auditLogRepository.count.mockResolvedValue(1);
    const byEntity = await auditLogService.getAuditLogsByEntity(
      'patient',
      'PAT0000001',
      1,
      20,
      'created_at',
      'desc',
      scopedUser
    );
    expect(auditLogRepository.findMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        tenant_id: scopedUser.tenant_id,
        entity: 'patient',
        entity_id: 'PAT0000001',
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(byEntity.data[0]).toEqual(expect.objectContaining({ id: 'AUD0000001' }));
  });
});
