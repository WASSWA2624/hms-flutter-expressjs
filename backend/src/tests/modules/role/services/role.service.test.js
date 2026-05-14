/**
 * Role service tests
 *
 * @module tests/modules/role/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

// Mock repository
jest.mock('@repositories/role/role.repository');
// Mock audit log
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

const roleRepository = require('@repositories/role/role.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listRoles,
  getRoleById,
  createRole,
  updateRole,
  deleteRole
} = require('@services/role/role.service');

describe('Role Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listRoles', () => {
    it('should list roles with pagination', async () => {
      const mockRoles = [
        { id: 'role-1', name: 'Admin' },
        { id: 'role-2', name: 'User' }
      ];
      roleRepository.findMany.mockResolvedValue(mockRoles);
      roleRepository.count.mockResolvedValue(2);

      const result = await listRoles({}, 1, 20, 'name', 'asc', 'user-123', '127.0.0.1');

      expect(result.roles).toEqual(mockRoles);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      roleRepository.findMany.mockResolvedValue([]);
      roleRepository.count.mockResolvedValue(0);

      await listRoles({ tenant_id: 'tenant-123' }, 1, 20, 'name', 'asc', 'user-123', '127.0.0.1');

      expect(roleRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should apply search filter correctly', async () => {
      roleRepository.findMany.mockResolvedValue([]);
      roleRepository.count.mockResolvedValue(0);

      await listRoles({ search: 'admin' }, 1, 20, null, 'asc', 'user-123', '127.0.0.1');

      expect(roleRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'admin' } },
            { description: { contains: 'admin' } }
          ])
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });
  });

  describe('getRoleById', () => {
    it('should get role by ID', async () => {
      const mockRole = { id: 'role-123', name: 'Admin' };
      roleRepository.findById.mockResolvedValue(mockRole);

      const result = await getRoleById('role-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mockRole);
    });

    it('should throw HttpError when role not found', async () => {
      roleRepository.findById.mockResolvedValue(null);

      await expect(getRoleById('role-123', 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('createRole', () => {
    it('should create role and audit log', async () => {
      const mockRole = { id: 'role-123', name: 'New Role' };
      roleRepository.create.mockResolvedValue(mockRole);

      const result = await createRole({ name: 'New Role' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockRole);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'role',
        entity_id: 'role-123',
        diff: { after: mockRole },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('updateRole', () => {
    it('should update role and audit log', async () => {
      const before = { id: 'role-123', name: 'Old Name' };
      const after = { id: 'role-123', name: 'New Name' };
      roleRepository.findById.mockResolvedValue(before);
      roleRepository.update.mockResolvedValue(after);

      const result = await updateRole('role-123', { name: 'New Name' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'role',
        entity_id: 'role-123',
        diff: { before, after },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw HttpError when role not found', async () => {
      roleRepository.findById.mockResolvedValue(null);

      await expect(updateRole('role-123', {}, 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('deleteRole', () => {
    it('should soft delete role and audit log', async () => {
      const before = { id: 'role-123', name: 'Admin' };
      roleRepository.findById.mockResolvedValue(before);
      roleRepository.softDelete.mockResolvedValue({});

      await deleteRole('role-123', 'user-123', '127.0.0.1');

      expect(roleRepository.softDelete).toHaveBeenCalledWith('role-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'role',
        entity_id: 'role-123',
        diff: { before },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw HttpError when role not found', async () => {
      roleRepository.findById.mockResolvedValue(null);

      await expect(deleteRole('role-123', 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });
});
