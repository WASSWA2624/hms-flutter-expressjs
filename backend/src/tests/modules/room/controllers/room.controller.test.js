/**
 * Room controller tests
 *
 * @module tests/modules/room/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/room/room.service');
jest.mock('@lib/response');

const roomService = require('@services/room/room.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listRooms,
  getRoomById,
  createRoom,
  updateRoom,
  deleteRoom
} = require('@controllers/room/room.controller');

describe('Room Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
      },
      ip: '192.168.1.1',
      get: jest.fn((header) => {
        if (header === 'user-agent') return 'Mozilla/5.0';
        return null;
      })
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listRooms', () => {
    it('should list rooms with default pagination', async () => {
      const mockResult = {
        rooms: [
          { id: 'room-1', name: 'Room 101', tenant_id: 'tenant-123' },
          { id: 'room-2', name: 'Room 102', tenant_id: 'tenant-123' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      roomService.listRooms.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listRooms(req, res);

      expect(roomService.listRooms).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.room.list.success',
        mockResult.rooms,
        mockResult.pagination
      );
    });

    it('should list rooms with filters', async () => {
      const mockResult = {
        rooms: [{ id: 'room-1', name: 'Room 101' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      roomService.listRooms.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        search: '101'
      };

      await listRooms(req, res);

      expect(roomService.listRooms).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          search: '101'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list rooms with sorting', async () => {
      const mockResult = {
        rooms: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      roomService.listRooms.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listRooms(req, res);

      expect(roomService.listRooms).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
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
      roomService.getRoomById.mockResolvedValue(mockRoom);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'room-123' };

      await getRoomById(req, res);

      expect(roomService.getRoomById).toHaveBeenCalledWith('room-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.room.get.success',
        mockRoom
      );
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
      roomService.createRoom.mockResolvedValue(mockCreatedRoom);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = roomData;

      await createRoom(req, res);

      expect(roomService.createRoom).toHaveBeenCalledWith(
        roomData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.room.create.success',
        mockCreatedRoom
      );
    });

    it('should create room without user context', async () => {
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
      roomService.createRoom.mockResolvedValue(mockCreatedRoom);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = roomData;
      req.user = undefined;

      await createRoom(req, res);

      expect(roomService.createRoom).toHaveBeenCalledWith(
        roomData,
        {
          user_id: undefined,
          tenant_id: undefined,
          facility_id: undefined,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });

  describe('updateRoom', () => {
    it('should update room successfully', async () => {
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
      roomService.updateRoom.mockResolvedValue(mockUpdatedRoom);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'room-123' };
      req.body = updateData;

      await updateRoom(req, res);

      expect(roomService.updateRoom).toHaveBeenCalledWith(
        'room-123',
        updateData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.room.update.success',
        mockUpdatedRoom
      );
    });

    it('should update room without user context', async () => {
      const updateData = { name: 'Updated Room' };
      const mockUpdatedRoom = {
        id: 'room-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Updated Room'
      };
      roomService.updateRoom.mockResolvedValue(mockUpdatedRoom);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'room-123' };
      req.body = updateData;
      req.user = undefined;

      await updateRoom(req, res);

      expect(roomService.updateRoom).toHaveBeenCalledWith(
        'room-123',
        updateData,
        {
          user_id: undefined,
          tenant_id: undefined,
          facility_id: undefined,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });

  describe('deleteRoom', () => {
    it('should delete room successfully', async () => {
      roomService.deleteRoom.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'room-123' };

      await deleteRoom(req, res);

      expect(roomService.deleteRoom).toHaveBeenCalledWith(
        'room-123',
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should delete room without user context', async () => {
      roomService.deleteRoom.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'room-123' };
      req.user = undefined;

      await deleteRoom(req, res);

      expect(roomService.deleteRoom).toHaveBeenCalledWith(
        'room-123',
        {
          user_id: undefined,
          tenant_id: undefined,
          facility_id: undefined,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });
});
