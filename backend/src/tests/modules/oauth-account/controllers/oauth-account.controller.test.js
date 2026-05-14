/**
 * OAuth Account controller tests
 *
 * @module tests/modules/oauth-account/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/oauth-account/oauth-account.service');
jest.mock('@lib/response');

const oauthAccountService = require('@services/oauth-account/oauth-account.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listOAuthAccounts,
  getOAuthAccountById,
  getOAuthAccountsByUserId,
  createOAuthAccount,
  updateOAuthAccount,
  deleteOAuthAccount
} = require('@controllers/oauth-account/oauth-account.controller');

describe('OAuth Account Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123' },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listOAuthAccounts', () => {
    it('should list OAuth accounts with default pagination', async () => {
      const mockResult = {
        oauth_accounts: [
          { id: 'oauth-1', user_id: 'user-123', provider: 'google' },
          { id: 'oauth-2', user_id: 'user-123', provider: 'microsoft' }
        ],
        pagination: { page: 1, limit: 20, total: 2, totalPages: 1 }
      };
      oauthAccountService.listOAuthAccounts.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };
      await listOAuthAccounts(req, res);

      expect(oauthAccountService.listOAuthAccounts).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getOAuthAccountById', () => {
    it('should get OAuth account by ID', async () => {
      const mockOAuthAccount = { 
        id: 'oauth-123', 
        user_id: 'user-123', 
        provider: 'google'
      };
      oauthAccountService.getOAuthAccountById.mockResolvedValue(mockOAuthAccount);
      sendSuccess.mockImplementation((res, code, message, data) => {
        res.status(code).json({ message, data });
      });

      req.params = { id: 'oauth-123' };
      await getOAuthAccountById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.oauth_account.get.success',
        mockOAuthAccount
      );
    });
  });

  describe('getOAuthAccountsByUserId', () => {
    it('should get OAuth accounts by user ID', async () => {
      const mockOAuthAccounts = [
        { id: 'oauth-1', user_id: 'user-123', provider: 'google' }
      ];
      oauthAccountService.getOAuthAccountsByUserId.mockResolvedValue(mockOAuthAccounts);
      sendSuccess.mockImplementation((res, code, message, data) => {
        res.status(code).json({ message, data });
      });

      req.params = { userId: 'user-123' };
      await getOAuthAccountsByUserId(req, res);

      expect(sendSuccess).toHaveBeenCalled();
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
      oauthAccountService.createOAuthAccount.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation((res, code, message, data) => {
        res.status(code).json({ message, data });
      });

      req.body = newOAuthAccount;
      await createOAuthAccount(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.oauth_account.create.success',
        mockCreated
      );
    });
  });

  describe('updateOAuthAccount', () => {
    it('should update OAuth account', async () => {
      const updateData = { provider: 'microsoft' };
      const mockUpdated = { id: 'oauth-123', provider: 'microsoft' };
      oauthAccountService.updateOAuthAccount.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation((res, code, message, data) => {
        res.status(code).json({ message, data });
      });

      req.params = { id: 'oauth-123' };
      req.body = updateData;
      await updateOAuthAccount(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteOAuthAccount', () => {
    it('should soft delete OAuth account', async () => {
      oauthAccountService.deleteOAuthAccount.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'oauth-123' };
      await deleteOAuthAccount(req, res);

      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
