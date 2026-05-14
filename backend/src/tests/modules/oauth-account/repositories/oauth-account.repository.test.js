/**
 * OAuth Account repository tests
 *
 * @module tests/modules/oauth-account/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  oauth_account: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/oauth-account/oauth-account.repository');

const prisma = require('@prisma/client');

describe('OAuth Account Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find OAuth account by ID', async () => {
      const mockOAuthAccount = {
        id: 'oauth-123',
        user_id: 'user-123',
        provider: 'google',
        provider_user_id: 'google-123',
        access_token_encrypted: 'encrypted_access',
        refresh_token_encrypted: 'encrypted_refresh',
        expires_at: new Date('2027-01-01'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.oauth_account.findFirst.mockResolvedValue(mockOAuthAccount);

      const result = await findById('oauth-123');

      expect(result).toEqual(mockOAuthAccount);
      expect(prisma.oauth_account.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'oauth-123',
          deleted_at: null
        }
      });
    });

    it('should return null if OAuth account not found', async () => {
      prisma.oauth_account.findFirst.mockResolvedValue(null);

      const result = await findById('oauth-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.oauth_account.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('oauth-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many OAuth accounts with default pagination', async () => {
      const mockOAuthAccounts = [
        { id: 'oauth-1', user_id: 'user-123', provider: 'google' },
        { id: 'oauth-2', user_id: 'user-123', provider: 'microsoft' }
      ];
      prisma.oauth_account.findMany.mockResolvedValue(mockOAuthAccounts);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockOAuthAccounts);
      expect(prisma.oauth_account.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find OAuth accounts with filters', async () => {
      const mockOAuthAccounts = [
        { id: 'oauth-1', user_id: 'user-123', provider: 'google' }
      ];
      prisma.oauth_account.findMany.mockResolvedValue(mockOAuthAccounts);

      const result = await findMany({ user_id: 'user-123', provider: 'google' }, 0, 10);

      expect(result).toEqual(mockOAuthAccounts);
      expect(prisma.oauth_account.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123',
          provider: 'google'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.oauth_account.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count all OAuth accounts', async () => {
      prisma.oauth_account.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.oauth_account.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count OAuth accounts with filters', async () => {
      prisma.oauth_account.count.mockResolvedValue(5);

      const result = await count({ user_id: 'user-123' });

      expect(result).toBe(5);
      expect(prisma.oauth_account.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.oauth_account.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new OAuth account', async () => {
      const newOAuthAccount = {
        user_id: 'user-123',
        provider: 'google',
        provider_user_id: 'google-123',
        access_token_encrypted: 'encrypted_access',
        refresh_token_encrypted: 'encrypted_refresh'
      };
      const mockCreated = {
        id: 'oauth-123',
        ...newOAuthAccount,
        expires_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.oauth_account.create.mockResolvedValue(mockCreated);

      const result = await create(newOAuthAccount);

      expect(result).toEqual(mockCreated);
      expect(prisma.oauth_account.create).toHaveBeenCalledWith({
        data: newOAuthAccount
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['provider', 'provider_user_id'] };
      prisma.oauth_account.create.mockRejectedValue(error);

      await expect(create({ user_id: 'user-123', provider: 'google', provider_user_id: 'google-123' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.oauth_account.create.mockRejectedValue(error);

      await expect(create({ user_id: 'invalid-user', provider: 'google', provider_user_id: 'google-123' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update OAuth account', async () => {
      const updateData = { access_token_encrypted: 'new_token' };
      const mockUpdated = {
        id: 'oauth-123',
        user_id: 'user-123',
        provider: 'google',
        access_token_encrypted: 'new_token',
        updated_at: new Date('2026-01-19')
      };
      prisma.oauth_account.update.mockResolvedValue(mockUpdated);

      const result = await update('oauth-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.oauth_account.update).toHaveBeenCalledWith({
        where: { id: 'oauth-123' },
        data: updateData
      });
    });

    it('should throw HttpError when OAuth account not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.oauth_account.update.mockRejectedValue(error);

      await expect(update('oauth-999', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete OAuth account', async () => {
      const mockDeleted = {
        id: 'oauth-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.oauth_account.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('oauth-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.oauth_account.update).toHaveBeenCalledWith({
        where: { id: 'oauth-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when OAuth account not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.oauth_account.update.mockRejectedValue(error);

      await expect(softDelete('oauth-999'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
