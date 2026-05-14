const {
  auditLogIdParamsSchema,
  userIdParamsSchema,
  entityParamsSchema,
  listAuditLogsQuerySchema,
} = require('@modules/audit-log/schemas/audit-log.schema');

describe('Audit Log Schemas', () => {
  it('accepts UUIDs and friendly identifiers for route params', () => {
    expect(
      auditLogIdParamsSchema.safeParse({ id: '123e4567-e89b-12d3-a456-426614174000' }).success
    ).toBe(true);
    expect(auditLogIdParamsSchema.safeParse({ id: 'AUD0000001' }).success).toBe(true);
    expect(userIdParamsSchema.safeParse({ userId: 'USR0000001' }).success).toBe(true);
  });

  it('accepts friendly entity references up to 64 characters', () => {
    expect(
      entityParamsSchema.safeParse({
        entity: 'patient',
        entityId: 'PAT0000001',
      }).success
    ).toBe(true);
    expect(
      entityParamsSchema.safeParse({
        entity: 'patient',
        entityId: 'x'.repeat(65),
      }).success
    ).toBe(false);
  });

  it('validates the supported list query filters', () => {
    const result = listAuditLogsQuerySchema.safeParse({
      tenant_id: 'TEN0000001',
      user_id: 'USR0000001',
      action: 'CREATE',
      entity: 'patient',
      entity_id: 'PAT0000001',
      ip_address: '192.168.1.1',
      search: 'john',
      date_from: '2026-01-01T00:00:00.000Z',
      date_to: '2026-01-31T23:59:59.999Z',
      page: '1',
      limit: '20',
      sort_by: 'created_at',
      order: 'desc',
    });

    expect(result.success).toBe(true);
  });

  it('rejects invalid action enums and invalid datetime strings', () => {
    expect(
      listAuditLogsQuerySchema.safeParse({ action: 'APPROVE' }).success
    ).toBe(false);
    expect(
      listAuditLogsQuerySchema.safeParse({ date_from: '2026-01-01' }).success
    ).toBe(false);
  });
});
