/**
 * Bed controller tests
 *
 * @module tests/modules/bed/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/bed/bed.service');
jest.mock('@lib/response');

const bedService = require('@services/bed/bed.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listBeds,
  getBedById,
  createBed,
  updateBed,
  deleteBed
} = require('@controllers/bed/bed.controller');

describe('Bed Controller', () => {
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

  describe('listBeds', () => {
    it('should list beds with default pagination', async () => {
      const mockResult = {
        beds: [
          { id: 'bed-1', label: 'Bed 101', tenant_id: 'tenant-123', status: 'AVAILABLE' },
          { id: 'bed-2', label: 'Bed 102', tenant_id: 'tenant-123', status: 'OCCUPIED' }
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
      bedService.listBeds.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listBeds(req, res);

      expect(bedService.listBeds).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.bed.list.success',
        mockResult.beds,
        mockResult.pagination
      );
    });

    it('should list beds with filters', async () => {
      const mockResult = {
        beds: [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      bedService.listBeds.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        status: 'AVAILABLE',
        search: 'bed'
      };

      await listBeds(req, res);

      expect(bedService.listBeds).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ward_id: 'ward-123',
          room_id: 'room-123',
          status: 'AVAILABLE',
          search: 'bed'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list beds with sort options', async () => {
      const mockResult = {
        beds: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      bedService.listBeds.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'label',
        order: 'asc'
      };

      await listBeds(req, res);

      expect(bedService.listBeds).toHaveBeenCalledWith(
        {},
        1,
        20,
        'label',
        'asc'
      );
    });
  });

  describe('getBedById', () => {
    it('should get bed by ID', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      bedService.getBedById.mockResolvedValue(mockBed);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'bed-123' };

      await getBedById(req, res);

      expect(bedService.getBedById).toHaveBeenCalledWith('bed-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.bed.get.success',
        mockBed
      );
    });
  });

  describe('createBed', () => {
    it('should create new bed', async () => {
      const bedData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = {
        id: 'bed-123',
        ...bedData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      bedService.createBed.mockResolvedValue(mockBed);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = bedData;

      await createBed(req, res);

      expect(bedService.createBed).toHaveBeenCalledWith(
        bedData,
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
        'messages.bed.create.success',
        mockBed
      );
    });

    it('should handle request without user', async () => {
      const bedData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = { id: 'bed-123', ...bedData };
      bedService.createBed.mockResolvedValue(mockBed);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = undefined;
      req.body = bedData;

      await createBed(req, res);

      expect(bedService.createBed).toHaveBeenCalledWith(
        bedData,
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

  describe('updateBed', () => {
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
        ...updateData
      };
      bedService.updateBed.mockResolvedValue(mockBed);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'bed-123' };
      req.body = updateData;

      await updateBed(req, res);

      expect(bedService.updateBed).toHaveBeenCalledWith(
        'bed-123',
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
        'messages.bed.update.success',
        mockBed
      );
    });

    it('should handle request without user', async () => {
      const updateData = { status: 'OCCUPIED' };
      const mockBed = { id: 'bed-123', status: 'OCCUPIED' };
      bedService.updateBed.mockResolvedValue(mockBed);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = undefined;
      req.params = { id: 'bed-123' };
      req.body = updateData;

      await updateBed(req, res);

      expect(bedService.updateBed).toHaveBeenCalledWith(
        'bed-123',
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

  describe('deleteBed', () => {
    it('should soft delete bed', async () => {
      bedService.deleteBed.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'bed-123' };

      await deleteBed(req, res);

      expect(bedService.deleteBed).toHaveBeenCalledWith(
        'bed-123',
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

    it('should handle request without user', async () => {
      bedService.deleteBed.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.user = undefined;
      req.params = { id: 'bed-123' };

      await deleteBed(req, res);

      expect(bedService.deleteBed).toHaveBeenCalledWith(
        'bed-123',
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
