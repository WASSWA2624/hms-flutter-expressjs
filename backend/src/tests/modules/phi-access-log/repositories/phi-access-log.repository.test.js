/**
 * PHI access log repository tests
 *
 * @module tests/modules/phi-access-log/repositories
 * @description Tests for PHI access log repository layer
 */

const phiAccessLogRepository = require('@modules/phi-access-log/repositories/phi-access-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  phi_access_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('PHI Access Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockPhiAccessLog = {
      id: mockId,
      tenant_id: '123e4567-e89b-12d3-a456-426614174001',
      user_id: '123e4567-e89b-12d3-a456-426614174002',
      patient_id: '123e4567-e89b-12d3-a456-426614174003',
      access_scope: 'PATIENT',
      accessed_at: new Date(),
      deleted_at: null
    };

    it('should find PHI access log by ID', async () => {
      prisma.phi_access_log.findFirst.mockResolvedValue(mockPhiAccessLog);

      const result = await phiAccessLogRepository.findById(mockId);

      expect(prisma.phi_access_log.findFirst).toHaveBeenCalledWith({
        where: { id: mockId, deleted_at: null },
        include: {}
      });
      expect(result).toEqual(mockPhiAccessLog);
    });

    it('should return null if PHI access log not found', async () => {
      prisma.phi_access_log.findFirst.mockResolvedValue(null);

      const result = await phiAccessLogRepository.findById(mockId);

      expect(result).toBeNull();
    });

    it('should include relations when specified', async () => {
      const include = { tenant: true, user: true, patient: true };
      prisma.phi_access_log.findFirst.mockResolvedValue(mockPhiAccessLog);

      await phiAccessLogRepository.findById(mockId, include);

      expect(prisma.phi_access_log.findFirst).toHaveBeenCalledWith({
        where: { id: mockId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Database connection failed');
      prisma.phi_access_log.findFirst.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.findById(mockId))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    const mockPhiAccessLogs = [
      {
        id: '123e4567-e89b-12d3-a456-426614174000',
        access_scope: 'PATIENT',
        deleted_at: null
      },
      {
        id: '123e4567-e89b-12d3-a456-426614174001',
        access_scope: 'FACILITY',
        deleted_at: null
      }
    ];

    it('should find many PHI access logs with default params', async () => {
      prisma.phi_access_log.findMany.mockResolvedValue(mockPhiAccessLogs);

      const result = await phiAccessLogRepository.findMany();

      expect(prisma.phi_access_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { accessed_at: 'desc' },
        include: {}
      });
      expect(result).toEqual(mockPhiAccessLogs);
    });

    it('should find many PHI access logs with filters', async () => {
      const filters = { access_scope: 'PATIENT', user_id: '123e4567-e89b-12d3-a456-426614174000' };
      prisma.phi_access_log.findMany.mockResolvedValue(mockPhiAccessLogs);

      await phiAccessLogRepository.findMany(filters, 0, 10, { accessed_at: 'asc' });

      expect(prisma.phi_access_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 10,
        orderBy: { accessed_at: 'asc' },
        include: {}
      });
    });

    it('should handle pagination', async () => {
      prisma.phi_access_log.findMany.mockResolvedValue(mockPhiAccessLogs);

      await phiAccessLogRepository.findMany({}, 20, 10);

      expect(prisma.phi_access_log.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Database query failed');
      prisma.phi_access_log.findMany.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count PHI access logs with no filters', async () => {
      prisma.phi_access_log.count.mockResolvedValue(100);

      const result = await phiAccessLogRepository.count();

      expect(prisma.phi_access_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
      expect(result).toBe(100);
    });

    it('should count PHI access logs with filters', async () => {
      const filters = { access_scope: 'PATIENT' };
      prisma.phi_access_log.count.mockResolvedValue(50);

      const result = await phiAccessLogRepository.count(filters);

      expect(prisma.phi_access_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
      expect(result).toBe(50);
    });

    it('should throw HttpError on database error', async () => {
      const dbError = new Error('Count query failed');
      prisma.phi_access_log.count.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const mockData = {
      tenant_id: '123e4567-e89b-12d3-a456-426614174000',
      user_id: '123e4567-e89b-12d3-a456-426614174001',
      patient_id: '123e4567-e89b-12d3-a456-426614174002',
      access_scope: 'PATIENT'
    };

    const mockCreated = { id: '123e4567-e89b-12d3-a456-426614174003', ...mockData };

    it('should create PHI access log', async () => {
      prisma.phi_access_log.create.mockResolvedValue(mockCreated);

      const result = await phiAccessLogRepository.create(mockData);

      expect(prisma.phi_access_log.create).toHaveBeenCalledWith({
        data: mockData
      });
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const dbError = new Error('Unique constraint');
      dbError.code = 'P2002';
      dbError.meta = { target: ['field'] };
      prisma.phi_access_log.create.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.create(mockData))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const dbError = new Error('Foreign key violation');
      dbError.code = 'P2003';
      dbError.meta = { field_name: 'patient_id' };
      prisma.phi_access_log.create.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.create(mockData))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockData = { access_scope: 'FACILITY' };
    const mockUpdated = { id: mockId, ...mockData };

    it('should update PHI access log', async () => {
      prisma.phi_access_log.update.mockResolvedValue(mockUpdated);

      const result = await phiAccessLogRepository.update(mockId, mockData);

      expect(prisma.phi_access_log.update).toHaveBeenCalledWith({
        where: { id: mockId },
        data: mockData
      });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if PHI access log not found', async () => {
      const dbError = new Error('Not found');
      dbError.code = 'P2025';
      prisma.phi_access_log.update.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.update(mockId, mockData))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockDeleted = { id: mockId, deleted_at: new Date() };

    it('should soft delete PHI access log', async () => {
      prisma.phi_access_log.update.mockResolvedValue(mockDeleted);

      const result = await phiAccessLogRepository.softDelete(mockId);

      expect(prisma.phi_access_log.update).toHaveBeenCalledWith({
        where: { id: mockId },
        data: { deleted_at: expect.any(Date) }
      });
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if PHI access log not found', async () => {
      const dbError = new Error('Not found');
      dbError.code = 'P2025';
      prisma.phi_access_log.update.mockRejectedValue(dbError);

      await expect(phiAccessLogRepository.softDelete(mockId))
        .rejects.toThrow(HttpError);
    });
  });
});
