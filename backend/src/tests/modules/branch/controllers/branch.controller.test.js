/**
 * Branch controller tests
 *
 * @module tests/modules/branch/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/branch/branch.service');
jest.mock('@lib/response');

const branchService = require('@services/branch/branch.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listBranches,
  getBranchById,
  createBranch,
  updateBranch,
  deleteBranch
} = require('@controllers/branch/branch.controller');

describe('Branch Controller', () => {
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

  describe('listBranches', () => {
    it('should list branches with default pagination', async () => {
      const mockResult = {
        branches: [
          { id: 'branch-1', name: 'Branch A', tenant_id: 'tenant-123' },
          { id: 'branch-2', name: 'Branch B', tenant_id: 'tenant-123' }
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
      branchService.listBranches.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listBranches(req, res);

      expect(branchService.listBranches).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.branch.list.success',
        mockResult.branches,
        mockResult.pagination
      );
    });

    it('should list branches with filters', async () => {
      const mockResult = {
        branches: [{ id: 'branch-1', name: 'Branch A' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      branchService.listBranches.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        is_active: 'true',
        search: 'branch'
      };

      await listBranches(req, res);

      expect(branchService.listBranches).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          is_active: 'true',
          search: 'branch'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list branches with sorting', async () => {
      const mockResult = {
        branches: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      branchService.listBranches.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listBranches(req, res);

      expect(branchService.listBranches).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });

    it('should coerce string pagination params to numbers', async () => {
      const mockResult = {
        branches: [],
        pagination: {
          page: 2,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: true
        }
      };
      branchService.listBranches.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: '2',
        limit: '20'
      };

      await listBranches(req, res);

      expect(branchService.listBranches).toHaveBeenCalledWith(
        {},
        2,
        20,
        undefined,
        undefined
      );
    });
  });

  describe('getBranchById', () => {
    it('should get branch by ID', async () => {
      const mockBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true
      };
      branchService.getBranchById.mockResolvedValue(mockBranch);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'branch-123' };

      await getBranchById(req, res);

      expect(branchService.getBranchById).toHaveBeenCalledWith('branch-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.branch.get.success',
        mockBranch
      );
    });
  });

  describe('createBranch', () => {
    it('should create branch successfully', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Branch',
        is_active: true
      };
      const mockCreatedBranch = {
        id: 'branch-new',
        ...branchData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      branchService.createBranch.mockResolvedValue(mockCreatedBranch);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = branchData;

      await createBranch(req, res);

      expect(branchService.createBranch).toHaveBeenCalledWith(
        branchData,
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
        'messages.branch.create.success',
        mockCreatedBranch
      );
    });

    it('should create branch without user context', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        name: 'New Branch'
      };
      const mockCreatedBranch = {
        id: 'branch-new',
        ...branchData,
        facility_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      branchService.createBranch.mockResolvedValue(mockCreatedBranch);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = branchData;
      req.user = undefined;

      await createBranch(req, res);

      expect(branchService.createBranch).toHaveBeenCalledWith(
        branchData,
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

  describe('updateBranch', () => {
    it('should update branch successfully', async () => {
      const updateData = {
        name: 'Updated Branch',
        is_active: false
      };
      const mockUpdatedBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Updated Branch',
        is_active: false,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      branchService.updateBranch.mockResolvedValue(mockUpdatedBranch);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'branch-123' };
      req.body = updateData;

      await updateBranch(req, res);

      expect(branchService.updateBranch).toHaveBeenCalledWith(
        'branch-123',
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
        'messages.branch.update.success',
        mockUpdatedBranch
      );
    });
  });

  describe('deleteBranch', () => {
    it('should delete branch successfully', async () => {
      branchService.deleteBranch.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'branch-123' };

      await deleteBranch(req, res);

      expect(branchService.deleteBranch).toHaveBeenCalledWith(
        'branch-123',
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
