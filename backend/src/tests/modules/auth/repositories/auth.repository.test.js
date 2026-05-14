/**
 * Auth repository tests
 *
 * @module tests/modules/auth/repositories
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  $connect: jest.fn(),
  $disconnect: jest.fn(),
  user: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  },
  user_session: {
    create: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn()
  },
  user_role: {
    findMany: jest.fn()
  },
  facility: {
    findMany: jest.fn()
  },
  verification_token: {
    create: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn()
  }
}));

const {
  findUserByEmailAndTenant,
  findUserByPhoneAndTenant,
  findUserById,
  findUserByEmail,
  findUserByPhone,
  findUsersByIdentifier,
  createUser,
  updateUserPassword,
  updateUserStatus,
  createSession,
  findSessionByRefreshToken,
  revokeSession,
  revokeAllUserSessions,
  createVerificationToken,
  findVerificationToken,
  markTokenAsUsed,
  deleteExpiredTokens,
  getUserFacilities,
} = require('@repositories/auth/auth.repository');

const prisma = require('@prisma/client');

describe('Auth Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findUserByEmailAndTenant', () => {
    it('should find user by email and tenant', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: 'tenant-123'
      };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await findUserByEmailAndTenant('test@example.com', 'tenant-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          email: 'test@example.com',
          tenant_id: 'tenant-123',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });

    it('should return null if user not found', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      const result = await findUserByEmailAndTenant('test@example.com', 'tenant-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.user.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findUserByEmailAndTenant('test@example.com', 'tenant-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('falls back when direct permission tables are missing', async () => {
      const missingTableError = new Error('The table `user_permission` does not exist');
      missingTableError.code = 'P2021';

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: 'tenant-123',
        roles: [],
      };

      prisma.user.findFirst
        .mockRejectedValueOnce(missingTableError)
        .mockResolvedValueOnce(mockUser);

      const result = await findUserByEmailAndTenant('test@example.com', 'tenant-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledTimes(2);
      expect(prisma.user.findFirst.mock.calls[1][0].include.permissions).toBeUndefined();
    });
  });

  describe('findUserByPhoneAndTenant', () => {
    it('should find user by phone and tenant', async () => {
      const mockUser = {
        id: 'user-123',
        phone: '256701234567',
        tenant_id: 'tenant-123'
      };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await findUserByPhoneAndTenant('256701234567', 'tenant-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          phone: '256701234567',
          tenant_id: 'tenant-123',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });

    it('should return null if phone user not found', async () => {
      prisma.user.findFirst.mockResolvedValue(null);

      const result = await findUserByPhoneAndTenant('256701234567', 'tenant-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.user.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findUserByPhoneAndTenant('256701234567', 'tenant-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('falls back when direct permission tables are missing', async () => {
      const missingTableError = new Error('The table `user_permission` does not exist');
      missingTableError.code = 'P2021';

      const mockUser = {
        id: 'user-123',
        phone: '256701234567',
        tenant_id: 'tenant-123',
        roles: [],
      };

      prisma.user.findFirst
        .mockRejectedValueOnce(missingTableError)
        .mockResolvedValueOnce(mockUser);

      const result = await findUserByPhoneAndTenant('256701234567', 'tenant-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledTimes(2);
      expect(prisma.user.findFirst.mock.calls[1][0].include.permissions).toBeUndefined();
    });
  });

  describe('findUserById', () => {
    it('should find user by ID', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com'
      };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await findUserById('user-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'user-123',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });
  });

  describe('createUser', () => {
    it('should create a new user', async () => {
      const userData = {
        email: 'newuser@example.com',
        password_hash: 'hashedpassword',
        tenant_id: 'tenant-123',
        position_title: 'TENANT_ADMIN'
      };
      const mockCreatedUser = { id: 'user-123', ...userData };
      prisma.user.create.mockResolvedValue(mockCreatedUser);

      const result = await createUser(userData);

      expect(result).toEqual(mockCreatedUser);
      expect(prisma.user.create).toHaveBeenCalledWith({
        data: userData,
        include: expect.any(Object)
      });
    });

    it('should throw HttpError 409 on duplicate email', async () => {
      const userData = {
        email: 'duplicate@example.com',
        password_hash: 'hashedpassword',
        tenant_id: 'tenant-123',
        position_title: 'TENANT_ADMIN'
      };
      const duplicateError = new Error('Unique constraint failed');
      duplicateError.code = 'P2002';
      prisma.user.create.mockRejectedValue(duplicateError);

      await expect(createUser(userData))
        .rejects
        .toThrow(HttpError);
      await expect(createUser(userData))
        .rejects
        .toMatchObject({ statusCode: 409 });
    });
  });

  describe('updateUserPassword', () => {
    it('should update user password', async () => {
      const mockUpdatedUser = {
        id: 'user-123',
        password_hash: 'newhashedpassword'
      };
      prisma.user.update.mockResolvedValue(mockUpdatedUser);

      const result = await updateUserPassword('user-123', 'newhashedpassword');

      expect(result).toEqual(mockUpdatedUser);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-123' },
        data: {
          password_hash: 'newhashedpassword',
          updated_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError 404 if user not found', async () => {
      const notFoundError = new Error('Record not found');
      notFoundError.code = 'P2025';
      prisma.user.update.mockRejectedValue(notFoundError);

      await expect(updateUserPassword('user-123', 'newhashedpassword'))
        .rejects
        .toThrow(HttpError);
      await expect(updateUserPassword('user-123', 'newhashedpassword'))
        .rejects
        .toMatchObject({ statusCode: 404 });
    });
  });

  describe('createSession', () => {
    it('should create a new session', async () => {
      const sessionData = {
        user_id: 'user-123',
        refresh_token_hash: 'tokenhash',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla',
        expires_at: new Date()
      };
      const mockCreatedSession = { id: 'session-123', ...sessionData };
      prisma.user_session.create.mockResolvedValue(mockCreatedSession);

      const result = await createSession(sessionData);

      expect(result).toEqual(mockCreatedSession);
      expect(prisma.user_session.create).toHaveBeenCalledWith({
        data: sessionData
      });
    });
  });

  describe('findSessionByRefreshToken', () => {
    it('should find session by refresh token hash', async () => {
      const mockSession = {
        id: 'session-123',
        refresh_token_hash: 'tokenhash',
        user: { id: 'user-123' }
      };
      prisma.user_session.findFirst.mockResolvedValue(mockSession);

      const result = await findSessionByRefreshToken('tokenhash');

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.findFirst).toHaveBeenCalledWith({
        where: {
          refresh_token_hash: 'tokenhash',
          revoked_at: null,
          deleted_at: null,
          expires_at: {
            gt: expect.any(Date)
          }
        },
        include: expect.any(Object)
      });
    });

    it('should return null if session not found or expired', async () => {
      prisma.user_session.findFirst.mockResolvedValue(null);

      const result = await findSessionByRefreshToken('tokenhash');

      expect(result).toBeNull();
    });

    it('falls back when direct permission tables are missing', async () => {
      const missingTableError = new Error('The table `user_permission` does not exist');
      missingTableError.code = 'P2021';

      const mockSession = {
        id: 'session-123',
        refresh_token_hash: 'tokenhash',
        user: {
          id: 'user-123',
          roles: [],
        },
      };

      prisma.user_session.findFirst
        .mockRejectedValueOnce(missingTableError)
        .mockResolvedValueOnce(mockSession);

      const result = await findSessionByRefreshToken('tokenhash');

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.findFirst).toHaveBeenCalledTimes(2);
      expect(prisma.user_session.findFirst.mock.calls[1][0].include.user.include.permissions).toBeUndefined();
    });

    it('should retry once on transient connection timeout', async () => {
      const transientPoolTimeout = new Error('pool timeout');
      transientPoolTimeout.code = 'P2010';
      transientPoolTimeout.meta = {
        driverAdapterError: {
          message: 'failed to retrieve a connection from pool after 5001ms'
        }
      };
      const mockSession = {
        id: 'session-123',
        refresh_token_hash: 'tokenhash',
        user: { id: 'user-123' }
      };

      prisma.user_session.findFirst
        .mockRejectedValueOnce(transientPoolTimeout)
        .mockResolvedValueOnce(mockSession);

      const result = await findSessionByRefreshToken('tokenhash');

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.findFirst).toHaveBeenCalledTimes(2);
      expect(prisma.$disconnect).toHaveBeenCalledTimes(1);
      expect(prisma.$connect).toHaveBeenCalledTimes(1);
    });
  });

  describe('revokeSession', () => {
    it('should revoke a session', async () => {
      const mockRevokedSession = {
        id: 'session-123',
        revoked_at: new Date()
      };
      prisma.user_session.update.mockResolvedValue(mockRevokedSession);

      const result = await revokeSession('session-123');

      expect(result).toEqual(mockRevokedSession);
      expect(prisma.user_session.update).toHaveBeenCalledWith({
        where: { id: 'session-123' },
        data: {
          revoked_at: expect.any(Date),
          updated_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError 404 if session not found', async () => {
      const notFoundError = new Error('Record not found');
      notFoundError.code = 'P2025';
      prisma.user_session.update.mockRejectedValue(notFoundError);

      await expect(revokeSession('session-123'))
        .rejects
        .toThrow(HttpError);
      await expect(revokeSession('session-123'))
        .rejects
        .toMatchObject({ statusCode: 404 });
    });
  });

  describe('revokeAllUserSessions', () => {
    it('should revoke all user sessions', async () => {
      const mockResult = { count: 3 };
      prisma.user_session.updateMany.mockResolvedValue(mockResult);

      const result = await revokeAllUserSessions('user-123');

      expect(result).toEqual(mockResult);
      expect(prisma.user_session.updateMany).toHaveBeenCalledWith({
        where: {
          user_id: 'user-123',
          revoked_at: null,
          deleted_at: null
        },
        data: {
          revoked_at: expect.any(Date),
          updated_at: expect.any(Date)
        }
      });
    });

    it('should handle no sessions to revoke', async () => {
      const mockResult = { count: 0 };
      prisma.user_session.updateMany.mockResolvedValue(mockResult);

      const result = await revokeAllUserSessions('user-123');

      expect(result).toEqual(mockResult);
    });
  });

  describe('createVerificationToken', () => {
    it('should create a verification token', async () => {
      const tokenData = {
        user_id: 'user-123',
        token_hash: 'tokenhash',
        type: 'EMAIL_VERIFICATION',
        expires_at: new Date()
      };
      const mockToken = { id: 'token-123', ...tokenData };
      prisma.verification_token.create.mockResolvedValue(mockToken);

      const result = await createVerificationToken(tokenData);

      expect(result).toEqual(mockToken);
      expect(prisma.verification_token.create).toHaveBeenCalledWith({
        data: tokenData
      });
    });
  });

  describe('findVerificationToken', () => {
    it('should find verification token by hash and type', async () => {
      const mockToken = {
        id: 'token-123',
        token_hash: 'tokenhash',
        type: 'EMAIL_VERIFICATION',
        user: { id: 'user-123' }
      };
      prisma.verification_token.findFirst.mockResolvedValue(mockToken);

      const result = await findVerificationToken('tokenhash', 'EMAIL_VERIFICATION');

      expect(result).toEqual(mockToken);
      expect(prisma.verification_token.findFirst).toHaveBeenCalledWith({
        where: {
          token_hash: 'tokenhash',
          type: 'EMAIL_VERIFICATION',
          used_at: null,
          deleted_at: null,
          expires_at: {
            gt: expect.any(Date)
          }
        },
        include: expect.any(Object)
      });
    });
  });

  describe('markTokenAsUsed', () => {
    it('should mark token as used', async () => {
      const mockToken = {
        id: 'token-123',
        used_at: new Date()
      };
      prisma.verification_token.update.mockResolvedValue(mockToken);

      const result = await markTokenAsUsed('token-123');

      expect(result).toEqual(mockToken);
      expect(prisma.verification_token.update).toHaveBeenCalledWith({
        where: { id: 'token-123' },
        data: {
          used_at: expect.any(Date),
          updated_at: expect.any(Date)
        }
      });
    });
  });

  describe('deleteExpiredTokens', () => {
    it('should delete expired tokens for user', async () => {
      const mockResult = { count: 2 };
      prisma.verification_token.updateMany.mockResolvedValue(mockResult);

      const result = await deleteExpiredTokens('user-123', 'EMAIL_VERIFICATION');

      expect(result).toEqual(mockResult);
      expect(prisma.verification_token.updateMany).toHaveBeenCalledWith({
        where: {
          user_id: 'user-123',
          type: 'EMAIL_VERIFICATION',
          deleted_at: null
        },
        data: {
          deleted_at: expect.any(Date),
          updated_at: expect.any(Date)
        }
      });
    });
  });

  describe('updateUserStatus', () => {
    it('should update user status', async () => {
      const mockUser = {
        id: 'user-123',
        status: 'ACTIVE'
      };
      prisma.user.update.mockResolvedValue(mockUser);

      const result = await updateUserStatus('user-123', 'ACTIVE');

      expect(result).toEqual(mockUser);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'user-123' },
        data: {
          status: 'ACTIVE',
          updated_at: expect.any(Date)
        }
      });
    });
  });

  describe('findUserByEmail', () => {
    it('should find user by email', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com'
      };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await findUserByEmail('test@example.com');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          email: 'test@example.com',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });
  });

  describe('findUserByPhone', () => {
    it('should find user by phone', async () => {
      const mockUser = {
        id: 'user-123',
        phone: '+1234567890'
      };
      prisma.user.findFirst.mockResolvedValue(mockUser);

      const result = await findUserByPhone('+1234567890');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          phone: '+1234567890',
          deleted_at: null
        },
        include: expect.any(Object)
      });
    });

    it('falls back when direct permission tables are missing', async () => {
      const missingTableError = new Error('The table `user_permission` does not exist');
      missingTableError.code = 'P2021';

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        roles: [],
      };

      prisma.user.findFirst
        .mockRejectedValueOnce(missingTableError)
        .mockResolvedValueOnce(mockUser);

      const result = await findUserById('user-123');

      expect(result).toEqual(mockUser);
      expect(prisma.user.findFirst).toHaveBeenCalledTimes(2);
      expect(prisma.user.findFirst.mock.calls[1][0].include.permissions).toBeUndefined();
    });
  });

  describe('findUsersByIdentifier', () => {
    it('should query by normalized email with tenant projection', async () => {
      const mockUsers = [
        {
          id: 'user-1',
          email: 'test@example.com',
          tenant_id: 'tenant-1',
          tenant: { id: 'tenant-1', name: 'Tenant 1', slug: 'tenant-1' },
        },
      ];
      prisma.user.findMany.mockResolvedValue(mockUsers);

      const result = await findUsersByIdentifier('TEST@EXAMPLE.COM');

      expect(result).toEqual(mockUsers);
      expect(prisma.user.findMany).toHaveBeenCalledWith({
        where: {
          email: 'test@example.com',
          deleted_at: null,
        },
        include: {
          tenant: {
            select: {
              id: true,
              name: true,
              slug: true,
            },
          },
        },
        orderBy: {
          created_at: 'desc',
        },
      });
    });

    it('should fallback when optional schema fields are missing', async () => {
      const missingColumnError = new Error('Column `tenant.slug` does not exist');
      missingColumnError.code = 'P2022';
      prisma.user.findMany
        .mockRejectedValueOnce(missingColumnError)
        .mockResolvedValueOnce([
          {
            id: 'user-1',
            email: 'test@example.com',
            tenant_id: 'tenant-1',
            tenant: { id: 'tenant-1', name: 'Tenant 1' },
          },
        ]);

      const result = await findUsersByIdentifier('TEST@EXAMPLE.COM');

      expect(result).toEqual([
        {
          id: 'user-1',
          email: 'test@example.com',
          tenant_id: 'tenant-1',
          tenant: { id: 'tenant-1', name: 'Tenant 1' },
        },
      ]);
      expect(prisma.user.findMany).toHaveBeenNthCalledWith(1, {
        where: {
          email: 'test@example.com',
          deleted_at: null,
        },
        include: {
          tenant: {
            select: {
              id: true,
              name: true,
              slug: true,
            },
          },
        },
        orderBy: {
          created_at: 'desc',
        },
      });
      expect(prisma.user.findMany).toHaveBeenNthCalledWith(2, {
        where: {
          email: 'test@example.com',
        },
        include: {
          tenant: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });
    });

    it('should retry once on transient connection timeout', async () => {
      const transientPoolTimeout = new Error('pool timeout');
      transientPoolTimeout.code = 'P2010';
      transientPoolTimeout.meta = {
        driverAdapterError: {
          message: 'pool timeout: failed to retrieve a connection from pool'
        }
      };
      const mockUsers = [
        {
          id: 'user-1',
          email: 'test@example.com',
          tenant_id: 'tenant-1',
          tenant: { id: 'tenant-1', name: 'Tenant 1', slug: 'tenant-1' },
        },
      ];

      prisma.user.findMany
        .mockRejectedValueOnce(transientPoolTimeout)
        .mockResolvedValueOnce(mockUsers);

      const result = await findUsersByIdentifier('test@example.com');

      expect(result).toEqual(mockUsers);
      expect(prisma.user.findMany).toHaveBeenCalledTimes(2);
      expect(prisma.$disconnect).toHaveBeenCalledTimes(1);
      expect(prisma.$connect).toHaveBeenCalledTimes(1);
    });
  });

  describe('getUserFacilities', () => {
    it('should return facilities using minimal schema-safe selects', async () => {
      prisma.user.findFirst.mockResolvedValue({
        facility_id: 'facility-1',
      });
      prisma.user_role.findMany.mockResolvedValue([
        { facility_id: 'facility-2', role: { facility_id: 'facility-3' } },
      ]);
      prisma.facility.findMany.mockResolvedValue([
        { id: 'facility-1', name: 'Main', facility_type: 'HOSPITAL', tenant_id: 'tenant-1', is_active: true },
      ]);

      const result = await getUserFacilities('user-1', 'tenant-1');

      expect(result).toEqual([
        { id: 'facility-1', name: 'Main', facility_type: 'HOSPITAL', tenant_id: 'tenant-1', is_active: true },
      ]);
      expect(prisma.user.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'user-1',
          tenant_id: 'tenant-1',
          deleted_at: null,
        },
        select: {
          facility_id: true,
        },
      });
      expect(prisma.facility.findMany).toHaveBeenCalledWith({
        where: {
          id: { in: expect.arrayContaining(['facility-1', 'facility-2', 'facility-3']) },
          tenant_id: 'tenant-1',
          deleted_at: null,
          is_active: true,
        },
        select: {
          id: true,
          tenant_id: true,
          name: true,
          facility_type: true,
          is_active: true,
        },
      });
    });

    it('should return empty array when user has no facility assignments', async () => {
      prisma.user.findFirst.mockResolvedValue({ facility_id: null });
      prisma.user_role.findMany.mockResolvedValue([]);

      const result = await getUserFacilities('user-1', 'tenant-1');

      expect(result).toEqual([]);
      expect(prisma.facility.findMany).not.toHaveBeenCalled();
    });
  });
});
