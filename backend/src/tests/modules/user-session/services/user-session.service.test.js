/**
 * User Session service tests
 *
 * @module tests/modules/user-session/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/user-session/user-session.repository');
jest.mock('@lib/audit');

const sessionRepository = require('@repositories/user-session/user-session.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listSessions,
  getSessionById,
  revokeSession
} = require('@services/user-session/user-session.service');

describe('User Session Service', () => {
  const requesterContext = { user_id: 'user-123' };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listSessions', () => {
    it('should list sessions with default pagination', async () => {
      const mockSessions = [
        { id: 'session-1', user_id: 'user-123' },
        { id: 'session-2', user_id: 'user-456' }
      ];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(10);

      const result = await listSessions({}, 1, 20, 'created_at', 'desc', requesterContext);

      expect(result.sessions).toEqual(mockSessions);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(sessionRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by user_id', async () => {
      const mockSessions = [{ id: 'session-1', user_id: 'user-123' }];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(1);

      const result = await listSessions(
        { user_id: 'user-123' },
        1,
        20,
        'created_at',
        'desc',
        requesterContext
      );

      expect(result.sessions).toEqual(mockSessions);
      expect(sessionRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockSessions = [{ id: 'session-1', user_id: 'user-123' }];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(1);

      const result = await listSessions(
        { is_active: 'true' },
        1,
        20,
        'created_at',
        'desc',
        requesterContext
      );

      expect(result.sessions).toEqual(mockSessions);
      expect(sessionRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          revoked_at: null,
          expires_at: expect.any(Object)
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockSessions = [{ id: 'session-1', user_id: 'user-123' }];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(1);

      const result = await listSessions(
        { is_active: 'false' },
        1,
        20,
        'created_at',
        'desc',
        requesterContext
      );

      expect(result.sessions).toEqual(mockSessions);
      expect(sessionRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.any(Array)
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockSessions = [];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(0);

      await listSessions({}, 1, 20, 'expires_at', 'asc', requesterContext);

      expect(sessionRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { expires_at: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockSessions = [];
      sessionRepository.findMany.mockResolvedValue(mockSessions);
      sessionRepository.count.mockResolvedValue(50);

      const result = await listSessions({}, 2, 20, 'created_at', 'desc', requesterContext);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should throw HttpError when context user is missing', async () => {
      await expect(listSessions({}, 1, 20)).rejects.toThrow(HttpError);
      expect(sessionRepository.findMany).not.toHaveBeenCalled();
    });

    it('should reject mismatched user_id filter', async () => {
      await expect(
        listSessions(
          { user_id: 'another-user' },
          1,
          20,
          'created_at',
          'desc',
          requesterContext
        )
      ).rejects.toThrow(HttpError);
      expect(sessionRepository.findMany).not.toHaveBeenCalled();
    });
  });

  describe('getSessionById', () => {
    it('should get session by ID', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: null,
        expires_at: new Date(Date.now() + 86400000) // Tomorrow
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      const result = await getSessionById('session-123', requesterContext);

      expect(result.id).toBe('session-123');
      expect(result.is_active).toBe(true);
      expect(sessionRepository.findById).toHaveBeenCalledWith('session-123');
    });

    it('should mark session as inactive if revoked', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: new Date(),
        expires_at: new Date(Date.now() + 86400000)
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      const result = await getSessionById('session-123', requesterContext);

      expect(result.is_active).toBe(false);
    });

    it('should mark session as inactive if expired', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: null,
        expires_at: new Date(Date.now() - 86400000) // Yesterday
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      const result = await getSessionById('session-123', requesterContext);

      expect(result.is_active).toBe(false);
    });

    it('should throw HttpError if session not found', async () => {
      sessionRepository.findById.mockResolvedValue(null);

      await expect(getSessionById('session-123', requesterContext))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError for non-owned sessions', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'different-user',
        revoked_at: null,
        expires_at: new Date(Date.now() + 86400000)
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      await expect(getSessionById('session-123', requesterContext)).rejects.toThrow(HttpError);
    });
  });

  describe('revokeSession', () => {
    it('should revoke session successfully', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: null
      };
      sessionRepository.findById.mockResolvedValue(mockSession);
      sessionRepository.softDelete.mockResolvedValue(mockSession);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      };

      await revokeSession('session-123', context);

      expect(sessionRepository.findById).toHaveBeenCalledWith('session-123');
      expect(sessionRepository.softDelete).toHaveBeenCalledWith('session-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'SESSION_REVOKED',
          entity: 'user_session',
          entity_id: 'session-123',
          user_id: 'user-123'
        })
      );
    });

    it('should throw HttpError if session not found', async () => {
      sessionRepository.findById.mockResolvedValue(null);

      await expect(revokeSession('session-123', requesterContext))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError if session already revoked', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: new Date()
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      await expect(revokeSession('session-123', requesterContext))
        .rejects
        .toThrow(HttpError);
    });

    it('should create audit log with correct context', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: null
      };
      sessionRepository.findById.mockResolvedValue(mockSession);
      sessionRepository.softDelete.mockResolvedValue(mockSession);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      };

      await revokeSession('session-123', context);

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'SESSION_REVOKED',
          user_id: 'user-123',
          details: expect.objectContaining({
            revoked_session_user_id: 'user-123',
            revoked_by_self: true
          })
        })
      );
    });

    it('should handle self-revocation correctly', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        revoked_at: null
      };
      sessionRepository.findById.mockResolvedValue(mockSession);
      sessionRepository.softDelete.mockResolvedValue(mockSession);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123'
      };

      await revokeSession('session-123', context);

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          details: expect.objectContaining({
            revoked_by_self: true
          })
        })
      );
    });

    it('should throw HttpError when revoking session owned by another user', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'other-user',
        revoked_at: null
      };
      sessionRepository.findById.mockResolvedValue(mockSession);

      await expect(revokeSession('session-123', requesterContext)).rejects.toThrow(HttpError);
      expect(sessionRepository.softDelete).not.toHaveBeenCalled();
    });
  });
});
