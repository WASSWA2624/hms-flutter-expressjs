/**
 * User MFA service tests
 *
 * @module tests/modules/user-mfa/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/user-mfa/user-mfa.repository');
jest.mock('@lib/audit');
jest.mock('@lib/auth/mfa', () => ({
  verifyUserMfaCode: jest.fn(),
}));

const userMfaRepository = require('@repositories/user-mfa/user-mfa.repository');
const { createAuditLog } = require('@lib/audit');
const { verifyUserMfaCode: verifyEncryptedUserMfaCode } = require('@lib/auth/mfa');
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
} = require('@services/user-mfa/user-mfa.service');

describe('User MFA Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    verifyEncryptedUserMfaCode.mockReturnValue(true);
  });

  describe('listUserMfas', () => {
    it('should list user MFAs with default pagination', async () => {
      const mockUserMfas = [
        { id: 'mfa-1', user_id: 'user-123', channel: 'SMS' },
        { id: 'mfa-2', user_id: 'user-123', channel: 'EMAIL' }
      ];
      userMfaRepository.findMany.mockResolvedValue(mockUserMfas);
      userMfaRepository.count.mockResolvedValue(10);

      const result = await listUserMfas({}, 1, 20);

      expect(result.user_mfas).toEqual(mockUserMfas);
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
      const mockUserMfas = [{ id: 'mfa-1', user_id: 'user-123' }];
      userMfaRepository.findMany.mockResolvedValue(mockUserMfas);
      userMfaRepository.count.mockResolvedValue(1);

      await listUserMfas({ user_id: 'user-123' }, 1, 20);

      expect(userMfaRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by channel', async () => {
      const mockUserMfas = [{ id: 'mfa-1', channel: 'SMS' }];
      userMfaRepository.findMany.mockResolvedValue(mockUserMfas);
      userMfaRepository.count.mockResolvedValue(1);

      await listUserMfas({ channel: 'SMS' }, 1, 20);

      expect(userMfaRepository.findMany).toHaveBeenCalledWith(
        { channel: 'SMS' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_enabled', async () => {
      const mockUserMfas = [{ id: 'mfa-1', is_enabled: true }];
      userMfaRepository.findMany.mockResolvedValue(mockUserMfas);
      userMfaRepository.count.mockResolvedValue(1);

      await listUserMfas({ is_enabled: true }, 1, 20);

      expect(userMfaRepository.findMany).toHaveBeenCalledWith(
        { is_enabled: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });
  });

  describe('getUserMfaById', () => {
    it('should get user MFA by ID', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', channel: 'SMS' };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);

      const result = await getUserMfaById('mfa-123');

      expect(result).toEqual(mockUserMfa);
      expect(userMfaRepository.findById).toHaveBeenCalledWith('mfa-123');
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(getUserMfaById('mfa-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getUserMfasByUserId', () => {
    it('should get user MFAs by user ID', async () => {
      const mockUserMfas = [
        { id: 'mfa-1', user_id: 'user-123', channel: 'SMS' },
        { id: 'mfa-2', user_id: 'user-123', channel: 'EMAIL' }
      ];
      userMfaRepository.findMany.mockResolvedValue(mockUserMfas);

      const result = await getUserMfasByUserId('user-123');

      expect(result).toEqual(mockUserMfas);
      expect(userMfaRepository.findMany).toHaveBeenCalledWith({ user_id: 'user-123' });
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
      userMfaRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const result = await createUserMfa(newUserMfa, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockCreated);
      expect(userMfaRepository.create).toHaveBeenCalledWith(newUserMfa);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateUserMfa', () => {
    it('should update user MFA', async () => {
      const updateData = { is_enabled: false };
      const mockBefore = { id: 'mfa-123', user_id: 'user-123', is_enabled: true };
      const mockAfter = { ...mockBefore, is_enabled: false };
      userMfaRepository.findById.mockResolvedValue(mockBefore);
      userMfaRepository.update.mockResolvedValue(mockAfter);
      createAuditLog.mockResolvedValue({});

      const result = await updateUserMfa('mfa-123', updateData, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(userMfaRepository.update).toHaveBeenCalledWith('mfa-123', updateData);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(updateUserMfa('mfa-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteUserMfa', () => {
    it('should delete user MFA', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', channel: 'SMS' };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);
      userMfaRepository.softDelete.mockResolvedValue(mockUserMfa);
      createAuditLog.mockResolvedValue({});

      await deleteUserMfa('mfa-123', 'user-123', '127.0.0.1');

      expect(userMfaRepository.softDelete).toHaveBeenCalledWith('mfa-123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(deleteUserMfa('mfa-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('verifyMfaCode', () => {
    it('should verify MFA code successfully', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: true, channel: 'SMS' };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);
      userMfaRepository.update.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await verifyMfaCode('mfa-123', '123456', 'user-123', '127.0.0.1');

      expect(result.verified).toBe(true);
      expect(userMfaRepository.update).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should reject invalid MFA code', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: true, channel: 'SMS' };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);
      verifyEncryptedUserMfaCode.mockReturnValue(false);

      await expect(verifyMfaCode('mfa-123', '000000', 'user-123', '127.0.0.1'))
        .rejects
        .toMatchObject({ statusCode: 401, messageKey: 'errors.user_mfa.invalid_code' });

      expect(userMfaRepository.update).not.toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(verifyMfaCode('mfa-123', '123456', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError if MFA is disabled', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: false };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);

      await expect(verifyMfaCode('mfa-123', '123456', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('enableMfa', () => {
    it('should enable MFA', async () => {
      const mockBefore = { id: 'mfa-123', user_id: 'user-123', is_enabled: false };
      const mockAfter = { ...mockBefore, is_enabled: true };
      userMfaRepository.findById.mockResolvedValue(mockBefore);
      userMfaRepository.update.mockResolvedValue(mockAfter);
      createAuditLog.mockResolvedValue({});

      const result = await enableMfa('mfa-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(userMfaRepository.update).toHaveBeenCalledWith('mfa-123', { is_enabled: true });
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(enableMfa('mfa-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError if MFA already enabled', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: true };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);

      await expect(enableMfa('mfa-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('disableMfa', () => {
    it('should disable MFA', async () => {
      const mockBefore = { id: 'mfa-123', user_id: 'user-123', is_enabled: true };
      const mockAfter = { ...mockBefore, is_enabled: false };
      userMfaRepository.findById.mockResolvedValue(mockBefore);
      userMfaRepository.update.mockResolvedValue(mockAfter);
      createAuditLog.mockResolvedValue({});

      const result = await disableMfa('mfa-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(userMfaRepository.update).toHaveBeenCalledWith('mfa-123', { is_enabled: false });
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if user MFA not found', async () => {
      userMfaRepository.findById.mockResolvedValue(null);

      await expect(disableMfa('mfa-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError if MFA already disabled', async () => {
      const mockUserMfa = { id: 'mfa-123', user_id: 'user-123', is_enabled: false };
      userMfaRepository.findById.mockResolvedValue(mockUserMfa);

      await expect(disableMfa('mfa-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
