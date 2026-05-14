/**
 * User MFA controller tests
 *
 * @module tests/modules/user-mfa/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/user-mfa/user-mfa.service');
jest.mock('@lib/response');

const userMfaService = require('@services/user-mfa/user-mfa.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listUserMfas,
  getUserMfaById,
  getUserMfasByUserId,
  createUserMfa,
  updateUserMfa,
  deleteUserMfa,
  verifyMfaCode,
  enableMfa,
  disableMfa
} = require('@controllers/user-mfa/user-mfa.controller');

describe('User MFA Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1',
      get: jest.fn((header) => {
        if (header === 'user-agent') return 'Mozilla/5.0';
        return null;
      })
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listUserMfas', () => {
    it('should list user MFAs with default pagination', async () => {
      const mockResult = {
        user_mfas: [
          { id: 'mfa-1', user_id: 'user-123', channel: 'SMS' },
          { id: 'mfa-2', user_id: 'user-123', channel: 'EMAIL' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      userMfaService.listUserMfas.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listUserMfas(req, res);

      expect(userMfaService.listUserMfas).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.user_mfa.list.success',
        mockResult.user_mfas,
        mockResult.pagination
      );
    });

    it('should list user MFAs with filters', async () => {
      const mockResult = {
        user_mfas: [{ id: 'mfa-1', user_id: 'user-123', channel: 'SMS' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      userMfaService.listUserMfas.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { user_id: 'user-123', channel: 'SMS', is_enabled: 'true' };

      await listUserMfas(req, res);

      expect(userMfaService.listUserMfas).toHaveBeenCalled();
    });
  });

  describe('getUserMfaById', () => {
    it('should get user MFA by ID', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', channel: 'SMS' };
      userMfaService.getUserMfaById.mockResolvedValue(mockUserMfa);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };

      await getUserMfaById(req, res);

      expect(userMfaService.getUserMfaById).toHaveBeenCalledWith(
        'mfa-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_mfa.get.success',
        mockUserMfa
      );
    });
  });

  describe('getUserMfasByUserId', () => {
    it('should get user MFAs by user ID', async () => {
      const mockUserMfas = [
        { id: 'mfa-1', user_id: 'user-123', channel: 'SMS' },
        { id: 'mfa-2', user_id: 'user-123', channel: 'EMAIL' }
      ];
      userMfaService.getUserMfasByUserId.mockResolvedValue(mockUserMfas);
      sendSuccess.mockImplementation(() => {});

      req.params = { userId: 'user-123' };

      await getUserMfasByUserId(req, res);

      expect(userMfaService.getUserMfasByUserId).toHaveBeenCalledWith(
        'user-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createUserMfa', () => {
    it('should create new user MFA', async () => {
      const newUserMfa = {
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret',
        is_enabled: true
      };
      const mockCreated = { id: 'mfa-123', ...newUserMfa };
      userMfaService.createUserMfa.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newUserMfa;

      await createUserMfa(req, res);

      expect(userMfaService.createUserMfa).toHaveBeenCalledWith(
        newUserMfa,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.user_mfa.create.success',
        mockCreated
      );
    });
  });

  describe('updateUserMfa', () => {
    it('should update user MFA', async () => {
      const updateData = { is_enabled: false };
      const mockUpdated = { id: 'mfa-123', user_id: 'user-123', is_enabled: false };
      userMfaService.updateUserMfa.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };
      req.body = updateData;

      await updateUserMfa(req, res);

      expect(userMfaService.updateUserMfa).toHaveBeenCalledWith(
        'mfa-123',
        updateData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_mfa.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteUserMfa', () => {
    it('should delete user MFA', async () => {
      userMfaService.deleteUserMfa.mockResolvedValue();
      sendNoContent.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };

      await deleteUserMfa(req, res);

      expect(userMfaService.deleteUserMfa).toHaveBeenCalledWith(
        'mfa-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });

  describe('verifyMfaCode', () => {
    it('should verify MFA code', async () => {
      const mockResult = { verified: true };
      userMfaService.verifyMfaCode.mockResolvedValue(mockResult);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };
      req.body = { code: '123456' };

      await verifyMfaCode(req, res);

      expect(userMfaService.verifyMfaCode).toHaveBeenCalledWith(
        'mfa-123',
        '123456',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_mfa.verify.success',
        mockResult
      );
    });
  });

  describe('enableMfa', () => {
    it('should enable MFA', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: true };
      userMfaService.enableMfa.mockResolvedValue(mockUserMfa);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };

      await enableMfa(req, res);

      expect(userMfaService.enableMfa).toHaveBeenCalledWith(
        'mfa-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_mfa.enable.success',
        mockUserMfa
      );
    });
  });

  describe('disableMfa', () => {
    it('should disable MFA', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: false };
      userMfaService.disableMfa.mockResolvedValue(mockUserMfa);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'mfa-123' };

      await disableMfa(req, res);

      expect(userMfaService.disableMfa).toHaveBeenCalledWith(
        'mfa-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_mfa.disable.success',
        mockUserMfa
      );
    });
  });
});
