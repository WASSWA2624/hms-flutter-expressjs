/**
 * Role-Permission controller tests
 *
 * @module tests/modules/role-permission/controllers
 * Per testing.mdc: Mock service layer
 */

jest.mock('@services/role-permission/role-permission.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

const rolePermissionService = require('@services/role-permission/role-permission.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listRolePermissions,
  getRolePermissionById,
  createRolePermission,
  updateRolePermission,
  deleteRolePermission
} = require('@controllers/role-permission/role-permission.controller');

describe('Role-Permission Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {};
  });

  describe('listRolePermissions', () => {
    it('should list role-permissions with pagination', async () => {
      const mocks = [{ id: 'rp-1' }];
      const mockPagination = { page: 1, limit: 20, total: 1, totalPages: 1 };
      rolePermissionService.listRolePermissions.mockResolvedValue({
        rolePermissions: mocks,
        pagination: mockPagination
      });

      mockReq.query = { page: '1', limit: '20' };

      await listRolePermissions(mockReq, mockRes);

      expect(rolePermissionService.listRolePermissions).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getRolePermissionById', () => {
    it('should get role-permission by ID', async () => {
      const mock = { id: 'rp-123' };
      rolePermissionService.getRolePermissionById.mockResolvedValue(mock);

      mockReq.params = { id: 'rp-123' };

      await getRolePermissionById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createRolePermission', () => {
    it('should create role-permission', async () => {
      const mock = { id: 'rp-123' };
      rolePermissionService.createRolePermission.mockResolvedValue(mock);

      mockReq.body = { role_id: 'role-123', permission_id: 'permission-123' };

      await createRolePermission(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateRolePermission', () => {
    it('should update role-permission', async () => {
      const mock = { id: 'rp-123' };
      rolePermissionService.updateRolePermission.mockResolvedValue(mock);

      mockReq.params = { id: 'rp-123' };
      mockReq.body = { role_id: 'role-456' };

      await updateRolePermission(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteRolePermission', () => {
    it('should delete role-permission', async () => {
      rolePermissionService.deleteRolePermission.mockResolvedValue(undefined);

      mockReq.params = { id: 'rp-123' };

      await deleteRolePermission(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
