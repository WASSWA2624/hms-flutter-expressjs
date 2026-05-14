/**
 * Pre-authorization repository tests
 *
 * @module tests/modules/pre-authorization/repositories
 * @description Tests for pre-authorization repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const preAuthorizationRepository = require('@repositories/pre-authorization/pre-authorization.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  pre_authorization: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Pre-Authorization Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find pre-authorization by id', async () => {
      const mockAuth = { id: '123', coverage_plan_id: '456', status: 'PENDING' };
      prisma.pre_authorization.findFirst.mockResolvedValue(mockAuth);

      const result = await preAuthorizationRepository.findById('123');
      expect(result).toEqual(mockAuth);
      expect(prisma.pre_authorization.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if pre-authorization not found', async () => {
      prisma.pre_authorization.findFirst.mockResolvedValue(null);

      const result = await preAuthorizationRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.pre_authorization.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(preAuthorizationRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many pre-authorizations with pagination', async () => {
      const mockAuths = [
        { id: '1', status: 'PENDING' },
        { id: '2', status: 'APPROVED' }
      ];
      prisma.pre_authorization.findMany.mockResolvedValue(mockAuths);

      const result = await preAuthorizationRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockAuths);
      expect(prisma.pre_authorization.findMany).toHaveBeenCalled();
    });

    it('should throw HttpError on database error', async () => {
      prisma.pre_authorization.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(preAuthorizationRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count pre-authorizations', async () => {
      prisma.pre_authorization.count.mockResolvedValue(42);

      const result = await preAuthorizationRepository.count({});
      expect(result).toBe(42);
    });

    it('should throw HttpError on database error', async () => {
      prisma.pre_authorization.count.mockRejectedValue(new Error('DB Error'));

      await expect(preAuthorizationRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create pre-authorization', async () => {
      const mockData = { coverage_plan_id: '123', status: 'PENDING' };
      const mockAuth = { id: '789', ...mockData };
      prisma.pre_authorization.create.mockResolvedValue(mockAuth);

      const result = await preAuthorizationRepository.create(mockData);
      expect(result).toEqual(mockAuth);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'coverage_plan_id' };
      prisma.pre_authorization.create.mockRejectedValue(error);

      await expect(preAuthorizationRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update pre-authorization', async () => {
      const mockAuth = { id: '123', status: 'APPROVED' };
      prisma.pre_authorization.update.mockResolvedValue(mockAuth);

      const result = await preAuthorizationRepository.update('123', { status: 'APPROVED' });
      expect(result).toEqual(mockAuth);
    });

    it('should throw HttpError if pre-authorization not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.pre_authorization.update.mockRejectedValue(error);

      await expect(preAuthorizationRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete pre-authorization', async () => {
      const mockAuth = { id: '123', deleted_at: new Date() };
      prisma.pre_authorization.update.mockResolvedValue(mockAuth);

      const result = await preAuthorizationRepository.softDelete('123');
      expect(result).toEqual(mockAuth);
    });

    it('should throw HttpError if pre-authorization not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.pre_authorization.update.mockRejectedValue(error);

      await expect(preAuthorizationRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });
  });
});
