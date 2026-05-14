/**
 * Ward controller tests
 *
 * @module tests/modules/ward/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/ward/ward.service');
jest.mock('@lib/response');

const wardService = require('@services/ward/ward.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listWards,
  getWardById,
  createWard,
  updateWard,
  deleteWard,
  getWardBeds
} = require('@controllers/ward/ward.controller');

describe('Ward Controller', () => {
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

  describe('listWards', () => {
    it('should list wards with default pagination', async () => {
      const mockResult = {
        wards: [
          { id: 'ward-1', name: 'ICU Ward', tenant_id: 'tenant-123', ward_type: 'ICU' },
          { id: 'ward-2', name: 'General Ward', tenant_id: 'tenant-123', ward_type: 'GENERAL' }
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
      wardService.listWards.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listWards(req, res);

      expect(wardService.listWards).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.ward.list.success',
        mockResult.wards,
        mockResult.pagination
      );
    });

    it('should list wards with filters', async () => {
      const mockResult = {
        wards: [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      wardService.listWards.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        ward_type: 'ICU',
        is_active: 'true',
        search: 'icu'
      };

      await listWards(req, res);

      expect(wardService.listWards).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          ward_type: 'ICU',
          is_active: 'true',
          search: 'icu'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list wards with sorting', async () => {
      const mockResult = {
        wards: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      wardService.listWards.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listWards(req, res);

      expect(wardService.listWards).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });
  });

  describe('getWardById', () => {
    it('should get ward by ID', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      wardService.getWardById.mockResolvedValue(mockWard);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'ward-123' };

      await getWardById(req, res);

      expect(wardService.getWardById).toHaveBeenCalledWith('ward-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.ward.get.success',
        mockWard
      );
    });
  });

  describe('createWard', () => {
    it('should create ward successfully', async () => {
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
      wardService.createWard.mockResolvedValue(mockCreatedWard);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = wardData;

      await createWard(req, res);

      expect(wardService.createWard).toHaveBeenCalledWith(
        wardData,
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
        'messages.ward.create.success',
        mockCreatedWard
      );
    });

    it('should create ward without user context', async () => {
      const wardData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Ward',
        ward_type: 'GENERAL'
      };
      const mockCreatedWard = {
        id: 'ward-new',
        ...wardData,
        department_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      wardService.createWard.mockResolvedValue(mockCreatedWard);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = wardData;
      req.user = undefined;

      await createWard(req, res);

      expect(wardService.createWard).toHaveBeenCalledWith(
        wardData,
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

  describe('updateWard', () => {
    it('should update ward successfully', async () => {
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
        name: 'Updated Ward',
        ward_type: 'SURGICAL',
        is_active: false,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      wardService.updateWard.mockResolvedValue(mockUpdatedWard);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'ward-123' };
      req.body = updateData;

      await updateWard(req, res);

      expect(wardService.updateWard).toHaveBeenCalledWith(
        'ward-123',
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
        'messages.ward.update.success',
        mockUpdatedWard
      );
    });
  });

  describe('deleteWard', () => {
    it('should delete ward successfully', async () => {
      wardService.deleteWard.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'ward-123' };

      await deleteWard(req, res);

      expect(wardService.deleteWard).toHaveBeenCalledWith(
        'ward-123',
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
  });

  describe('getWardBeds', () => {
    it('should get ward beds successfully', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      wardService.getWardBeds.mockResolvedValue(mockWard);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'ward-123' };

      await getWardBeds(req, res);

      expect(wardService.getWardBeds).toHaveBeenCalledWith('ward-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.ward.beds.list.success',
        mockWard
      );
    });
  });
});
