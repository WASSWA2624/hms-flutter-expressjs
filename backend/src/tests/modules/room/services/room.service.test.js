/**
 * Room service tests
 *
 * @module tests/modules/room/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/room/room.repository');
jest.mock('@lib/audit');

const roomRepository = require('@repositories/room/room.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listRooms,
  getRoomById,
  createRoom,
  updateRoom,
  deleteRoom
} = require('@services/room/room.service');

describe('Room Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listRooms', () => {
    it('should list rooms with default pagination', async () => {
      const mockRooms = [
        { id: 'room-1', name: 'Room 101', tenant_id: 'tenant-123' },
        { id: 'room-2', name: 'Room 102', tenant_id: 'tenant-123' }
      ];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(10);

      const result = await listRooms({}, 1, 20);

      expect(result.rooms).toEqual(mockRooms);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(roomRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockRooms = [{ id: 'room-1', name: 'Room 101' }];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(1);

      const result = await listRooms({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.rooms).toEqual(mockRooms);
      expect(roomRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockRooms = [{ id: 'room-1', name: 'Room 101' }];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(1);

      const result = await listRooms({ facility_id: 'facility-123' }, 1, 20);

      expect(result.rooms).toEqual(mockRooms);
      expect(roomRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by ward_id', async () => {
      const mockRooms = [{ id: 'room-1', name: 'Room 101' }];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(1);

      const result = await listRooms({ ward_id: 'ward-123' }, 1, 20);

      expect(result.rooms).toEqual(mockRooms);
      expect(roomRepository.findMany).toHaveBeenCalledWith(
        { ward_id: 'ward-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockRooms = [{ id: 'room-1', name: 'Room 101' }];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(1);

      const result = await listRooms({ search: '101' }, 1, 20);

      expect(result.rooms).toEqual(mockRooms);
      expect(roomRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: '101', mode: 'insensitive' }
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockRooms = [];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(0);

      await listRooms({}, 1, 20, 'name', 'asc');

      expect(roomRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockRooms = [];
      roomRepository.findMany.mockResolvedValue(mockRooms);
      roomRepository.count.mockResolvedValue(50);

      const result = await listRooms({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getRoomById', () => {
    it('should get room by ID', async () => {
      const mockRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Room 101',
        floor: '1st Floor'
      };
      roomRepository.findById.mockResolvedValue(mockRoom);

      const result = await getRoomById('room-123');

      expect(result).toEqual(mockRoom);
      expect(roomRepository.findById).toHaveBeenCalledWith('room-123');
    });

    it('should throw HttpError if room not found', async () => {
      roomRepository.findById.mockResolvedValue(null);

      await expect(getRoomById('room-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createRoom', () => {
    it('should create room successfully', async () => {
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
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      roomRepository.create.mockResolvedValue(mockCreatedRoom);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createRoom(roomData, context);

      expect(result).toEqual(mockCreatedRoom);
      expect(roomRepository.create).toHaveBeenCalledWith(roomData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'ROOM_CREATED',
        entity: 'room',
        entity_id: mockCreatedRoom.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockCreatedRoom.tenant_id,
          facility_id: mockCreatedRoom.facility_id,
          ward_id: mockCreatedRoom.ward_id,
          name: mockCreatedRoom.name,
          floor: mockCreatedRoom.floor
        }
      });
    });

    it('should create room without context', async () => {
      const roomData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Room 101'
      };
      const mockCreatedRoom = {
        id: 'room-new',
        ...roomData,
        ward_id: null,
        floor: null,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      roomRepository.create.mockResolvedValue(mockCreatedRoom);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createRoom(roomData);

      expect(result).toEqual(mockCreatedRoom);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      roomRepository.create.mockRejectedValue(error);

      await expect(createRoom({ 
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Test'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateRoom', () => {
    it('should update room successfully', async () => {
      const beforeRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Old Room',
        floor: '1st Floor'
      };
      const updateData = {
        name: 'New Room',
        floor: '2nd Floor'
      };
      const afterRoom = {
        ...beforeRoom,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      roomRepository.findById.mockResolvedValue(beforeRoom);
      roomRepository.update.mockResolvedValue(afterRoom);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateRoom('room-123', updateData, context);

      expect(result).toEqual(afterRoom);
      expect(roomRepository.findById).toHaveBeenCalledWith('room-123');
      expect(roomRepository.update).toHaveBeenCalledWith('room-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'ROOM_UPDATED',
        entity: 'room',
        entity_id: 'room-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            facility_id: beforeRoom.facility_id,
            ward_id: beforeRoom.ward_id,
            name: beforeRoom.name,
            floor: beforeRoom.floor
          },
          after: {
            facility_id: afterRoom.facility_id,
            ward_id: afterRoom.ward_id,
            name: afterRoom.name,
            floor: afterRoom.floor
          }
        }
      });
    });

    it('should throw HttpError if room not found', async () => {
      roomRepository.findById.mockResolvedValue(null);

      await expect(updateRoom('room-123', { name: 'New Name' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should propagate repository errors', async () => {
      const mockRoom = {
        id: 'room-123',
        name: 'Room 101'
      };
      roomRepository.findById.mockResolvedValue(mockRoom);
      roomRepository.update.mockRejectedValue(new HttpError('errors.database.unique_field', 409));

      await expect(updateRoom('room-123', { name: 'Duplicate' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteRoom', () => {
    it('should delete room successfully', async () => {
      const mockRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        name: 'Room 101'
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      roomRepository.findById.mockResolvedValue(mockRoom);
      roomRepository.softDelete.mockResolvedValue(undefined);
      createAuditLog.mockResolvedValue(undefined);

      await deleteRoom('room-123', context);

      expect(roomRepository.findById).toHaveBeenCalledWith('room-123');
      expect(roomRepository.softDelete).toHaveBeenCalledWith('room-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'ROOM_DELETED',
        entity: 'room',
        entity_id: 'room-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockRoom.tenant_id,
          facility_id: mockRoom.facility_id,
          ward_id: mockRoom.ward_id,
          name: mockRoom.name
        }
      });
    });

    it('should throw HttpError if room not found', async () => {
      roomRepository.findById.mockResolvedValue(null);

      await expect(deleteRoom('room-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should propagate repository errors', async () => {
      const mockRoom = {
        id: 'room-123',
        name: 'Room 101'
      };
      roomRepository.findById.mockResolvedValue(mockRoom);
      roomRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(deleteRoom('room-123'))
        .rejects
        .toThrow();
    });
  });
});
