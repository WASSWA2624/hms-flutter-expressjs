/**
 * User-Role controller tests
 *
 * @module tests/modules/user-role/controllers
 * Per testing.mdc: Mock service layer
 */

jest.mock('@services/user-role/user-role.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

const userRoleService = require('@services/user-role/user-role.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
} = require('@controllers/user-role/user-role.controller');

describe('User-Role Controller', () => {
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

  describe('listUserRoles', () => {
    it('should list user-roles with pagination', async () => {
      const mocks = [{ id: 'ur-1' }];
      const mockPagination = { page: 1, limit: 20, total: 1, totalPages: 1 };
      userRoleService.listUserRoles.mockResolvedValue({
        userRoles: mocks,
        pagination: mockPagination
      });

      mockReq.query = { page: '1', limit: '20' };

      await listUserRoles(mockReq, mockRes);

      expect(userRoleService.listUserRoles).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getUserRoleById', () => {
    it('should get user-role by ID', async () => {
      const mock = { id: 'ur-123' };
      userRoleService.getUserRoleById.mockResolvedValue(mock);

      mockReq.params = { id: 'ur-123' };

      await getUserRoleById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createUserRole', () => {
    it('should create user-role', async () => {
      const mock = { id: 'ur-123' };
      userRoleService.createUserRole.mockResolvedValue(mock);

      mockReq.body = { user_id: 'user-123', role_id: 'role-123', tenant_id: 'tenant-123' };

      await createUserRole(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateUserRole', () => {
    it('should update user-role', async () => {
      const mock = { id: 'ur-123' };
      userRoleService.updateUserRole.mockResolvedValue(mock);

      mockReq.params = { id: 'ur-123' };
      mockReq.body = { role_id: 'role-456' };

      await updateUserRole(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteUserRole', () => {
    it('should delete user-role', async () => {
      userRoleService.deleteUserRole.mockResolvedValue(undefined);

      mockReq.params = { id: 'ur-123' };

      await deleteUserRole(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
