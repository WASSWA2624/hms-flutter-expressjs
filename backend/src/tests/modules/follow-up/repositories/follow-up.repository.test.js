/**
 * Follow-up repository tests
 *
 * @module tests/modules/follow-up/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  follow_up: {
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
} = require('@repositories/follow-up/follow-up.repository');

const prisma = require('@prisma/client');

describe('Follow-up Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find follow-up by ID', async () => {
      const mockFollowUp = {
        id: 'followup-123',
        encounter_id: 'encounter-123',
        scheduled_at: new Date('2026-01-25'),
        notes: 'Follow-up appointment',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.follow_up.findFirst.mockResolvedValue(mockFollowUp);

      const result = await findById('followup-123');

      expect(result).toEqual(mockFollowUp);
      expect(prisma.follow_up.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'followup-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if follow-up not found', async () => {
      prisma.follow_up.findFirst.mockResolvedValue(null);

      const result = await findById('followup-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.follow_up.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('followup-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many follow-ups with default pagination', async () => {
      const mockFollowUps = [
        { id: 'followup-1', scheduled_at: new Date('2026-01-25') },
        { id: 'followup-2', scheduled_at: new Date('2026-01-26') }
      ];
      prisma.follow_up.findMany.mockResolvedValue(mockFollowUps);

      const result = await findMany();

      expect(result).toEqual(mockFollowUps);
      expect(prisma.follow_up.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      prisma.follow_up.findMany.mockResolvedValue([]);

      await findMany({ encounter_id: 'encounter-123' });

      expect(prisma.follow_up.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          encounter_id: 'encounter-123'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.follow_up.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count follow-ups', async () => {
      prisma.follow_up.count.mockResolvedValue(15);

      const result = await count();

      expect(result).toBe(15);
      expect(prisma.follow_up.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters', async () => {
      prisma.follow_up.count.mockResolvedValue(3);

      await count({ encounter_id: 'encounter-123' });

      expect(prisma.follow_up.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          encounter_id: 'encounter-123'
        }
      });
    });
  });

  describe('create', () => {
    it('should create follow-up', async () => {
      const data = {
        encounter_id: 'encounter-123',
        scheduled_at: new Date('2026-01-25'),
        notes: 'Test notes'
      };
      const mockFollowUp = { id: 'followup-123', ...data };
      prisma.follow_up.create.mockResolvedValue(mockFollowUp);

      const result = await create(data);

      expect(result).toEqual(mockFollowUp);
      expect(prisma.follow_up.create).toHaveBeenCalledWith({ data });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      prisma.follow_up.create.mockRejectedValue({
        code: 'P2002',
        meta: { target: ['encounter_id'] }
      });

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      prisma.follow_up.create.mockRejectedValue({
        code: 'P2003',
        meta: { field_name: 'encounter_id' }
      });

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update follow-up', async () => {
      const data = { notes: 'Updated notes' };
      const mockFollowUp = { id: 'followup-123', ...data };
      prisma.follow_up.update.mockResolvedValue(mockFollowUp);

      const result = await update('followup-123', data);

      expect(result).toEqual(mockFollowUp);
      expect(prisma.follow_up.update).toHaveBeenCalledWith({
        where: { id: 'followup-123' },
        data
      });
    });

    it('should throw HttpError if follow-up not found', async () => {
      prisma.follow_up.update.mockRejectedValue({ code: 'P2025' });

      await expect(update('followup-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete follow-up', async () => {
      const mockFollowUp = { id: 'followup-123', deleted_at: new Date() };
      prisma.follow_up.update.mockResolvedValue(mockFollowUp);

      const result = await softDelete('followup-123');

      expect(result).toEqual(mockFollowUp);
      expect(prisma.follow_up.update).toHaveBeenCalledWith({
        where: { id: 'followup-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if follow-up not found', async () => {
      prisma.follow_up.update.mockRejectedValue({ code: 'P2025' });

      await expect(softDelete('followup-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
