/**
 * User repository tests
 *
 * @module tests/modules/user/repositories
 * @description Tests for user repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const userRepository = require('@repositories/user/user.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => {
  const prismaMock = {
    $transaction: jest.fn(async (callback) => callback(prismaMock)),
    user: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      create: jest.fn(),
      update: jest.fn()
    },
    user_permission: {
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  return prismaMock;
});

describe('User Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const mockUser = {
      id: userId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      email: 'test@example.com',
      status: 'ACTIVE'
    };

    it('should find user by ID', async () => {
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await userRepository.findById(userId);

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: { id: userId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if user not found', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      const result = await userRepository.findById(userId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted users', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      await userRepository.findById(userId);

      expect(prisma.user.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { profile: true };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      await userRepository.findById(userId, include);

      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: { id: userId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.findById(userId)).rejects.toThrow(HttpError);
      await expect(userRepository.findById(userId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
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

    it('should find many users with default params', async () => {
      prisma.user.findMany.mockResolvedValue(mockUsers);

      const result = await userRepository.findMany();

      expect(result).toEqual(mockUsers);
      expect(prisma.user.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440002', status: 'ACTIVE' };
      prisma.user.findMany.mockResolvedValue(mockUsers);

      await userRepository.findMany(filters);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.user.findMany.mockResolvedValue(mockUsers);

      await userRepository.findMany({}, 20, 10);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { email: 'asc' };
      prisma.user.findMany.mockResolvedValue(mockUsers);

      await userRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should apply include parameter', async () => {
      const include = { profile: true, sessions: true };
      prisma.user.findMany.mockResolvedValue(mockUsers);

      await userRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.user.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ include })
      );
    });

    it('should return empty array if no users found', async () => {
      prisma.user.findMany.mockResolvedValue([]);

      const result = await userRepository.findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count users with default filters', async () => {
      prisma.user.count.mockResolvedValue(42);

      const result = await userRepository.count();

      expect(result).toBe(42);
      expect(prisma.user.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count users with filters', async () => {
      const filters = { status: 'ACTIVE', tenant_id: '550e8400-e29b-41d4-a716-446655440000' };
      prisma.user.count.mockResolvedValue(10);

      const result = await userRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.user.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should return 0 if no users found', async () => {
      prisma.user.count.mockResolvedValue(0);

      const result = await userRepository.count();

      expect(result).toBe(0);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user.count.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const userData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
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
      prisma.user.create.mockResolvedValue(createdUser);
      prisma.user.findFirst.mockResolvedValue(createdUser);
      prisma.user_permission.findMany.mockResolvedValue([]);

      const result = await userRepository.create(userData);

      expect(result).toEqual(createdUser);
      expect(prisma.user.create).toHaveBeenCalledWith({ data: userData });
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          id: createdUser.id,
          deleted_at: null,
        },
        include: expect.objectContaining({
          facility: expect.objectContaining({
            select: expect.objectContaining({
              id: true,
              human_friendly_id: true,
              name: true,
            }),
          }),
        }),
      });
      expect(prisma.user.findFirst.mock.calls[0][0].include.facility.select.code).toBeUndefined();
      expect(prisma.user.findFirst.mock.calls[0][0].include.facility.select.slug).toBeUndefined();
    });

    it('should create permission links when permission_ids are provided', async () => {
      prisma.user.create.mockResolvedValue(createdUser);
      prisma.user.findFirst.mockResolvedValue(createdUser);
      prisma.user_permission.findMany.mockResolvedValue([]);
      prisma.user_permission.create.mockResolvedValue({});

      await userRepository.create({
        ...userData,
        permission_ids: ['perm-1', 'perm-2'],
      });

      expect(prisma.user_permission.create).toHaveBeenCalledTimes(2);
      expect(prisma.user_permission.create).toHaveBeenNthCalledWith(1, {
        data: {
          user_id: createdUser.id,
          permission_id: 'perm-1',
        },
      });
      expect(prisma.user_permission.create).toHaveBeenNthCalledWith(2, {
        data: {
          user_id: createdUser.id,
          permission_id: 'perm-2',
        },
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['email'] } };
      prisma.user.create.mockRejectedValue(error);

      await expect(userRepository.create(userData)).rejects.toThrow(HttpError);
      await expect(userRepository.create(userData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'tenant_id' } };
      prisma.user.create.mockRejectedValue(error);

      await expect(userRepository.create(userData)).rejects.toThrow(HttpError);
      await expect(userRepository.create(userData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user.create.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.create(userData)).rejects.toThrow(HttpError);
      await expect(userRepository.create(userData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });

    it('should handle P2002 error without meta.target', async () => {
      const error = { code: 'P2002', meta: {} };
      prisma.user.create.mockRejectedValue(error);

      await expect(userRepository.create(userData)).rejects.toThrow(HttpError);
      await expect(userRepository.create(userData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should handle P2003 error without meta.field_name', async () => {
      const error = { code: 'P2003', meta: {} };
      prisma.user.create.mockRejectedValue(error);

      await expect(userRepository.create(userData)).rejects.toThrow(HttpError);
      await expect(userRepository.create(userData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });
  });

  describe('update', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'INACTIVE', phone: '+256700000000' };
    const updatedUser = {
      id: userId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      email: 'test@example.com',
      ...updateData,
      updated_at: new Date()
    };

    it('should update user', async () => {
      prisma.user.update.mockResolvedValue(updatedUser);
      prisma.user.findFirst.mockResolvedValue(updatedUser);

      const result = await userRepository.update(userId, updateData);

      expect(result).toEqual(updatedUser);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: userId },
        data: updateData
      });
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          id: userId,
          deleted_at: null,
        },
        include: expect.objectContaining({
          facility: expect.objectContaining({
            select: expect.objectContaining({
              id: true,
              human_friendly_id: true,
              name: true,
            }),
          }),
        }),
      });
      expect(prisma.user.findFirst.mock.calls[0][0].include.facility.select.code).toBeUndefined();
      expect(prisma.user.findFirst.mock.calls[0][0].include.facility.select.slug).toBeUndefined();
    });

    it('should sync permission assignments on update', async () => {
      prisma.user.findFirst.mockResolvedValue(updatedUser);
      prisma.user_permission.findMany.mockResolvedValue([
        { id: 'up-1', user_id: userId, permission_id: 'perm-1', deleted_at: null },
        { id: 'up-2', user_id: userId, permission_id: 'perm-2', deleted_at: new Date('2025-01-01T00:00:00Z') },
      ]);
      prisma.user_permission.update.mockResolvedValue({});
      prisma.user_permission.create.mockResolvedValue({});

      await userRepository.update(userId, { permission_ids: ['perm-2', 'perm-3'] });

      expect(prisma.user_permission.update).toHaveBeenCalledTimes(2);
      expect(prisma.user_permission.create).toHaveBeenCalledWith({
        data: {
          user_id: userId,
          permission_id: 'perm-3',
        },
      });
    });

    it('should throw HttpError if user not found', async () => {
      const error = { code: 'P2025' };
      prisma.user.update.mockRejectedValue(error);

      await expect(userRepository.update(userId, updateData)).rejects.toThrow(HttpError);
      await expect(userRepository.update(userId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['email'] } };
      prisma.user.update.mockRejectedValue(error);

      await expect(userRepository.update(userId, updateData)).rejects.toThrow(HttpError);
      await expect(userRepository.update(userId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'facility_id' } };
      prisma.user.update.mockRejectedValue(error);

      await expect(userRepository.update(userId, updateData)).rejects.toThrow(HttpError);
      await expect(userRepository.update(userId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user.update.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.update(userId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const userId = '550e8400-e29b-41d4-a716-446655440000';
    const deletedUser = {
      id: userId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      email: 'test@example.com',
      deleted_at: new Date()
    };

    it('should soft delete user', async () => {
      prisma.user.update.mockResolvedValue(deletedUser);
      prisma.user_permission.updateMany.mockResolvedValue({ count: 1 });

      const result = await userRepository.softDelete(userId);

      expect(result).toEqual(deletedUser);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: userId },
        data: { deleted_at: expect.any(Date) }
      });
      expect(prisma.user_permission.updateMany).toHaveBeenCalledWith({
        where: {
          user_id: userId,
          deleted_at: null,
        },
        data: {
          deleted_at: expect.any(Date),
        },
      });
    });

    it('should throw HttpError if user not found', async () => {
      const error = { code: 'P2025' };
      prisma.user.update.mockRejectedValue(error);

      await expect(userRepository.softDelete(userId)).rejects.toThrow(HttpError);
      await expect(userRepository.softDelete(userId)).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user.update.mockRejectedValue(new Error('DB Error'));

      await expect(userRepository.softDelete(userId)).rejects.toThrow(HttpError);
      await expect(userRepository.softDelete(userId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
