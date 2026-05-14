/**
 * User MFA repository tests
 *
 * @module tests/modules/user-mfa/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  user_mfa: {
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
} = require('@repositories/user-mfa/user-mfa.repository');

const prisma = require('@prisma/client');

describe('User MFA Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find user MFA by ID', async () => {
      const mockUserMfa = {
        id: 'mfa-123',
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true,
        last_used_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.user_mfa.findFirst.mockResolvedValue(mockUserMfa);

      const result = await findById('mfa-123');

      expect(result).toEqual(mockUserMfa);
      expect(prisma.user_mfa.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'mfa-123',
          deleted_at: null
        }
      });
    });

    it('should return null if user MFA not found', async () => {
      prisma.user_mfa.findFirst.mockResolvedValue(null);

      const result = await findById('mfa-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_mfa.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('mfa-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many user MFAs with default pagination', async () => {
      const mockUserMfas = [
        {
          id: 'mfa-1',
          user_id: 'user-123',
          channel: 'SMS',
          secret_encrypted: 'encrypted_1',
          is_enabled: true
        },
        {
          id: 'mfa-2',
          user_id: 'user-123',
          channel: 'AUTHENTICATOR_APP',
          secret_encrypted: 'encrypted_2',
          is_enabled: true
        }
      ];
      prisma.user_mfa.findMany.mockResolvedValue(mockUserMfas);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockUserMfas);
      expect(prisma.user_mfa.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find user MFAs with filters', async () => {
      const mockUserMfas = [
        {
          id: 'mfa-1',
          user_id: 'user-123',
          channel: 'SMS',
          secret_encrypted: 'encrypted_1',
          is_enabled: true
        }
      ];
      prisma.user_mfa.findMany.mockResolvedValue(mockUserMfas);

      const result = await findMany({ 
        user_id: 'user-123', 
        channel: 'SMS'
      }, 0, 10);

      expect(result).toEqual(mockUserMfas);
      expect(prisma.user_mfa.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123',
          channel: 'SMS'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find user MFAs with custom pagination', async () => {
      const mockUserMfas = [];
      prisma.user_mfa.findMany.mockResolvedValue(mockUserMfas);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockUserMfas);
      expect(prisma.user_mfa.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find user MFAs with custom order', async () => {
      const mockUserMfas = [];
      prisma.user_mfa.findMany.mockResolvedValue(mockUserMfas);

      const result = await findMany({}, 0, 20, { channel: 'asc' });

      expect(result).toEqual(mockUserMfas);
      expect(prisma.user_mfa.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { channel: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_mfa.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count user MFAs', async () => {
      prisma.user_mfa.count.mockResolvedValue(5);

      const result = await count({});

      expect(result).toBe(5);
      expect(prisma.user_mfa.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count user MFAs with filters', async () => {
      prisma.user_mfa.count.mockResolvedValue(2);

      const result = await count({ 
        user_id: 'user-123',
        is_enabled: true
      });

      expect(result).toBe(2);
      expect(prisma.user_mfa.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123',
          is_enabled: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_mfa.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new user MFA', async () => {
      const newUserMfa = {
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true
      };
      const mockCreated = {
        id: 'mfa-123',
        ...newUserMfa,
        last_used_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.user_mfa.create.mockResolvedValue(mockCreated);

      const result = await create(newUserMfa);

      expect(result).toEqual(mockCreated);
      expect(prisma.user_mfa.create).toHaveBeenCalledWith({
        data: newUserMfa
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const newUserMfa = {
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true
      };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['user_id', 'channel'] };
      prisma.user_mfa.create.mockRejectedValue(error);

      await expect(create(newUserMfa))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const newUserMfa = {
        user_id: 'invalid-user',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true
      };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.user_mfa.create.mockRejectedValue(error);

      await expect(create(newUserMfa))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const newUserMfa = {
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true
      };
      prisma.user_mfa.create.mockRejectedValue(new Error('DB error'));

      await expect(create(newUserMfa))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update user MFA', async () => {
      const updateData = {
        is_enabled: false
      };
      const mockUpdated = {
        id: 'mfa-123',
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: false,
        last_used_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.user_mfa.update.mockResolvedValue(mockUpdated);

      const result = await update('mfa-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.user_mfa.update).toHaveBeenCalledWith({
        where: { id: 'mfa-123' },
        data: updateData
      });
    });

    it('should throw HttpError when user MFA not found (P2025)', async () => {
      const updateData = {
        is_enabled: false
      };
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.user_mfa.update.mockRejectedValue(error);

      await expect(update('mfa-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const updateData = {
        channel: 'EMAIL'
      };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['user_id', 'channel'] };
      prisma.user_mfa.update.mockRejectedValue(error);

      await expect(update('mfa-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const updateData = {
        user_id: 'invalid-user'
      };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.user_mfa.update.mockRejectedValue(error);

      await expect(update('mfa-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const updateData = {
        is_enabled: false
      };
      prisma.user_mfa.update.mockRejectedValue(new Error('DB error'));

      await expect(update('mfa-123', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete user MFA', async () => {
      const mockDeleted = {
        id: 'mfa-123',
        user_id: 'user-123',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_123',
        is_enabled: true,
        last_used_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };
      prisma.user_mfa.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('mfa-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.user_mfa.update).toHaveBeenCalledWith({
        where: { id: 'mfa-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when user MFA not found (P2025)', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.user_mfa.update.mockRejectedValue(error);

      await expect(softDelete('mfa-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user_mfa.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('mfa-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
