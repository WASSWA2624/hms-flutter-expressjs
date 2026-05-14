/**
 * OAuth Account service tests
 *
 * @module tests/modules/oauth-account/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/oauth-account/oauth-account.repository');
jest.mock('@lib/audit');

const oauthAccountRepository = require('@repositories/oauth-account/oauth-account.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listOAuthAccounts,
  getOAuthAccountById,
  getOAuthAccountsByUserId,
  createOAuthAccount,
  updateOAuthAccount,
  deleteOAuthAccount
} = require('@services/oauth-account/oauth-account.service');

describe('OAuth Account Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listOAuthAccounts', () => {
    it('should list OAuth accounts with default pagination', async () => {
      const mockOAuthAccounts = [
        { id: 'oauth-1', user_id: 'user-123', provider: 'google' },
        { id: 'oauth-2', user_id: 'user-123', provider: 'microsoft' }
      ];
      oauthAccountRepository.findMany.mockResolvedValue(mockOAuthAccounts);
      oauthAccountRepository.count.mockResolvedValue(10);

      const result = await listOAuthAccounts({}, 1, 20);

      expect(result.oauth_accounts).toEqual(mockOAuthAccounts);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by user_id', async () => {
      const mockOAuthAccounts = [{ id: 'oauth-1', user_id: 'user-123', provider: 'google' }];
      oauthAccountRepository.findMany.mockResolvedValue(mockOAuthAccounts);
      oauthAccountRepository.count.mockResolvedValue(1);

      await listOAuthAccounts({ user_id: 'user-123' }, 1, 20);

      expect(oauthAccountRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });
  });

  describe('getOAuthAccountById', () => {
    it('should get OAuth account by ID', async () => {
      const mockOAuthAccount = { 
        id: 'oauth-123', 
        user_id: 'user-123', 
        provider: 'google'
      };
      oauthAccountRepository.findById.mockResolvedValue(mockOAuthAccount);

      const result = await getOAuthAccountById('oauth-123');

      expect(result).toEqual(mockOAuthAccount);
    });

    it('should throw HttpError if OAuth account not found', async () => {
      oauthAccountRepository.findById.mockResolvedValue(null);

      await expect(getOAuthAccountById('oauth-999'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getOAuthAccountsByUserId', () => {
    it('should get OAuth accounts by user ID', async () => {
      const mockOAuthAccounts = [
        { id: 'oauth-1', user_id: 'user-123', provider: 'google' },
        { id: 'oauth-2', user_id: 'user-123', provider: 'microsoft' }
      ];
      oauthAccountRepository.findMany.mockResolvedValue(mockOAuthAccounts);

      const result = await getOAuthAccountsByUserId('user-123');

      expect(result).toEqual(mockOAuthAccounts);
      expect(oauthAccountRepository.findMany).toHaveBeenCalledWith({ user_id: 'user-123' });
    });
  });

  describe('createOAuthAccount', () => {
    it('should create new OAuth account', async () => {
      const newOAuthAccount = {
        user_id: 'user-123',
        provider: 'google',
        provider_user_id: 'google-123'
      };
      const mockCreated = { id: 'oauth-123', ...newOAuthAccount };
      oauthAccountRepository.create.mockResolvedValue(mockCreated);

      const result = await createOAuthAccount(newOAuthAccount, 'admin-123', '127.0.0.1');

      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateOAuthAccount', () => {
    it('should update OAuth account', async () => {
      const before = { id: 'oauth-123', provider: 'google' };
      const after = { id: 'oauth-123', provider: 'microsoft' };

      oauthAccountRepository.findById.mockResolvedValue(before);
      oauthAccountRepository.update.mockResolvedValue(after);

      const result = await updateOAuthAccount('oauth-123', { provider: 'microsoft' }, 'admin-123', '127.0.0.1');

      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if OAuth account not found', async () => {
      oauthAccountRepository.findById.mockResolvedValue(null);

      await expect(updateOAuthAccount('oauth-999', {}, 'admin-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteOAuthAccount', () => {
    it('should soft delete OAuth account', async () => {
      const mockOAuthAccount = { id: 'oauth-123', provider: 'google' };
      oauthAccountRepository.findById.mockResolvedValue(mockOAuthAccount);
      oauthAccountRepository.softDelete.mockResolvedValue({});

      await deleteOAuthAccount('oauth-123', 'admin-123', '127.0.0.1');

      expect(oauthAccountRepository.softDelete).toHaveBeenCalledWith('oauth-123');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
