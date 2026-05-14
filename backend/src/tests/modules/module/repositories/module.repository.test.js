/**
 * Module repository tests
 *
 * @module tests/modules/module/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  module: {
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
} = require('@repositories/module/module.repository');

const prisma = require('@prisma/client');

describe('Module Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find module by ID', async () => {
      const mockModule = {
        id: 'module-123',
        name: 'Test Module',
        description: 'Test description',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.module.findFirst.mockResolvedValue(mockModule);

      const result = await findById('module-123');

      expect(result).toEqual(mockModule);
      expect(prisma.module.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'module-123',
          deleted_at: null
        }
      });
    });

    it('should return null if module not found', async () => {
      prisma.module.findFirst.mockResolvedValue(null);

      const result = await findById('module-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.module.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('module-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many modules with default pagination', async () => {
      const mockModules = [
        {
          id: 'module-1',
          name: 'Module A',
          description: 'Description A'
        },
        {
          id: 'module-2',
          name: 'Module B',
          description: 'Description B'
        }
      ];
      prisma.module.findMany.mockResolvedValue(mockModules);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockModules);
      expect(prisma.module.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find modules with filters', async () => {
      const mockModules = [
        {
          id: 'module-1',
          name: 'Module A',
          description: 'Description A'
        }
      ];
      prisma.module.findMany.mockResolvedValue(mockModules);

      const result = await findMany({ name: { contains: 'Module A' } }, 0, 10);

      expect(result).toEqual(mockModules);
      expect(prisma.module.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          name: { contains: 'Module A' }
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find modules with custom sort order', async () => {
      const mockModules = [];
      prisma.module.findMany.mockResolvedValue(mockModules);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.module.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.module.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count modules without filters', async () => {
      prisma.module.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.module.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count modules with filters', async () => {
      prisma.module.count.mockResolvedValue(5);

      const result = await count({ name: { contains: 'Test' } });

      expect(result).toBe(5);
      expect(prisma.module.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          name: { contains: 'Test' }
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.module.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new module', async () => {
      const moduleData = {
        name: 'New Module',
        description: 'New description'
      };
      const mockCreatedModule = {
        id: 'module-new',
        ...moduleData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.module.create.mockResolvedValue(mockCreatedModule);

      const result = await create(moduleData);

      expect(result).toEqual(mockCreatedModule);
      expect(prisma.module.create).toHaveBeenCalledWith({
        data: moduleData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const moduleData = {
        name: 'Duplicate Module',
        description: 'Test'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.module.create.mockRejectedValue(error);

      await expect(create(moduleData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.module.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ name: 'Test' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a module', async () => {
      const updateData = {
        name: 'Updated Module',
        description: 'Updated description'
      };
      const mockUpdatedModule = {
        id: 'module-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.module.update.mockResolvedValue(mockUpdatedModule);

      const result = await update('module-123', updateData);

      expect(result).toEqual(mockUpdatedModule);
      expect(prisma.module.update).toHaveBeenCalledWith({
        where: { id: 'module-123' },
        data: updateData
      });
    });

    it('should throw HttpError when module not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.module.update.mockRejectedValue(error);

      await expect(update('module-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.module.update.mockRejectedValue(error);

      await expect(update('module-123', { name: 'duplicate-name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.module.update.mockRejectedValue(new Error('DB error'));

      await expect(update('module-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a module', async () => {
      const mockDeletedModule = {
        id: 'module-123',
        name: 'Test Module',
        description: 'Test description',
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.module.update.mockResolvedValue(mockDeletedModule);

      const result = await softDelete('module-123');

      expect(result).toEqual(mockDeletedModule);
      expect(prisma.module.update).toHaveBeenCalledWith({
        where: { id: 'module-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when module not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.module.update.mockRejectedValue(error);

      await expect(softDelete('module-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.module.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('module-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
