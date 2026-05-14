/**
 * Department controller tests
 *
 * @module tests/modules/department/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/department/department.service');
jest.mock('@lib/response');

const departmentService = require('@services/department/department.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  getDepartmentUnits
} = require('@controllers/department/department.controller');

describe('Department Controller', () => {
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

  describe('listDepartments', () => {
    it('should list departments with default pagination', async () => {
      const mockResult = {
        departments: [
          { id: 'dept-1', name: 'Emergency', tenant_id: 'tenant-123', department_type: 'CLINICAL' },
          { id: 'dept-2', name: 'Radiology', tenant_id: 'tenant-123', department_type: 'DIAGNOSTICS' }
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
      departmentService.listDepartments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listDepartments(req, res);

      expect(departmentService.listDepartments).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.department.list.success',
        mockResult.departments,
        mockResult.pagination
      );
    });

    it('should list departments with filters', async () => {
      const mockResult = {
        departments: [{ id: 'dept-1', name: 'Emergency', department_type: 'CLINICAL' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      departmentService.listDepartments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        department_type: 'CLINICAL',
        is_active: 'true',
        search: 'emergency'
      };

      await listDepartments(req, res);

      expect(departmentService.listDepartments).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          branch_id: 'branch-123',
          department_type: 'CLINICAL',
          is_active: 'true',
          search: 'emergency'
        },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list departments with sorting', async () => {
      const mockResult = {
        departments: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      departmentService.listDepartments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listDepartments(req, res);

      expect(departmentService.listDepartments).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });
  });

  describe('getDepartmentById', () => {
    it('should get department by ID', async () => {
      const mockDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      departmentService.getDepartmentById.mockResolvedValue(mockDepartment);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'dept-123' };

      await getDepartmentById(req, res);

      expect(departmentService.getDepartmentById).toHaveBeenCalledWith('dept-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.department.get.success',
        mockDepartment
      );
    });
  });

  describe('createDepartment', () => {
    it('should create department successfully', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'New Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const mockCreatedDepartment = {
        id: 'dept-new',
        ...departmentData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      departmentService.createDepartment.mockResolvedValue(mockCreatedDepartment);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = departmentData;

      await createDepartment(req, res);

      expect(departmentService.createDepartment).toHaveBeenCalledWith(
        departmentData,
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
        'messages.department.create.success',
        mockCreatedDepartment
      );
    });

    it('should create department without user context', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        name: 'New Department',
        department_type: 'CLINICAL'
      };
      const mockCreatedDepartment = {
        id: 'dept-new',
        ...departmentData,
        facility_id: null,
        branch_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      departmentService.createDepartment.mockResolvedValue(mockCreatedDepartment);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = departmentData;
      req.user = undefined;

      await createDepartment(req, res);

      expect(departmentService.createDepartment).toHaveBeenCalledWith(
        departmentData,
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

  describe('updateDepartment', () => {
    it('should update department successfully', async () => {
      const updateData = {
        name: 'Updated Department',
        department_type: 'ADMINISTRATIVE',
        is_active: false
      };
      const mockUpdatedDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Updated Department',
        department_type: 'ADMINISTRATIVE',
        is_active: false,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      departmentService.updateDepartment.mockResolvedValue(mockUpdatedDepartment);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'dept-123' };
      req.body = updateData;

      await updateDepartment(req, res);

      expect(departmentService.updateDepartment).toHaveBeenCalledWith(
        'dept-123',
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
        'messages.department.update.success',
        mockUpdatedDepartment
      );
    });
  });

  describe('deleteDepartment', () => {
    it('should delete department successfully', async () => {
      departmentService.deleteDepartment.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'dept-123' };

      await deleteDepartment(req, res);

      expect(departmentService.deleteDepartment).toHaveBeenCalledWith(
        'dept-123',
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

  describe('getDepartmentUnits', () => {
    it('should get department units with pagination', async () => {
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
      departmentService.getDepartmentUnits.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.params = { id: 'dept-123' };
      req.query = { page: 1, limit: 20 };

      await getDepartmentUnits(req, res);

      expect(departmentService.getDepartmentUnits).toHaveBeenCalledWith('dept-123', 1, 20);
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.department.units.list.success',
        mockResult.units,
        mockResult.pagination
      );
    });
  });
});
