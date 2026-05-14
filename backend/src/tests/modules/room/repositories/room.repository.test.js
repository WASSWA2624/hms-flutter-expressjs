/**
 * Room repository tests
 *
 * @module tests/modules/room/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  room: {
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
} = require('@repositories/room/room.repository');

const prisma = require('@prisma/client');

describe('Room Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find room by ID', async () => {
      const mockRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Room 101',
        floor: '1st Floor',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.room.findFirst.mockResolvedValue(mockRoom);

      const result = await findById('room-123');

      expect(result).toEqual(mockRoom);
      expect(prisma.room.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'room-123',
          deleted_at: null
        }
      });
    });

    it('should return null if room not found', async () => {
      prisma.room.findFirst.mockResolvedValue(null);

      const result = await findById('room-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.room.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('room-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many rooms with default pagination', async () => {
      const mockRooms = [
        {
          id: 'room-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          name: 'Room 101',
          floor: '1st Floor'
        },
        {
          id: 'room-2',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          name: 'Room 102',
          floor: '1st Floor'
        }
      ];
      prisma.room.findMany.mockResolvedValue(mockRooms);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockRooms);
      expect(prisma.room.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find rooms with filters', async () => {
      const mockRooms = [
        {
          id: 'room-1',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          name: 'Room 101',
          floor: '1st Floor'
        }
      ];
      prisma.room.findMany.mockResolvedValue(mockRooms);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        facility_id: 'facility-123',
        ward_id: 'ward-123'
      }, 0, 10);

      expect(result).toEqual(mockRooms);
      expect(prisma.room.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find rooms with custom sort order', async () => {
      const mockRooms = [];
      prisma.room.findMany.mockResolvedValue(mockRooms);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.room.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.room.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count rooms without filters', async () => {
      prisma.room.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.room.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count rooms with filters', async () => {
      prisma.room.count.mockResolvedValue(5);

      const result = await count({ tenant_id: 'tenant-123', ward_id: 'ward-123' });

      expect(result).toBe(5);
      expect(prisma.room.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          ward_id: 'ward-123'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.room.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new room', async () => {
      const roomData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Room 101',
        floor: '1st Floor'
      };
      const mockCreatedRoom = {
        id: 'room-new',
        ...roomData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.room.create.mockResolvedValue(mockCreatedRoom);

      const result = await create(roomData);

      expect(result).toEqual(mockCreatedRoom);
      expect(prisma.room.create).toHaveBeenCalledWith({
        data: roomData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const roomData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Room 101'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.room.create.mockRejectedValue(error);

      await expect(create(roomData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const roomData = {
        tenant_id: 'invalid-tenant',
        facility_id: 'facility-123',
        name: 'Room 101'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.room.create.mockRejectedValue(error);

      await expect(create(roomData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database error', async () => {
      const roomData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Room 101'
      };
      prisma.room.create.mockRejectedValue(new Error('DB error'));

      await expect(create(roomData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a room', async () => {
      const updateData = {
        name: 'Updated Room',
        floor: '2nd Floor'
      };
      const mockUpdatedRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Updated Room',
        floor: '2nd Floor',
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.room.update.mockResolvedValue(mockUpdatedRoom);

      const result = await update('room-123', updateData);

      expect(result).toEqual(mockUpdatedRoom);
      expect(prisma.room.update).toHaveBeenCalledWith({
        where: { id: 'room-123' },
        data: updateData
      });
    });

    it('should throw HttpError if room not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.room.update.mockRejectedValue(error);

      await expect(update('room-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.room.update.mockRejectedValue(error);

      await expect(update('room-123', { name: 'Duplicate' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'ward_id' };
      prisma.room.update.mockRejectedValue(error);

      await expect(update('room-123', { ward_id: 'invalid-ward' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database error', async () => {
      prisma.room.update.mockRejectedValue(new Error('DB error'));

      await expect(update('room-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a room', async () => {
      const mockDeletedRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Room 101',
        floor: '1st Floor',
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.room.update.mockResolvedValue(mockDeletedRoom);

      const result = await softDelete('room-123');

      expect(result).toEqual(mockDeletedRoom);
      expect(prisma.room.update).toHaveBeenCalledWith({
        where: { id: 'room-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if room not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.room.update.mockRejectedValue(error);

      await expect(softDelete('room-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database error', async () => {
      prisma.room.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('room-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
