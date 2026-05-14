/**
 * createAuditLog helper tests
 */

jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    error: jest.fn(),
    info: jest.fn(),
  },
}));

const prisma = require('@prisma/client');
const { logger } = require('@lib/logging');
const { createAuditLog } = require('@lib/audit/createAuditLog');

const flushImmediate = () =>
  new Promise((resolve) => {
    setImmediate(resolve);
  });

describe('createAuditLog helper', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.audit_log.create.mockReset();
    if (!prisma.user) prisma.user = {};
    prisma.user.findUnique = jest.fn();
  });

  it('returns early when required fields are missing', async () => {
    await createAuditLog({ action: 'CREATE' });

    expect(logger.warn).toHaveBeenCalledWith(
      'Invalid audit log data: missing required fields',
      expect.any(Object)
    );
    expect(prisma.audit_log.create).not.toHaveBeenCalled();
  });

  it('persists a valid audit log asynchronously', async () => {
    prisma.audit_log.create.mockResolvedValue({ id: 'audit-1' });

    await createAuditLog({
      tenant_id: 'tenant-1',
      user_id: 'user-1',
      action: 'CREATE',
      entity: 'invoice',
      entity_id: 'inv-1',
      diff: { after: { id: 'inv-1' } },
      ip_address: '127.0.0.1',
    });

    await flushImmediate();

    expect(prisma.audit_log.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        tenant_id: 'tenant-1',
        user_id: 'user-1',
        action: 'CREATE',
        entity: 'invoice',
        entity_id: 'inv-1',
        diff_json: { after: { id: 'inv-1' } },
        ip_address: '127.0.0.1',
      }),
    });
  });

  it('infers tenant_id from diff payload when not provided explicitly', async () => {
    prisma.audit_log.create.mockResolvedValue({ id: 'audit-tenant-from-diff' });

    await createAuditLog({
      user_id: 'user-1',
      action: 'UPDATE',
      entity: 'user_profile',
      entity_id: 'profile-1',
      diff: {
        before: { id: 'profile-1', tenant_id: 'tenant-from-diff' },
        after: { id: 'profile-1', tenant_id: 'tenant-from-diff' }
      }
    });

    await flushImmediate();

    expect(prisma.audit_log.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        tenant_id: 'tenant-from-diff'
      })
    });
  });

  it('skips audit write when tenant_id is a placeholder value', async () => {
    await createAuditLog({
      tenant_id: 'unknown',
      action: 'ACCESS',
      entity: 'authorization',
      entity_id: '/api/v1/auth/login',
      user_id: null,
    });

    await flushImmediate();

    expect(prisma.audit_log.create).not.toHaveBeenCalled();
    expect(logger.warn).toHaveBeenCalledWith(
      'Invalid audit log data: missing tenant_id',
      expect.objectContaining({
        action: 'ACCESS',
        entity: 'authorization',
        entity_id: '/api/v1/auth/login',
      })
    );
  });

  it('infers tenant_id from user_id when payload does not include tenant_id', async () => {
    prisma.audit_log.create.mockResolvedValue({ id: 'audit-tenant-from-user' });
    prisma.user.findUnique.mockResolvedValue({ tenant_id: 'tenant-from-user' });

    await createAuditLog({
      user_id: 'user-2',
      action: 'CREATE',
      entity: 'appointment',
      entity_id: 'apt-1'
    });

    await flushImmediate();

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { id: 'user-2' },
      select: { tenant_id: true }
    });
    expect(prisma.audit_log.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        tenant_id: 'tenant-from-user'
      })
    });
  });

  it('maps unknown actions to ACCESS and preserves original action', async () => {
    prisma.audit_log.create.mockResolvedValue({ id: 'audit-2' });

    await createAuditLog({
      tenant_id: 'tenant-1',
      action: 'publish_shift',
      entity: 'shift',
      entity_id: 'shift-1',
      diff: 'payload',
      ip: '10.0.0.1',
    });

    await flushImmediate();

    expect(prisma.audit_log.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: 'ACCESS',
        diff_json: {
          details: 'payload',
          original_action: 'PUBLISH_SHIFT',
        },
        ip_address: '10.0.0.1',
      }),
    });
  });

  it('maps workflow mutation actions to UPDATE and preserves the original action', async () => {
    prisma.audit_log.create.mockResolvedValue({ id: 'audit-3' });

    await createAuditLog({
      tenant_id: 'tenant-1',
      action: 'discharge',
      entity: 'admission',
      entity_id: 'adm-1',
      diff: { after: { id: 'adm-1', status: 'DISCHARGED' } },
    });

    await flushImmediate();

    expect(prisma.audit_log.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: 'UPDATE',
        diff_json: {
          after: { id: 'adm-1', status: 'DISCHARGED' },
          original_action: 'DISCHARGE',
        },
      }),
    });
  });

  it('logs persistence failures but does not throw', async () => {
    prisma.audit_log.create.mockRejectedValue(new Error('db failure'));

    await createAuditLog({
      tenant_id: 'tenant-1',
      action: 'UPDATE',
      entity: 'patient',
      entity_id: 'patient-1',
    });

    await flushImmediate();

    expect(logger.error).toHaveBeenCalledWith(
      'Failed to create audit log entry',
      expect.objectContaining({ error: 'db failure' })
    );
  });

  it('logs scheduling failures when setImmediate errors', async () => {
    const setImmediateSpy = jest
      .spyOn(global, 'setImmediate')
      .mockImplementation(() => {
        throw new Error('schedule failure');
      });

    await createAuditLog({
      tenant_id: 'tenant-1',
      action: 'DELETE',
      entity: 'user',
      entity_id: 'user-1',
    });

    expect(logger.error).toHaveBeenCalledWith(
      'Failed to schedule audit log creation',
      expect.objectContaining({ error: 'schedule failure' })
    );

    setImmediateSpy.mockRestore();
  });

  it('warns and skips when prisma client is unavailable', async () => {
    jest.resetModules();

    const warnMock = jest.fn();
    jest.doMock('@lib/logging', () => ({
      logger: {
        warn: warnMock,
        error: jest.fn(),
        info: jest.fn(),
      },
    }));
    jest.doMock('@prisma/client', () => {
      throw new Error('missing prisma');
    });

    let isolatedCreateAuditLog;
    jest.isolateModules(() => {
      ({ createAuditLog: isolatedCreateAuditLog } = require('@lib/audit/createAuditLog'));
    });

    await isolatedCreateAuditLog({
      tenant_id: 'tenant-1',
      action: 'CREATE',
      entity: 'user',
      entity_id: 'user-1',
    });

    expect(warnMock).toHaveBeenCalledWith(
      'Prisma client not available, skipping audit log creation',
      expect.objectContaining({
        action: 'CREATE',
        entity: 'user',
        entity_id: 'user-1',
      })
    );
  });
});
