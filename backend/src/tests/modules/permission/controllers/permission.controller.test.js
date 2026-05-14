/**
 * Permission controller tests
 *
 * @module tests/modules/permission/controllers
 * Per testing.mdc: Mock service layer
 */

jest.mock('@services/permission/permission.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

const permissionService = require('@services/permission/permission.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listPermissions,
  getPermissionById,
  createPermission,
  updatePermission,
  deletePermission
} = require('@controllers/permission/permission.controller');

describe('Permission Controller', () => {
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

  describe('listPermissions', () => {
    it('should list permissions with pagination', async () => {
      const mockPermissions = [{ id: 'permission-1', name: 'view_users' }];
      const mockPagination = { page: 1, limit: 20, total: 1, totalPages: 1 };
      permissionService.listPermissions.mockResolvedValue({
        permissions: mockPermissions,
        pagination: mockPagination
      });

      mockReq.query = { page: '1', limit: '20' };

      await listPermissions(mockReq, mockRes);

      expect(permissionService.listPermissions).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.permission.list.success',
        mockPermissions,
        mockPagination
      );
    });
  });

  describe('getPermissionById', () => {
    it('should get permission by ID', async () => {
      const mockPermission = { id: 'permission-123', name: 'view_users' };
      permissionService.getPermissionById.mockResolvedValue(mockPermission);

      mockReq.params = { id: 'permission-123' };

      await getPermissionById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.permission.get.success',
        mockPermission
      );
    });
  });

  describe('createPermission', () => {
    it('should create permission', async () => {
      const mockPermission = { id: 'permission-123', name: 'view_users' };
      permissionService.createPermission.mockResolvedValue(mockPermission);

      mockReq.body = { name: 'view_users', tenant_id: 'tenant-123' };

      await createPermission(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.permission.create.success',
        mockPermission
      );
    });
  });

  describe('updatePermission', () => {
    it('should update permission', async () => {
      const mockPermission = { id: 'permission-123', name: 'edit_users' };
      permissionService.updatePermission.mockResolvedValue(mockPermission);

      mockReq.params = { id: 'permission-123' };
      mockReq.body = { name: 'edit_users' };

      await updatePermission(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deletePermission', () => {
    it('should delete permission', async () => {
      permissionService.deletePermission.mockResolvedValue(undefined);

      mockReq.params = { id: 'permission-123' };

      await deletePermission(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
