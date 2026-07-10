/**
 * Role-Permission service tests
 *
 * @module tests/modules/role-permission/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/role-permission/role-permission.repository');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

const rolePermissionRepository = require('@repositories/role-permission/role-permission.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
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
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
  });

  describe('listRolePermissions', () => {
    it('should list role-permissions with pagination', async () => {
      const mocks = [
        {
          id: 'rp-1',
          human_friendly_id: 'RPE0001',
          role_id: 'role-uuid',
          permission_id: 'perm-uuid',
          permission: {
            id: 'perm-uuid',
            human_friendly_id: 'PRM0001',
            name: 'clinical:read',
          },
        },
      ];
      rolePermissionRepository.findMany.mockResolvedValue(mocks);
      rolePermissionRepository.count.mockResolvedValue(1);

      const result = await listRolePermissions({}, 1, 20, 'created_at', 'asc', 'user-123', '127.0.0.1');

      expect(result.rolePermissions).toEqual([
        expect.objectContaining({
          id: 'RPE0001',
          permission_id: 'PRM0001',
          permission: expect.objectContaining({
            id: 'PRM0001',
            name: 'clinical:read',
          }),
        }),
      ]);
    });

    it('should resolve friendly role_id before querying', async () => {
      const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
      resolveIdentifierForPayload.mockImplementation(async ({ value, model }) => {
        if (model === 'role' && value === 'ROL0001') return 'role-uuid';
        return value;
      });
      rolePermissionRepository.findMany.mockResolvedValue([]);
      rolePermissionRepository.count.mockResolvedValue(0);

      await listRolePermissions(
        { role_id: 'ROL0001' },
        1,
        20,
        null,
        'asc',
        'user-123',
        '127.0.0.1'
      );

      expect(rolePermissionRepository.findMany).toHaveBeenCalledWith(
        { role_id: 'role-uuid' },
        0,
        20,
        { created_at: 'desc' }
      );
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
      const mock = { id: 'rp-123', role_id: 'role-uuid', permission_id: 'perm-uuid' };
      rolePermissionRepository.create.mockResolvedValue(mock);

      const result = await createRolePermission(
        { role_id: 'ROL0001', permission_id: 'PRM0001' },
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mock);
      expect(rolePermissionRepository.create).toHaveBeenCalledWith({
        role_id: 'ROL0001',
        permission_id: 'PRM0001',
      });
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
