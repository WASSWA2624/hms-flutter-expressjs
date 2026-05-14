/**
 * Ambulance Dispatch repository tests
 *
 * @module tests/modules/ambulance-dispatch/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  ambulance_dispatch: {
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
} = require('@repositories/ambulance-dispatch/ambulance-dispatch.repository');

const prisma = require('@prisma/client');

describe('Ambulance Dispatch Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ambulance dispatch by ID', async () => {
      const mockDispatch = {
        id: 'dispatch-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        status: 'DISPATCHED',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null
      };
      prisma.ambulance_dispatch.findFirst.mockResolvedValue(mockDispatch);

      const result = await findById('dispatch-123');

      expect(result).toEqual(mockDispatch);
      expect(prisma.ambulance_dispatch.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'dispatch-123',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });

    it('should return null if dispatch not found', async () => {
      prisma.ambulance_dispatch.findFirst.mockResolvedValue(null);

      const result = await findById('dispatch-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.ambulance_dispatch.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('dispatch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many dispatches with default pagination', async () => {
      const mockDispatches = [
        { id: 'dispatch-1', ambulance_id: 'ambulance-1', status: 'DISPATCHED' },
        { id: 'dispatch-2', ambulance_id: 'ambulance-2', status: 'EN_ROUTE' }
      ];
      prisma.ambulance_dispatch.findMany.mockResolvedValue(mockDispatches);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockDispatches);
    });
  });

  describe('count', () => {
    it('should count dispatches', async () => {
      prisma.ambulance_dispatch.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create dispatch', async () => {
      const mockDispatch = {
        id: 'dispatch-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        status: 'DISPATCHED'
      };
      prisma.ambulance_dispatch.create.mockResolvedValue(mockDispatch);

      const result = await create(mockDispatch);

      expect(result).toEqual(mockDispatch);
    });
  });

  describe('update', () => {
    it('should update dispatch', async () => {
      const mockDispatch = {
        id: 'dispatch-123',
        status: 'ON_SCENE'
      };
      prisma.ambulance_dispatch.update.mockResolvedValue(mockDispatch);

      const result = await update('dispatch-123', { status: 'ON_SCENE' });

      expect(result).toEqual(mockDispatch);
    });
  });

  describe('softDelete', () => {
    it('should soft delete dispatch', async () => {
      const mockDispatch = {
        id: 'dispatch-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.ambulance_dispatch.update.mockResolvedValue(mockDispatch);

      const result = await softDelete('dispatch-123');

      expect(result).toEqual(mockDispatch);
    });
  });
});
