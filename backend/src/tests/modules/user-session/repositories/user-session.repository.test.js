/**
 * User Session repository tests
 *
 * @module tests/modules/user-session/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  user_session: {
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
} = require('@repositories/user-session/user-session.repository');

const prisma = require('@prisma/client');

describe('User Session Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find session by ID', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        refresh_token_hash: 'hash123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0',
        expires_at: new Date('2026-02-01'),
        revoked_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        user: {
          id: 'user-123',
          email: 'test@example.com',
          status: 'ACTIVE'
        }
      };
      prisma.user_session.findFirst.mockResolvedValue(mockSession);

      const result = await findById('session-123');

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'session-123',
          deleted_at: null
        },
        include: {
          user: {
            select: {
              id: true,
              email: true,
              status: true
            }
          }
        }
      });
    });

    it('should return null if session not found', async () => {
      prisma.user_session.findFirst.mockResolvedValue(null);

      const result = await findById('session-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_session.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('session-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many sessions with default pagination', async () => {
      const mockSessions = [
        {
          id: 'session-1',
          user_id: 'user-123',
          user: { id: 'user-123', email: 'test@example.com', status: 'ACTIVE' }
        },
        {
          id: 'session-2',
          user_id: 'user-123',
          user: { id: 'user-123', email: 'test@example.com', status: 'ACTIVE' }
        }
      ];
      prisma.user_session.findMany.mockResolvedValue(mockSessions);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockSessions);
      expect(prisma.user_session.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {
          user: {
            select: {
              id: true,
              email: true,
              status: true
            }
          }
        }
      });
    });

    it('should find sessions with filters', async () => {
      const mockSessions = [
        {
          id: 'session-1',
          user_id: 'user-123',
          user: { id: 'user-123', email: 'test@example.com', status: 'ACTIVE' }
        }
      ];
      prisma.user_session.findMany.mockResolvedValue(mockSessions);

      const result = await findMany({ user_id: 'user-123' }, 0, 10);

      expect(result).toEqual(mockSessions);
      expect(prisma.user_session.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
    });

    it('should find sessions with custom sort order', async () => {
      const mockSessions = [];
      prisma.user_session.findMany.mockResolvedValue(mockSessions);

      await findMany({}, 0, 20, { expires_at: 'asc' });

      expect(prisma.user_session.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { expires_at: 'asc' },
        include: expect.any(Object)
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_session.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count sessions without filters', async () => {
      prisma.user_session.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.user_session.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count sessions with filters', async () => {
      prisma.user_session.count.mockResolvedValue(5);

      const result = await count({ user_id: 'user-123' });

      expect(result).toBe(5);
      expect(prisma.user_session.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_session.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new session', async () => {
      const sessionData = {
        user_id: 'user-123',
        refresh_token_hash: 'hash123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0',
        expires_at: new Date('2026-02-01')
      };
      const mockSession = { id: 'session-123', ...sessionData };
      prisma.user_session.create.mockResolvedValue(mockSession);

      const result = await create(sessionData);

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.create).toHaveBeenCalledWith({
        data: sessionData
      });
    });

    it('should throw HttpError on duplicate session', async () => {
      const sessionData = {
        user_id: 'user-123',
        refresh_token_hash: 'hash123'
      };
      prisma.user_session.create.mockRejectedValue({ code: 'P2002' });

      await expect(create(sessionData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on invalid user reference', async () => {
      const sessionData = {
        user_id: 'invalid-user',
        refresh_token_hash: 'hash123'
      };
      prisma.user_session.create.mockRejectedValue({ code: 'P2003' });

      await expect(create(sessionData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      const sessionData = { user_id: 'user-123', refresh_token_hash: 'hash123' };
      prisma.user_session.create.mockRejectedValue(new Error('DB error'));

      await expect(create(sessionData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update session', async () => {
      const updateData = { ip_address: '192.168.1.2' };
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        ip_address: '192.168.1.2'
      };
      prisma.user_session.update.mockResolvedValue(mockSession);

      const result = await update('session-123', updateData);

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.update).toHaveBeenCalledWith({
        where: { id: 'session-123' },
        data: updateData
      });
    });

    it('should throw HttpError if session not found', async () => {
      prisma.user_session.update.mockRejectedValue({ code: 'P2025' });

      await expect(update('session-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_session.update.mockRejectedValue(new Error('DB error'));

      await expect(update('session-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete session', async () => {
      const mockSession = {
        id: 'session-123',
        user_id: 'user-123',
        deleted_at: expect.any(Date),
        revoked_at: expect.any(Date)
      };
      prisma.user_session.update.mockResolvedValue(mockSession);

      const result = await softDelete('session-123');

      expect(result).toEqual(mockSession);
      expect(prisma.user_session.update).toHaveBeenCalledWith({
        where: { id: 'session-123' },
        data: {
          deleted_at: expect.any(Date),
          revoked_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if session not found', async () => {
      prisma.user_session.update.mockRejectedValue({ code: 'P2025' });

      await expect(softDelete('session-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_session.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('session-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
