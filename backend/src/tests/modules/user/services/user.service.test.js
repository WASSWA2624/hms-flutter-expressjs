/**
 * User service tests
 *
 * @module tests/modules/user/services
 * @description Tests for user service
 * Per testing.mdc: Mock repository, test business logic
 */

const userService = require('@services/user/user.service');
const userRepository = require('@repositories/user/user.repository');
const { createAuditLog } = require('@lib/audit');
const { hashPassword } = require('@lib/crypto');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/user/user.repository');
jest.mock('@lib/audit');
jest.mock('@lib/crypto');

describe('User Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    hashPassword.mockResolvedValue('$2b$10$hashedpasswordplaceholder');
  });

  describe('listUsers', () => {
    const mockUsers = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        email: 'user1@example.com',
        status: 'ACTIVE'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440001',
        email: 'user2@example.com',
        status: 'INACTIVE'
      }
    ];

    it('should list users with pagination', async () => {
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(2);

      const result = await userService.listUsers({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('users', mockUsers);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'ACTIVE'
      };
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(2);

      await userService.listUsers(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(userRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: filters.tenant_id,
          status: filters.status
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply search filter with OR clause', async () => {
      const filters = { search: 'john' };
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(2);

      await userService.listUsers(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(userRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { email: { contains: 'john' } },
            { phone: { contains: 'john' } },
            { position_title: { contains: 'john' } }
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(42);

      const result = await userService.listUsers({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(userRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10, // skip: (2-1) * 10
        10,
        expect.any(Object)
      );
    });

    it('should apply custom sorting', async () => {
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(2);

      await userService.listUsers({}, 1, 20, 'email', 'desc', 'user-id', '127.0.0.1');

      expect(userRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { email: 'desc' }
      );
    });

    it('should use default sorting when sortBy not provided', async () => {
      userRepository.findMany.mockResolvedValue(mockUsers);
      userRepository.count.mockResolvedValue(2);

      await userService.listUsers({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(userRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'desc' }
      );
    });

    it('should handle repository errors', async () => {
      userRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        userService.listUsers({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      userRepository.findMany.mockRejectedValue(httpError);

      await expect(
        userService.listUsers({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('getUserById', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const mockUser = {
      id: userId,
      email: 'test@example.com',
      status: 'ACTIVE'
    };

    it('should get user by ID', async () => {
      userRepository.findById.mockResolvedValue(mockUser);

      const result = await userService.getUserById(userId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockUser);
      expect(userRepository.findById).toHaveBeenCalledWith(
        userId,
        expect.objectContaining({
          facility: expect.objectContaining({
            select: expect.objectContaining({
              id: true,
              human_friendly_id: true,
              name: true,
            }),
          }),
        })
      );
      expect(userRepository.findById.mock.calls[0][1].facility.select.code).toBeUndefined();
      expect(userRepository.findById.mock.calls[0][1].facility.select.slug).toBeUndefined();
    });

    it('should throw HttpError if user not found', async () => {
      userRepository.findById.mockResolvedValue(null);

      await expect(
        userService.getUserById(userId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        userService.getUserById(userId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      userRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        userService.getUserById(userId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      userRepository.findById.mockRejectedValue(httpError);

      await expect(
        userService.getUserById(userId, 'requester-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('createUser', () => {
    const userData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      position_title: 'Charge Nurse',
      email: 'newuser@example.com',
      password_hash: '$2b$10$abcdefghijklmnopqrstuvwxyz',
      status: 'ACTIVE'
    };

    const createdUser = {
      id: '550e8400-e29b-41d4-a716-446655440001',
      ...userData,
      created_at: new Date(),
      updated_at: new Date()
    };

    it('should create new user', async () => {
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockResolvedValue(true);

      const result = await userService.createUser(userData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(createdUser);
      expect(userRepository.create).toHaveBeenCalledWith(userData);
    });

    it('should trim position_title before persistence', async () => {
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockResolvedValue(true);

      await userService.createUser(
        { ...userData, position_title: '  Charge Nurse  ' },
        'creator-id',
        '127.0.0.1'
      );

      expect(userRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ position_title: 'Charge Nurse' })
      );
    });

    it('should normalize permission_ids before persistence', async () => {
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockResolvedValue(true);

      await userService.createUser(
        {
          ...userData,
          permission_ids: [
            '550e8400-e29b-41d4-a716-446655440010',
            ' 550e8400-e29b-41d4-a716-446655440010 ',
            '550e8400-e29b-41d4-a716-446655440011',
          ],
        },
        'creator-id',
        '127.0.0.1'
      );

      expect(userRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          permission_ids: [
            '550e8400-e29b-41d4-a716-446655440010',
            '550e8400-e29b-41d4-a716-446655440011',
          ],
        })
      );
    });

    it('should hash non-bcrypt password_hash values before persistence', async () => {
      const plainPasswordPayload = {
        ...userData,
        password_hash: 'PlainPassword123!',
      };
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockResolvedValue(true);

      await userService.createUser(plainPasswordPayload, 'creator-id', '127.0.0.1');

      expect(hashPassword).toHaveBeenCalledWith('PlainPassword123!');
      expect(userRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          password_hash: '$2b$10$hashedpasswordplaceholder',
        })
      );
    });

    it('should create audit log for user creation', async () => {
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockResolvedValue(true);

      await userService.createUser(userData, 'creator-id', '127.0.0.1');

      // Wait for non-blocking audit log
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'creator-id',
        action: 'CREATE',
        entity: 'user',
        entity_id: createdUser.id,
        diff: { after: createdUser },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      userRepository.create.mockResolvedValue(createdUser);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await userService.createUser(userData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(createdUser);
    });

    it('should require position_title on create', async () => {
      await expect(
        userService.createUser(
          { ...userData, position_title: '   ' },
          'creator-id',
          '127.0.0.1'
        )
      ).rejects.toThrow(HttpError);
    });

    it('should handle repository errors', async () => {
      userRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        userService.createUser(userData, 'creator-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unique_field', 409);
      userRepository.create.mockRejectedValue(httpError);

      await expect(
        userService.createUser(userData, 'creator-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('updateUser', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'INACTIVE' };
    const beforeUser = {
      id: userId,
      email: 'test@example.com',
      status: 'ACTIVE'
    };
    const afterUser = {
      id: userId,
      email: 'test@example.com',
      status: 'INACTIVE'
    };

    it('should update user', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockResolvedValue(afterUser);
      createAuditLog.mockResolvedValue(true);

      const result = await userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1');

      expect(result).toEqual(afterUser);
      expect(userRepository.findById.mock.calls[0][1].facility.select.code).toBeUndefined();
      expect(userRepository.findById.mock.calls[0][1].facility.select.slug).toBeUndefined();
      expect(userRepository.update).toHaveBeenCalledWith(userId, updateData);
    });

    it('should trim position_title on update', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockResolvedValue({
        ...afterUser,
        position_title: 'Head Nurse'
      });
      createAuditLog.mockResolvedValue(true);

      await userService.updateUser(
        userId,
        { position_title: '  Head Nurse  ' },
        'updater-id',
        '127.0.0.1'
      );

      expect(userRepository.update).toHaveBeenCalledWith(userId, {
        position_title: 'Head Nurse'
      });
    });

    it('should normalize permission_ids on update', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockResolvedValue(afterUser);
      createAuditLog.mockResolvedValue(true);

      await userService.updateUser(
        userId,
        {
          permission_ids: [
            '550e8400-e29b-41d4-a716-446655440010',
            ' 550e8400-e29b-41d4-a716-446655440010 ',
            '550e8400-e29b-41d4-a716-446655440011',
          ],
        },
        'updater-id',
        '127.0.0.1'
      );

      expect(userRepository.update).toHaveBeenCalledWith(userId, {
        permission_ids: [
          '550e8400-e29b-41d4-a716-446655440010',
          '550e8400-e29b-41d4-a716-446655440011',
        ],
      });
    });

    it('should throw HttpError if user not found', async () => {
      userRepository.findById.mockResolvedValue(null);

      await expect(
        userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404
      });
    });

    it('should create audit log with before and after states', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockResolvedValue(afterUser);
      createAuditLog.mockResolvedValue(true);

      await userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1');

      // Wait for non-blocking audit log
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'updater-id',
        action: 'UPDATE',
        entity: 'user',
        entity_id: userId,
        diff: { before: beforeUser, after: afterUser },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockResolvedValue(afterUser);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1');

      expect(result).toEqual(afterUser);
    });

    it('should handle repository errors', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      userRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      userRepository.findById.mockResolvedValue(beforeUser);
      const httpError = new HttpError('errors.database.unique_field', 409);
      userRepository.update.mockRejectedValue(httpError);

      await expect(
        userService.updateUser(userId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('deleteUser', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const mockUser = {
      id: userId,
      email: 'test@example.com',
      status: 'ACTIVE'
    };

    it('should soft delete user', async () => {
      userRepository.findById.mockResolvedValue(mockUser);
      userRepository.softDelete.mockResolvedValue({ ...mockUser, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await userService.deleteUser(userId, 'deleter-id', '127.0.0.1');

      expect(userRepository.softDelete).toHaveBeenCalledWith(userId);
    });

    it('should throw HttpError if user not found', async () => {
      userRepository.findById.mockResolvedValue(null);

      await expect(
        userService.deleteUser(userId, 'deleter-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        userService.deleteUser(userId, 'deleter-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404
      });
    });

    it('should create audit log with before state', async () => {
      userRepository.findById.mockResolvedValue(mockUser);
      userRepository.softDelete.mockResolvedValue({ ...mockUser, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await userService.deleteUser(userId, 'deleter-id', '127.0.0.1');

      // Wait for non-blocking audit log
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'deleter-id',
        action: 'DELETE',
        entity: 'user',
        entity_id: userId,
        diff: { before: mockUser },
        ip_address: '127.0.0.1'
      });
    });

    it('should not fail if audit log fails', async () => {
      userRepository.findById.mockResolvedValue(mockUser);
      userRepository.softDelete.mockResolvedValue({ ...mockUser, deleted_at: new Date() });
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      await expect(
        userService.deleteUser(userId, 'deleter-id', '127.0.0.1')
      ).resolves.not.toThrow();
    });

    it('should handle repository errors', async () => {
      userRepository.findById.mockResolvedValue(mockUser);
      userRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        userService.deleteUser(userId, 'deleter-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      userRepository.findById.mockResolvedValue(mockUser);
      const httpError = new HttpError('errors.user.not_found', 404);
      userRepository.softDelete.mockRejectedValue(httpError);

      await expect(
        userService.deleteUser(userId, 'deleter-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });
});
