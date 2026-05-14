/**
 * Bed repository tests
 *
 * @module tests/modules/bed/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  bed: {
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
} = require('@repositories/bed/bed.repository');

const prisma = require('@prisma/client');

describe('Bed Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find bed by ID', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.bed.findFirst.mockResolvedValue(mockBed);

      const result = await findById('bed-123');

      expect(result).toEqual(mockBed);
      expect(prisma.bed.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'bed-123',
          deleted_at: null
        }
      });
    });

    it('should return null if bed not found', async () => {
      prisma.bed.findFirst.mockResolvedValue(null);

      const result = await findById('bed-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.bed.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('bed-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many beds with default pagination', async () => {
      const mockBeds = [
        {
          id: 'bed-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          room_id: 'room-123',
          label: 'Bed 101',
          status: 'AVAILABLE'
        },
        {
          id: 'bed-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          room_id: 'room-124',
          label: 'Bed 102',
          status: 'OCCUPIED'
        }
      ];
      prisma.bed.findMany.mockResolvedValue(mockBeds);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockBeds);
      expect(prisma.bed.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find beds with filters', async () => {
      const mockBeds = [
        {
          id: 'bed-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          room_id: 'room-123',
          label: 'Bed 101',
          status: 'AVAILABLE'
        }
      ];
      prisma.bed.findMany.mockResolvedValue(mockBeds);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        ward_id: 'ward-123',
        status: 'AVAILABLE'
      }, 0, 10);

      expect(result).toEqual(mockBeds);
      expect(prisma.bed.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          ward_id: 'ward-123',
          status: 'AVAILABLE'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find beds with custom order', async () => {
      const mockBeds = [];
      prisma.bed.findMany.mockResolvedValue(mockBeds);

      const result = await findMany({}, 0, 20, { label: 'asc' });

      expect(result).toEqual(mockBeds);
      expect(prisma.bed.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { label: 'asc' }
      });
    });

    it('should return empty array if no beds found', async () => {
      prisma.bed.findMany.mockResolvedValue([]);

      const result = await findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.bed.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count beds with no filters', async () => {
      prisma.bed.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.bed.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count beds with filters', async () => {
      prisma.bed.count.mockResolvedValue(5);

      const result = await count({ 
        tenant_id: 'tenant-123', 
        status: 'AVAILABLE' 
      });

      expect(result).toBe(5);
      expect(prisma.bed.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          status: 'AVAILABLE'
        }
      });
    });

    it('should return zero when no beds found', async () => {
      prisma.bed.count.mockResolvedValue(0);

      const result = await count();

      expect(result).toBe(0);
    });

    it('should throw HttpError on database error', async () => {
      prisma.bed.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new bed', async () => {
      const createData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = {
        id: 'bed-123',
        ...createData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.bed.create.mockResolvedValue(mockBed);

      const result = await create(createData);

      expect(result).toEqual(mockBed);
      expect(prisma.bed.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should create bed with null room_id', async () => {
      const createData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: null,
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = {
        id: 'bed-123',
        ...createData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.bed.create.mockResolvedValue(mockBed);

      const result = await create(createData);

      expect(result).toEqual(mockBed);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      prisma.bed.create.mockRejectedValue({
        code: 'P2002',
        meta: { target: ['label'] }
      });

      await expect(create({ label: 'Bed 101' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      prisma.bed.create.mockRejectedValue({
        code: 'P2003',
        meta: { field_name: 'ward_id' }
      });

      await expect(create({ ward_id: 'invalid-ward-id' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.bed.create.mockRejectedValue(new Error('DB error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update bed', async () => {
      const updateData = {
        label: 'Updated Bed',
        status: 'OCCUPIED'
      };
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.bed.update.mockResolvedValue(mockBed);

      const result = await update('bed-123', updateData);

      expect(result).toEqual(mockBed);
      expect(prisma.bed.update).toHaveBeenCalledWith({
        where: { id: 'bed-123' },
        data: updateData
      });
    });

    it('should update bed with null room_id', async () => {
      const updateData = {
        room_id: null
      };
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: null,
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      prisma.bed.update.mockResolvedValue(mockBed);

      const result = await update('bed-123', updateData);

      expect(result).toEqual(mockBed);
    });

    it('should throw HttpError when bed not found', async () => {
      prisma.bed.update.mockRejectedValue({
        code: 'P2025'
      });

      await expect(update('bed-123', { label: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      prisma.bed.update.mockRejectedValue({
        code: 'P2002',
        meta: { target: ['label'] }
      });

      await expect(update('bed-123', { label: 'Existing Bed' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      prisma.bed.update.mockRejectedValue({
        code: 'P2003',
        meta: { field_name: 'ward_id' }
      });

      await expect(update('bed-123', { ward_id: 'invalid-ward-id' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.bed.update.mockRejectedValue(new Error('DB error'));

      await expect(update('bed-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete bed', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };
      prisma.bed.update.mockResolvedValue(mockBed);

      const result = await softDelete('bed-123');

      expect(result).toEqual(mockBed);
      expect(prisma.bed.update).toHaveBeenCalledWith({
        where: { id: 'bed-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when bed not found', async () => {
      prisma.bed.update.mockRejectedValue({
        code: 'P2025'
      });

      await expect(softDelete('bed-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.bed.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('bed-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
