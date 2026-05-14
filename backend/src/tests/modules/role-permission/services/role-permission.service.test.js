/**
 * Role-Permission service tests
 *
 * @module tests/modules/role-permission/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/role-permission/role-permission.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

const rolePermissionRepository = require('@repositories/role-permission/role-permission.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listRolePermissions,
  getRolePermissionById,
  createRolePermission,
  updateRolePermission,
  deleteRolePermission
} = require('@services/role-permission/role-permission.service');

describe('Role-Permission Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listRolePermissions', () => {
    it('should list role-permissions with pagination', async () => {
      const mocks = [{ id: 'rp-1' }];
      rolePermissionRepository.findMany.mockResolvedValue(mocks);
      rolePermissionRepository.count.mockResolvedValue(1);

      const result = await listRolePermissions({}, 1, 20, 'created_at', 'asc', 'user-123', '127.0.0.1');

      expect(result.rolePermissions).toEqual(mocks);
    });
  });

  describe('getRolePermissionById', () => {
    it('should get role-permission by ID', async () => {
      const mock = { id: 'rp-123' };
      rolePermissionRepository.findById.mockResolvedValue(mock);

      const result = await getRolePermissionById('rp-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mock);
    });

    it('should throw HttpError when not found', async () => {
      rolePermissionRepository.findById.mockResolvedValue(null);

      await expect(getRolePermissionById('rp-123', 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('createRolePermission', () => {
    it('should create role-permission and audit log', async () => {
      const mock = { id: 'rp-123', role_id: 'role-123' };
      rolePermissionRepository.create.mockResolvedValue(mock);

      const result = await createRolePermission({ role_id: 'role-123' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(mock);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateRolePermission', () => {
    it('should update role-permission and audit log', async () => {
      const before = { id: 'rp-123', role_id: 'role-123' };
      const after = { id: 'rp-123', role_id: 'role-456' };
      rolePermissionRepository.findById.mockResolvedValue(before);
      rolePermissionRepository.update.mockResolvedValue(after);

      const result = await updateRolePermission('rp-123', { role_id: 'role-456' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteRolePermission', () => {
    it('should soft delete role-permission and audit log', async () => {
      const before = { id: 'rp-123' };
      rolePermissionRepository.findById.mockResolvedValue(before);
      rolePermissionRepository.softDelete.mockResolvedValue({});

      await deleteRolePermission('rp-123', 'user-123', '127.0.0.1');

      expect(rolePermissionRepository.softDelete).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
