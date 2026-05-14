/**
 * Branch repository tests
 *
 * @module tests/modules/branch/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  branch: {
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
} = require('@repositories/branch/branch.repository');

const prisma = require('@prisma/client');

describe('Branch Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find branch by ID', async () => {
      const mockBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.branch.findFirst.mockResolvedValue(mockBranch);

      const result = await findById('branch-123');

      expect(result).toEqual(mockBranch);
      expect(prisma.branch.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'branch-123',
          deleted_at: null
        }
      });
    });

    it('should return null if branch not found', async () => {
      prisma.branch.findFirst.mockResolvedValue(null);

      const result = await findById('branch-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.branch.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('branch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many branches with default pagination', async () => {
      const mockBranches = [
        {
          id: 'branch-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          name: 'Branch A',
          is_active: true
        },
        {
          id: 'branch-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          name: 'Branch B',
          is_active: true
        }
      ];
      prisma.branch.findMany.mockResolvedValue(mockBranches);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockBranches);
      expect(prisma.branch.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find branches with filters', async () => {
      const mockBranches = [
        {
          id: 'branch-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          name: 'Branch A',
          is_active: true
        }
      ];
      prisma.branch.findMany.mockResolvedValue(mockBranches);

      const result = await findMany({ tenant_id: 'tenant-123', is_active: true }, 0, 10);

      expect(result).toEqual(mockBranches);
      expect(prisma.branch.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          is_active: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find branches with custom sort order', async () => {
      const mockBranches = [];
      prisma.branch.findMany.mockResolvedValue(mockBranches);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.branch.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.branch.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count branches without filters', async () => {
      prisma.branch.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.branch.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count branches with filters', async () => {
      prisma.branch.count.mockResolvedValue(5);

      const result = await count({ tenant_id: 'tenant-123', is_active: true });

      expect(result).toBe(5);
      expect(prisma.branch.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          is_active: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.branch.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new branch', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Branch',
        is_active: true
      };
      const mockCreatedBranch = {
        id: 'branch-new',
        ...branchData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.branch.create.mockResolvedValue(mockCreatedBranch);

      const result = await create(branchData);

      expect(result).toEqual(mockCreatedBranch);
      expect(prisma.branch.create).toHaveBeenCalledWith({
        data: branchData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        name: 'Duplicate Branch'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.branch.create.mockRejectedValue(error);

      await expect(create(branchData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const branchData = {
        tenant_id: 'invalid-tenant',
        name: 'Test Branch'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.branch.create.mockRejectedValue(error);

      await expect(create(branchData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.branch.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ tenant_id: 'tenant-123', name: 'Test' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a branch', async () => {
      const updateData = {
        name: 'Updated Branch',
        is_active: false
      };
      const mockUpdatedBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.branch.update.mockResolvedValue(mockUpdatedBranch);

      const result = await update('branch-123', updateData);

      expect(result).toEqual(mockUpdatedBranch);
      expect(prisma.branch.update).toHaveBeenCalledWith({
        where: { id: 'branch-123' },
        data: updateData
      });
    });

    it('should throw HttpError when branch not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.branch.update.mockRejectedValue(error);

      await expect(update('branch-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.branch.update.mockRejectedValue(error);

      await expect(update('branch-123', { name: 'duplicate-name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.branch.update.mockRejectedValue(error);

      await expect(update('branch-123', { facility_id: 'invalid-facility' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.branch.update.mockRejectedValue(new Error('DB error'));

      await expect(update('branch-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a branch', async () => {
      const mockDeletedBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.branch.update.mockResolvedValue(mockDeletedBranch);

      const result = await softDelete('branch-123');

      expect(result).toEqual(mockDeletedBranch);
      expect(prisma.branch.update).toHaveBeenCalledWith({
        where: { id: 'branch-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when branch not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.branch.update.mockRejectedValue(error);

      await expect(softDelete('branch-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.branch.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('branch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
