/**
 * Department repository tests
 *
 * @module tests/modules/department/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  department: {
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
} = require('@repositories/department/department.repository');

const prisma = require('@prisma/client');

describe('Department Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find department by ID', async () => {
      const mockDepartment = {
        id: 'department-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.department.findFirst.mockResolvedValue(mockDepartment);

      const result = await findById('department-123');

      expect(result).toEqual(mockDepartment);
      expect(prisma.department.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'department-123',
          deleted_at: null
        }
      });
    });

    it('should return null if department not found', async () => {
      prisma.department.findFirst.mockResolvedValue(null);

      const result = await findById('department-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.department.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('department-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many departments with default pagination', async () => {
      const mockDepartments = [
        {
          id: 'department-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          branch_id: 'branch-123',
          name: 'Emergency Department',
          department_type: 'CLINICAL',
          is_active: true
        },
        {
          id: 'department-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          branch_id: 'branch-123',
          name: 'Radiology',
          department_type: 'DIAGNOSTICS',
          is_active: true
        }
      ];
      prisma.department.findMany.mockResolvedValue(mockDepartments);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockDepartments);
      expect(prisma.department.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find departments with filters', async () => {
      const mockDepartments = [
        {
          id: 'department-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          branch_id: 'branch-123',
          name: 'Emergency Department',
          department_type: 'CLINICAL',
          is_active: true
        }
      ];
      prisma.department.findMany.mockResolvedValue(mockDepartments);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        department_type: 'CLINICAL',
        is_active: true 
      }, 0, 10);

      expect(result).toEqual(mockDepartments);
      expect(prisma.department.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          department_type: 'CLINICAL',
          is_active: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find departments with custom sort order', async () => {
      const mockDepartments = [];
      prisma.department.findMany.mockResolvedValue(mockDepartments);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.department.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.department.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count departments without filters', async () => {
      prisma.department.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.department.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count departments with filters', async () => {
      prisma.department.count.mockResolvedValue(5);

      const result = await count({ tenant_id: 'tenant-123', is_active: true });

      expect(result).toBe(5);
      expect(prisma.department.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          is_active: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.department.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new department', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'New Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const mockCreatedDepartment = {
        id: 'department-new',
        ...departmentData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.department.create.mockResolvedValue(mockCreatedDepartment);

      const result = await create(departmentData);

      expect(result).toEqual(mockCreatedDepartment);
      expect(prisma.department.create).toHaveBeenCalledWith({
        data: departmentData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        name: 'Duplicate Department',
        department_type: 'CLINICAL'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.department.create.mockRejectedValue(error);

      await expect(create(departmentData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const departmentData = {
        tenant_id: 'invalid-tenant',
        name: 'Test Department',
        department_type: 'CLINICAL'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.department.create.mockRejectedValue(error);

      await expect(create(departmentData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.department.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ 
        tenant_id: 'tenant-123', 
        name: 'Test',
        department_type: 'CLINICAL'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a department', async () => {
      const updateData = {
        name: 'Updated Department',
        department_type: 'ADMINISTRATIVE',
        is_active: false
      };
      const mockUpdatedDepartment = {
        id: 'department-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.department.update.mockResolvedValue(mockUpdatedDepartment);

      const result = await update('department-123', updateData);

      expect(result).toEqual(mockUpdatedDepartment);
      expect(prisma.department.update).toHaveBeenCalledWith({
        where: { id: 'department-123' },
        data: updateData
      });
    });

    it('should throw HttpError when department not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.department.update.mockRejectedValue(error);

      await expect(update('department-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.department.update.mockRejectedValue(error);

      await expect(update('department-123', { name: 'duplicate-name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.department.update.mockRejectedValue(error);

      await expect(update('department-123', { facility_id: 'invalid-facility' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.department.update.mockRejectedValue(new Error('DB error'));

      await expect(update('department-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a department', async () => {
      const mockDeletedDepartment = {
        id: 'department-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.department.update.mockResolvedValue(mockDeletedDepartment);

      const result = await softDelete('department-123');

      expect(result).toEqual(mockDeletedDepartment);
      expect(prisma.department.update).toHaveBeenCalledWith({
        where: { id: 'department-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when department not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.department.update.mockRejectedValue(error);

      await expect(softDelete('department-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.department.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('department-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
