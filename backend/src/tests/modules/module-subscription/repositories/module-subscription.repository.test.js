/**
 * Module subscription repository tests
 *
 * @module tests/modules/module-subscription/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  module_subscription: {
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
} = require('@repositories/module-subscription/module-subscription.repository');

const prisma = require('@prisma/client');

describe('Module Subscription Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find module subscription by ID with relations', async () => {
      const mockModuleSubscription = {
        id: 'sub-123',
        module_id: 'module-123',
        subscription_id: 'subscription-123',
        is_active: true,
        deleted_at: null,
        module: { id: 'module-123', name: 'Test Module' },
        subscription: { id: 'subscription-123' }
      };
      prisma.module_subscription.findFirst.mockResolvedValue(mockModuleSubscription);

      const result = await findById('sub-123');

      expect(result).toEqual(mockModuleSubscription);
      expect(prisma.module_subscription.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'sub-123',
          deleted_at: null
        },
        include: {
          module: true,
          subscription: {
            include: {
              plan: true
            }
          }
        }
      });
    });

    it('should return null if not found', async () => {
      prisma.module_subscription.findFirst.mockResolvedValue(null);

      const result = await findById('sub-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.module_subscription.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('sub-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create module subscription with relations', async () => {
      const data = {
        module_id: 'module-123',
        subscription_id: 'subscription-123',
        is_active: true
      };
      const mockCreated = {
        id: 'sub-new',
        ...data,
        module: { id: 'module-123', name: 'Test Module' },
        subscription: { id: 'subscription-123' }
      };
      prisma.module_subscription.create.mockResolvedValue(mockCreated);

      const result = await create(data);

      expect(result).toEqual(mockCreated);
      expect(prisma.module_subscription.create).toHaveBeenCalledWith({
        data,
        include: {
          module: true,
          subscription: {
            include: {
              plan: true
            }
          }
        }
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['module_id', 'subscription_id'] };
      prisma.module_subscription.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      prisma.module_subscription.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update module subscription', async () => {
      const updateData = { is_active: false };
      const mockUpdated = {
        id: 'sub-123',
        is_active: false,
        module: { id: 'module-123', name: 'Test Module' },
        subscription: { id: 'subscription-123' }
      };
      prisma.module_subscription.update.mockResolvedValue(mockUpdated);

      const result = await update('sub-123', updateData);

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.module_subscription.update.mockRejectedValue(error);

      await expect(update('sub-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete module subscription', async () => {
      const mockDeleted = {
        id: 'sub-123',
        deleted_at: new Date()
      };
      prisma.module_subscription.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('sub-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.module_subscription.update).toHaveBeenCalledWith({
        where: { id: 'sub-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.module_subscription.update.mockRejectedValue(error);

      await expect(softDelete('sub-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
