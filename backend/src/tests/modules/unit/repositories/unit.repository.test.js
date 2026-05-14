/**
 * Unit repository tests
 *
 * @module tests/modules/unit/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  unit: {
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
} = require('@repositories/unit/unit.repository');

const prisma = require('@prisma/client');

describe('Unit Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find unit by ID', async () => {
      const mockUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.unit.findFirst.mockResolvedValue(mockUnit);

      const result = await findById('unit-123');

      expect(result).toEqual(mockUnit);
      expect(prisma.unit.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'unit-123',
          deleted_at: null
        }
      });
    });

    it('should return null if unit not found', async () => {
      prisma.unit.findFirst.mockResolvedValue(null);

      const result = await findById('unit-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.unit.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('unit-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many units with default pagination', async () => {
      const mockUnits = [
        {
          id: 'unit-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'ICU Unit',
          is_active: true
        },
        {
          id: 'unit-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'Surgery Unit',
          is_active: true
        }
      ];
      prisma.unit.findMany.mockResolvedValue(mockUnits);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockUnits);
      expect(prisma.unit.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find units with filters', async () => {
      const mockUnits = [
        {
          id: 'unit-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'ICU Unit',
          is_active: true
        }
      ];
      prisma.unit.findMany.mockResolvedValue(mockUnits);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        department_id: 'department-123',
        is_active: true 
      }, 0, 10);

      expect(result).toEqual(mockUnits);
      expect(prisma.unit.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          department_id: 'department-123',
          is_active: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find units with custom sort order', async () => {
      const mockUnits = [];
      prisma.unit.findMany.mockResolvedValue(mockUnits);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.unit.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.unit.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count units without filters', async () => {
      prisma.unit.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.unit.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count units with filters', async () => {
      prisma.unit.count.mockResolvedValue(5);

      const result = await count({ tenant_id: 'tenant-123', is_active: true });

      expect(result).toBe(5);
      expect(prisma.unit.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          is_active: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.unit.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new unit', async () => {
      const unitData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'New Unit',
        is_active: true
      };
      const mockCreatedUnit = {
        id: 'unit-new',
        ...unitData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.unit.create.mockResolvedValue(mockCreatedUnit);

      const result = await create(unitData);

      expect(result).toEqual(mockCreatedUnit);
      expect(prisma.unit.create).toHaveBeenCalledWith({
        data: unitData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const unitData = {
        tenant_id: 'tenant-123',
        name: 'Duplicate Unit'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.unit.create.mockRejectedValue(error);

      await expect(create(unitData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const unitData = {
        tenant_id: 'invalid-tenant',
        name: 'Test Unit'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.unit.create.mockRejectedValue(error);

      await expect(create(unitData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.unit.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ 
        tenant_id: 'tenant-123', 
        name: 'Test'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a unit', async () => {
      const updateData = {
        name: 'Updated Unit',
        is_active: false
      };
      const mockUpdatedUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.unit.update.mockResolvedValue(mockUpdatedUnit);

      const result = await update('unit-123', updateData);

      expect(result).toEqual(mockUpdatedUnit);
      expect(prisma.unit.update).toHaveBeenCalledWith({
        where: { id: 'unit-123' },
        data: updateData
      });
    });

    it('should throw HttpError when unit not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.unit.update.mockRejectedValue(error);

      await expect(update('unit-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.unit.update.mockRejectedValue(error);

      await expect(update('unit-123', { name: 'duplicate-name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.unit.update.mockRejectedValue(error);

      await expect(update('unit-123', { facility_id: 'invalid-facility' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.unit.update.mockRejectedValue(new Error('DB error'));

      await expect(update('unit-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a unit', async () => {
      const mockDeletedUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.unit.update.mockResolvedValue(mockDeletedUnit);

      const result = await softDelete('unit-123');

      expect(result).toEqual(mockDeletedUnit);
      expect(prisma.unit.update).toHaveBeenCalledWith({
        where: { id: 'unit-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when unit not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.unit.update.mockRejectedValue(error);

      await expect(softDelete('unit-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.unit.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('unit-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
