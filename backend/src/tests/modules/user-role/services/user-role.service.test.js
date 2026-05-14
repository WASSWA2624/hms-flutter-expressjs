/**
 * User-Role service tests
 *
 * @module tests/modules/user-role/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/user-role/user-role.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

const userRoleRepository = require('@repositories/user-role/user-role.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
} = require('@services/user-role/user-role.service');

describe('User-Role Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listUserRoles', () => {
    it('should list user-roles with pagination', async () => {
      const mocks = [{ id: 'ur-1' }];
      userRoleRepository.findMany.mockResolvedValue(mocks);
      userRoleRepository.count.mockResolvedValue(1);

      const result = await listUserRoles({}, 1, 20, 'created_at', 'asc', 'user-123', '127.0.0.1');

      expect(result.userRoles).toEqual(mocks);
    });
  });

  describe('getUserRoleById', () => {
    it('should get user-role by ID', async () => {
      const mock = { id: 'ur-123' };
      userRoleRepository.findById.mockResolvedValue(mock);

      const result = await getUserRoleById('ur-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mock);
    });

    it('should throw HttpError when not found', async () => {
      userRoleRepository.findById.mockResolvedValue(null);

      await expect(getUserRoleById('ur-123', 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('createUserRole', () => {
    it('should create user-role and audit log', async () => {
      const mock = { id: 'ur-123', user_id: 'user-123' };
      userRoleRepository.create.mockResolvedValue(mock);

      const result = await createUserRole({ user_id: 'user-123' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(mock);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateUserRole', () => {
    it('should update user-role and audit log', async () => {
      const before = { id: 'ur-123', user_id: 'user-123' };
      const after = { id: 'ur-123', user_id: 'user-456' };
      userRoleRepository.findById.mockResolvedValue(before);
      userRoleRepository.update.mockResolvedValue(after);

      const result = await updateUserRole('ur-123', { user_id: 'user-456' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteUserRole', () => {
    it('should soft delete user-role and audit log', async () => {
      const before = { id: 'ur-123' };
      userRoleRepository.findById.mockResolvedValue(before);
      userRoleRepository.softDelete.mockResolvedValue({});

      await deleteUserRole('ur-123', 'user-123', '127.0.0.1');

      expect(userRoleRepository.softDelete).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
