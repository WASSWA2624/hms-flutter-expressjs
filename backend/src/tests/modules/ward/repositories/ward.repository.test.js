/**
 * Ward repository tests
 *
 * @module tests/modules/ward/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  ward: {
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
} = require('@repositories/ward/ward.repository');

const prisma = require('@prisma/client');

describe('Ward Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ward by ID', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.ward.findFirst.mockResolvedValue(mockWard);

      const result = await findById('ward-123');

      expect(result).toEqual(mockWard);
      expect(prisma.ward.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'ward-123',
          deleted_at: null
        }
      });
    });

    it('should return null if ward not found', async () => {
      prisma.ward.findFirst.mockResolvedValue(null);

      const result = await findById('ward-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.ward.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('ward-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many wards with default pagination', async () => {
      const mockWards = [
        {
          id: 'ward-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'ICU Ward',
          ward_type: 'ICU',
          is_active: true
        },
        {
          id: 'ward-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'General Ward',
          ward_type: 'GENERAL',
          is_active: true
        }
      ];
      prisma.ward.findMany.mockResolvedValue(mockWards);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockWards);
      expect(prisma.ward.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find wards with filters', async () => {
      const mockWards = [
        {
          id: 'ward-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          name: 'ICU Ward',
          ward_type: 'ICU',
          is_active: true
        }
      ];
      prisma.ward.findMany.mockResolvedValue(mockWards);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        department_id: 'department-123',
        ward_type: 'ICU',
        is_active: true 
      }, 0, 10);

      expect(result).toEqual(mockWards);
      expect(prisma.ward.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          department_id: 'department-123',
          ward_type: 'ICU',
          is_active: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find wards with custom sort order', async () => {
      const mockWards = [];
      prisma.ward.findMany.mockResolvedValue(mockWards);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.ward.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.ward.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count wards without filters', async () => {
      prisma.ward.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.ward.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count wards with filters', async () => {
      prisma.ward.count.mockResolvedValue(5);

      const result = await count({ tenant_id: 'tenant-123', ward_type: 'ICU', is_active: true });

      expect(result).toBe(5);
      expect(prisma.ward.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          ward_type: 'ICU',
          is_active: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.ward.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new ward', async () => {
      const wardData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'New Ward',
        ward_type: 'GENERAL',
        is_active: true
      };
      const mockCreatedWard = {
        id: 'ward-new',
        ...wardData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.ward.create.mockResolvedValue(mockCreatedWard);

      const result = await create(wardData);

      expect(result).toEqual(mockCreatedWard);
      expect(prisma.ward.create).toHaveBeenCalledWith({
        data: wardData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const wardData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Duplicate Ward',
        ward_type: 'GENERAL'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.ward.create.mockRejectedValue(error);

      await expect(create(wardData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const wardData = {
        tenant_id: 'invalid-tenant',
        facility_id: 'facility-123',
        name: 'Test Ward',
        ward_type: 'GENERAL'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.ward.create.mockRejectedValue(error);

      await expect(create(wardData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.ward.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ 
        tenant_id: 'tenant-123', 
        facility_id: 'facility-123',
        name: 'Test',
        ward_type: 'GENERAL'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a ward', async () => {
      const updateData = {
        name: 'Updated Ward',
        ward_type: 'SURGICAL',
        is_active: false
      };
      const mockUpdatedWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.ward.update.mockResolvedValue(mockUpdatedWard);

      const result = await update('ward-123', updateData);

      expect(result).toEqual(mockUpdatedWard);
      expect(prisma.ward.update).toHaveBeenCalledWith({
        where: { id: 'ward-123' },
        data: updateData
      });
    });

    it('should throw HttpError when ward not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.ward.update.mockRejectedValue(error);

      await expect(update('ward-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.ward.update.mockRejectedValue(error);

      await expect(update('ward-123', { name: 'duplicate-name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.ward.update.mockRejectedValue(error);

      await expect(update('ward-123', { facility_id: 'invalid-facility' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.ward.update.mockRejectedValue(new Error('DB error'));

      await expect(update('ward-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a ward', async () => {
      const mockDeletedWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.ward.update.mockResolvedValue(mockDeletedWard);

      const result = await softDelete('ward-123');

      expect(result).toEqual(mockDeletedWard);
      expect(prisma.ward.update).toHaveBeenCalledWith({
        where: { id: 'ward-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when ward not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.ward.update.mockRejectedValue(error);

      await expect(softDelete('ward-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.ward.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('ward-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
