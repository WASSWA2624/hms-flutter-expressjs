/**
 * Ambulance repository tests
 *
 * @module tests/modules/ambulance/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  ambulance: {
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
} = require('@repositories/ambulance/ambulance.repository');

const prisma = require('@prisma/client');

describe('Ambulance Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ambulance by ID', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.ambulance.findFirst.mockResolvedValue(mockAmbulance);

      const result = await findById('ambulance-123');

      expect(result).toEqual(mockAmbulance);
      expect(prisma.ambulance.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'ambulance-123',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });

    it('should return null if ambulance not found', async () => {
      prisma.ambulance.findFirst.mockResolvedValue(null);

      const result = await findById('ambulance-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.ambulance.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('ambulance-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many ambulances with default pagination', async () => {
      const mockAmbulances = [
        {
          id: 'ambulance-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          identifier: 'AMB-001',
          status: 'AVAILABLE'
        },
        {
          id: 'ambulance-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          identifier: 'AMB-002',
          status: 'DISPATCHED'
        }
      ];
      prisma.ambulance.findMany.mockResolvedValue(mockAmbulances);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockAmbulances);
      expect(prisma.ambulance.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
    });

    it('should find ambulances with filters', async () => {
      const mockAmbulances = [
        {
          id: 'ambulance-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          identifier: 'AMB-001',
          status: 'AVAILABLE'
        }
      ];
      prisma.ambulance.findMany.mockResolvedValue(mockAmbulances);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        status: 'AVAILABLE'
      }, 0, 10);

      expect(result).toEqual(mockAmbulances);
      expect(prisma.ambulance.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          status: 'AVAILABLE'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.ambulance.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count ambulances without filters', async () => {
      prisma.ambulance.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.ambulance.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count ambulances with filters', async () => {
      prisma.ambulance.count.mockResolvedValue(5);

      const result = await count({ 
        tenant_id: 'tenant-123',
        status: 'AVAILABLE' 
      });

      expect(result).toBe(5);
      expect(prisma.ambulance.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          status: 'AVAILABLE'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.ambulance.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create ambulance', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.ambulance.create.mockResolvedValue(mockAmbulance);

      const data = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      const result = await create(data);

      expect(result).toEqual(mockAmbulance);
      expect(prisma.ambulance.create).toHaveBeenCalledWith({
        data,
        include: expect.any(Object)
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['identifier'] };
      prisma.ambulance.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.ambulance.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.ambulance.create.mockRejectedValue(new Error('DB error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update ambulance', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.ambulance.update.mockResolvedValue(mockAmbulance);

      const data = {
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED'
      };

      const result = await update('ambulance-123', data);

      expect(result).toEqual(mockAmbulance);
      expect(prisma.ambulance.update).toHaveBeenCalledWith({
        where: { id: 'ambulance-123' },
        data,
        include: expect.any(Object)
      });
    });

    it('should throw HttpError if ambulance not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.ambulance.update.mockRejectedValue(error);

      await expect(update('ambulance-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['identifier'] };
      prisma.ambulance.update.mockRejectedValue(error);

      await expect(update('ambulance-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.ambulance.update.mockRejectedValue(error);

      await expect(update('ambulance-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete ambulance', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };
      prisma.ambulance.update.mockResolvedValue(mockAmbulance);

      const result = await softDelete('ambulance-123');

      expect(result).toEqual(mockAmbulance);
      expect(prisma.ambulance.update).toHaveBeenCalledWith({
        where: { id: 'ambulance-123' },
        data: {
          deleted_at: expect.any(Date)
        },
        include: expect.any(Object)
      });
    });

    it('should throw HttpError if ambulance not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.ambulance.update.mockRejectedValue(error);

      await expect(softDelete('ambulance-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.ambulance.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('ambulance-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
