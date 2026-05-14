/**
 * Role controller tests
 *
 * @module tests/modules/role/controllers
 * Per testing.mdc: Mock service layer
 */

jest.mock('@services/role/role.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

const roleService = require('@services/role/role.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listRoles,
  getRoleById,
  createRole,
  updateRole,
  deleteRole
} = require('@controllers/role/role.controller');

describe('Role Controller', () => {
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

  describe('listRoles', () => {
    it('should list roles with pagination', async () => {
      const mockRoles = [{ id: 'role-1', name: 'Admin' }];
      const mockPagination = { page: 1, limit: 20, total: 1, totalPages: 1 };
      roleService.listRoles.mockResolvedValue({
        roles: mockRoles,
        pagination: mockPagination
      });

      mockReq.query = { page: '1', limit: '20' };

      await listRoles(mockReq, mockRes);

      expect(roleService.listRoles).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.role.list.success',
        mockRoles,
        mockPagination
      );
    });

    it('should apply filters from query', async () => {
      roleService.listRoles.mockResolvedValue({ roles: [], pagination: {} });

      mockReq.query = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Admin',
        search: 'role'
      };

      await listRoles(mockReq, mockRes);

      expect(roleService.listRoles).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          name: 'Admin',
          search: 'role'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getRoleById', () => {
    it('should get role by ID', async () => {
      const mockRole = { id: 'role-123', name: 'Admin' };
      roleService.getRoleById.mockResolvedValue(mockRole);

      mockReq.params = { id: 'role-123' };

      await getRoleById(mockReq, mockRes);

      expect(roleService.getRoleById).toHaveBeenCalledWith('role-123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.role.get.success',
        mockRole
      );
    });
  });

  describe('createRole', () => {
    it('should create role', async () => {
      const mockRole = { id: 'role-123', name: 'New Role' };
      roleService.createRole.mockResolvedValue(mockRole);

      mockReq.body = { name: 'New Role', tenant_id: 'tenant-123' };

      await createRole(mockReq, mockRes);

      expect(roleService.createRole).toHaveBeenCalledWith(
        { name: 'New Role', tenant_id: 'tenant-123' },
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.role.create.success',
        mockRole
      );
    });
  });

  describe('updateRole', () => {
    it('should update role', async () => {
      const mockRole = { id: 'role-123', name: 'Updated Role' };
      roleService.updateRole.mockResolvedValue(mockRole);

      mockReq.params = { id: 'role-123' };
      mockReq.body = { name: 'Updated Role' };

      await updateRole(mockReq, mockRes);

      expect(roleService.updateRole).toHaveBeenCalledWith(
        'role-123',
        { name: 'Updated Role' },
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.role.update.success',
        mockRole
      );
    });
  });

  describe('deleteRole', () => {
    it('should delete role', async () => {
      roleService.deleteRole.mockResolvedValue(undefined);

      mockReq.params = { id: 'role-123' };

      await deleteRole(mockReq, mockRes);

      expect(roleService.deleteRole).toHaveBeenCalledWith('role-123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
