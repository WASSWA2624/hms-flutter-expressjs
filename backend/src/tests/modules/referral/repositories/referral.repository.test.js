/**
 * Referral repository tests
 *
 * @module tests/modules/referral/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  referral: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/referral/referral.repository');

const prisma = require('@prisma/client');

describe('Referral Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find referral by ID', async () => {
      const mockReferral = {
        id: 'referral-123',
        encounter_id: 'encounter-123',
        from_department_id: 'dept-123',
        to_department_id: 'dept-456',
        reason: 'Specialist consultation',
        status: 'PENDING',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.referral.findFirst.mockResolvedValue(mockReferral);

      const result = await findById('referral-123');

      expect(result).toEqual(mockReferral);
      expect(prisma.referral.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'referral-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if referral not found', async () => {
      prisma.referral.findFirst.mockResolvedValue(null);

      const result = await findById('referral-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.referral.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('referral-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many referrals with default pagination', async () => {
      const mockReferrals = [
        { id: 'referral-1', status: 'REQUESTED' },
        { id: 'referral-2', status: 'APPROVED' }
      ];
      prisma.referral.findMany.mockResolvedValue(mockReferrals);

      const result = await findMany();

      expect(result).toEqual(mockReferrals);
      expect(prisma.referral.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      prisma.referral.findMany.mockResolvedValue([]);

      await findMany({ encounter_id: 'encounter-123', status: 'PENDING' });

      expect(prisma.referral.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          encounter_id: 'encounter-123',
          status: 'PENDING'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.referral.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count referrals', async () => {
      prisma.referral.count.mockResolvedValue(42);

      const result = await count();

      expect(result).toBe(42);
      expect(prisma.referral.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters', async () => {
      prisma.referral.count.mockResolvedValue(5);

      await count({ status: 'REQUESTED' });

      expect(prisma.referral.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'REQUESTED'
        }
      });
    });
  });

  describe('create', () => {
    it('should create referral', async () => {
      const data = {
        encounter_id: 'encounter-123',
        status: 'REQUESTED',
        reason: 'Test reason'
      };
      const mockReferral = { id: 'referral-123', ...data };
      prisma.referral.create.mockResolvedValue(mockReferral);

      const result = await create(data);

      expect(result).toEqual(mockReferral);
      expect(prisma.referral.create).toHaveBeenCalledWith({ data });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      prisma.referral.create.mockRejectedValue({
        code: 'P2002',
        meta: { target: ['encounter_id'] }
      });

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      prisma.referral.create.mockRejectedValue({
        code: 'P2003',
        meta: { field_name: 'encounter_id' }
      });

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update referral', async () => {
      const data = { status: 'APPROVED' };
      const mockReferral = { id: 'referral-123', ...data };
      prisma.referral.update.mockResolvedValue(mockReferral);

      const result = await update('referral-123', data);

      expect(result).toEqual(mockReferral);
      expect(prisma.referral.update).toHaveBeenCalledWith({
        where: { id: 'referral-123' },
        data
      });
    });

    it('should throw HttpError if referral not found', async () => {
      prisma.referral.update.mockRejectedValue({ code: 'P2025' });

      await expect(update('referral-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete referral', async () => {
      const mockReferral = { id: 'referral-123', deleted_at: new Date() };
      prisma.referral.update.mockResolvedValue(mockReferral);

      const result = await softDelete('referral-123');

      expect(result).toEqual(mockReferral);
      expect(prisma.referral.update).toHaveBeenCalledWith({
        where: { id: 'referral-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if referral not found', async () => {
      prisma.referral.update.mockRejectedValue({ code: 'P2025' });

      await expect(softDelete('referral-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
