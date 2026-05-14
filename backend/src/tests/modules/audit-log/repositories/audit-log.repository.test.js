/**
 * Audit log repository tests
 *
 * @module tests/modules/audit-log/repositories
 * @description Tests for audit log repository layer
 */

const auditLogRepository = require('@modules/audit-log/repositories/audit-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  audit_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn()
  }
}));

describe('Audit Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockAuditLog = {
      id: mockId,
      tenant_id: '123e4567-e89b-12d3-a456-426614174001',
      user_id: '123e4567-e89b-12d3-a456-426614174002',
      action: 'CREATE',
      entity: 'user',
      entity_id: '123e4567-e89b-12d3-a456-426614174003',
      ip_address: '192.168.1.1',
      created_at: new Date(),
      deleted_at: null
    };

    it('should find audit log by ID', async () => {
      prisma.audit_log.findFirst.mockResolvedValue(mockAuditLog);

      const result = await auditLogRepository.findById(mockId);

      expect(prisma.audit_log.findFirst).toHaveBeenCalledWith({
        where: { id: mockId, deleted_at: null },
        include: {}
      });
      expect(result).toEqual(mockAuditLog);
    });

    it('should return null if audit log not found', async () => {
      prisma.audit_log.findFirst.mockResolvedValue(null);

      const result = await auditLogRepository.findById(mockId);

      expect(result).toBeNull();
    });

    it('should include relations when specified', async () => {
      const include = { tenant: true, user: true };
      prisma.audit_log.findFirst.mockResolvedValue(mockAuditLog);

      await auditLogRepository.findById(mockId, include);

      expect(prisma.audit_log.findFirst).toHaveBeenCalledWith({
        where: { id: mockId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Database connection failed');
      prisma.audit_log.findFirst.mockRejectedValue(dbError);

      await expect(auditLogRepository.findById(mockId))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    const mockAuditLogs = [
      {
        id: '123e4567-e89b-12d3-a456-426614174000',
        action: 'CREATE',
        entity: 'user',
        deleted_at: null
      },
      {
        id: '123e4567-e89b-12d3-a456-426614174001',
        action: 'UPDATE',
        entity: 'patient',
        deleted_at: null
      }
    ];

    it('should find many audit logs with default params', async () => {
      prisma.audit_log.findMany.mockResolvedValue(mockAuditLogs);

      const result = await auditLogRepository.findMany();

      expect(prisma.audit_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
      expect(result).toEqual(mockAuditLogs);
    });

    it('should find many audit logs with filters', async () => {
      const filters = { action: 'CREATE', entity: 'user' };
      prisma.audit_log.findMany.mockResolvedValue(mockAuditLogs);

      await auditLogRepository.findMany(filters, 0, 10, { created_at: 'asc' });

      expect(prisma.audit_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'asc' },
        include: {}
      });
    });

    it('should handle pagination', async () => {
      prisma.audit_log.findMany.mockResolvedValue(mockAuditLogs);

      await auditLogRepository.findMany({}, 20, 10);

      expect(prisma.audit_log.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Database query failed');
      prisma.audit_log.findMany.mockRejectedValue(dbError);

      await expect(auditLogRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count audit logs with no filters', async () => {
      prisma.audit_log.count.mockResolvedValue(100);

      const result = await auditLogRepository.count();

      expect(prisma.audit_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
      expect(result).toBe(100);
    });

    it('should count audit logs with filters', async () => {
      const filters = { action: 'DELETE', entity: 'patient' };
      prisma.audit_log.count.mockResolvedValue(5);

      const result = await auditLogRepository.count(filters);

      expect(prisma.audit_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
      expect(result).toBe(5);
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Count query failed');
      prisma.audit_log.count.mockRejectedValue(dbError);

      await expect(auditLogRepository.count())
        .rejects.toThrow(HttpError);
    });
  });
});
