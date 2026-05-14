/**
 * User Session controller tests
 *
 * @module tests/modules/user-session/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/user-session/user-session.service');
jest.mock('@lib/response');

const sessionService = require('@services/user-session/user-session.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listSessions,
  getSessionById,
  revokeSession
} = require('@controllers/user-session/user-session.controller');

describe('User Session Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
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

  describe('listSessions', () => {
    it('should list sessions with default pagination', async () => {
      const mockResult = {
        sessions: [
          { id: 'session-1', user_id: 'user-123' },
          { id: 'session-2', user_id: 'user-456' }
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
      sessionService.listSessions.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listSessions(req, res);

      expect(sessionService.listSessions).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined,
        { user_id: 'user-123' }
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.session.list.success',
        mockResult.sessions,
        mockResult.pagination
      );
    });

    it('should list sessions with filters', async () => {
      const mockResult = {
        sessions: [{ id: 'session-1', user_id: 'user-123' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      sessionService.listSessions.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        user_id: 'user-123',
        is_active: 'true'
      };

      await listSessions(req, res);

      expect(sessionService.listSessions).toHaveBeenCalledWith(
        { user_id: 'user-123', is_active: 'true' },
        1,
        20,
        undefined,
        undefined,
        { user_id: 'user-123' }
      );
    });

    it('should list sessions with sorting', async () => {
      const mockResult = {
        sessions: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      sessionService.listSessions.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'expires_at',
        order: 'asc'
      };

      await listSessions(req, res);

      expect(sessionService.listSessions).toHaveBeenCalledWith(
        {},
        1,
        20,
        'expires_at',
        'asc',
        { user_id: 'user-123' }
      );
    });
  });

  describe('getSessionById', () => {
    it('should get session by ID', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        is_active: true
      };
      sessionService.getSessionById.mockResolvedValue(mockSession);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'session-123' };

      await getSessionById(req, res);

      expect(sessionService.getSessionById).toHaveBeenCalledWith(
        'session-123',
        { user_id: 'user-123' }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.session.get.success',
        mockSession
      );
    });
  });

  describe('revokeSession', () => {
    it('should revoke session successfully', async () => {
      sessionService.revokeSession.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'session-123' };

      await revokeSession(req, res);

      expect(sessionService.revokeSession).toHaveBeenCalledWith(
        'session-123',
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        })
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user context', async () => {
      sessionService.revokeSession.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.user = undefined;
      req.params = { id: 'session-123' };

      await revokeSession(req, res);

      expect(sessionService.revokeSession).toHaveBeenCalledWith(
        'session-123',
        expect.objectContaining({
          user_id: undefined,
          tenant_id: undefined,
          facility_id: undefined,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        })
      );
    });
  });
});
