/**
 * Unit controller tests
 *
 * @module tests/modules/unit/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/unit/unit.service');
jest.mock('@lib/response');

const unitService = require('@services/unit/unit.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listUnits,
  getUnitById,
  createUnit,
  updateUnit,
  deleteUnit
} = require('@controllers/unit/unit.controller');

describe('Unit Controller', () => {
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

  describe('listUnits', () => {
    it('should list units with default pagination', async () => {
      const mockResult = {
        units: [
          { id: 'unit-1', name: 'ICU Unit', tenant_id: 'tenant-123' },
          { id: 'unit-2', name: 'Surgery Unit', tenant_id: 'tenant-123' }
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
      unitService.listUnits.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listUnits(req, res);

      expect(unitService.listUnits).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.unit.list.success',
        mockResult.units,
        mockResult.pagination
      );
    });

    it('should list units with filters', async () => {
      const mockResult = {
        units: [{ id: 'unit-1', name: 'ICU Unit' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      unitService.listUnits.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        is_active: 'true',
        search: 'icu'
      };

      await listUnits(req, res);

      expect(unitService.listUnits).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          department_id: 'department-123',
          is_active: 'true',
          search: 'icu'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list units with sorting', async () => {
      const mockResult = {
        units: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      unitService.listUnits.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listUnits(req, res);

      expect(unitService.listUnits).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });
  });

  describe('getUnitById', () => {
    it('should get unit by ID', async () => {
      const mockUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true
      };
      unitService.getUnitById.mockResolvedValue(mockUnit);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'unit-123' };

      await getUnitById(req, res);

      expect(unitService.getUnitById).toHaveBeenCalledWith('unit-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.unit.get.success',
        mockUnit
      );
    });
  });

  describe('createUnit', () => {
    it('should create unit successfully', async () => {
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
      unitService.createUnit.mockResolvedValue(mockCreatedUnit);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = unitData;

      await createUnit(req, res);

      expect(unitService.createUnit).toHaveBeenCalledWith(
        unitData,
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
        'messages.unit.create.success',
        mockCreatedUnit
      );
    });

    it('should create unit without user context', async () => {
      const unitData = {
        tenant_id: 'tenant-123',
        name: 'New Unit'
      };
      const mockCreatedUnit = {
        id: 'unit-new',
        ...unitData,
        facility_id: null,
        department_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      unitService.createUnit.mockResolvedValue(mockCreatedUnit);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = unitData;
      req.user = undefined;

      await createUnit(req, res);

      expect(unitService.createUnit).toHaveBeenCalledWith(
        unitData,
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

  describe('updateUnit', () => {
    it('should update unit successfully', async () => {
      const updateData = {
        name: 'Updated Unit',
        is_active: false
      };
      const mockUpdatedUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'Updated Unit',
        is_active: false,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      unitService.updateUnit.mockResolvedValue(mockUpdatedUnit);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'unit-123' };
      req.body = updateData;

      await updateUnit(req, res);

      expect(unitService.updateUnit).toHaveBeenCalledWith(
        'unit-123',
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
        'messages.unit.update.success',
        mockUpdatedUnit
      );
    });
  });

  describe('deleteUnit', () => {
    it('should delete unit successfully', async () => {
      unitService.deleteUnit.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'unit-123' };

      await deleteUnit(req, res);

      expect(unitService.deleteUnit).toHaveBeenCalledWith(
        'unit-123',
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
});
