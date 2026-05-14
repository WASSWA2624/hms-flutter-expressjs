/**
 * Terms acceptance repository tests
 *
 * @module tests/modules/terms-acceptance/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  terms_acceptance: {
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
  softDelete
} = require('@repositories/terms-acceptance/terms-acceptance.repository');

const prisma = require('@prisma/client');

describe('Terms Acceptance Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find terms acceptance by ID', async () => {
      const mockTermsAcceptance = {
        id: 'ta-123',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        version_label: 'v1.0.0',
        accepted_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.terms_acceptance.findFirst.mockResolvedValue(mockTermsAcceptance);

      const result = await findById('ta-123');

      expect(result).toEqual(mockTermsAcceptance);
      expect(prisma.terms_acceptance.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'ta-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if terms acceptance not found', async () => {
      prisma.terms_acceptance.findFirst.mockResolvedValue(null);

      const result = await findById('ta-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.terms_acceptance.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('ta-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockTermsAcceptance = { id: 'ta-123' };
      prisma.terms_acceptance.findFirst.mockResolvedValue(mockTermsAcceptance);

      await findById('ta-123', { user: true });

      expect(prisma.terms_acceptance.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'ta-123',
          deleted_at: null
        },
        include: { user: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many terms acceptances with default pagination', async () => {
      const mockTermsAcceptances = [
        {
          id: 'ta-1',
          tenant_id: 'tenant-123',
          user_id: 'user-123',
          version_label: 'v1.0.0'
        },
        {
          id: 'ta-2',
          tenant_id: 'tenant-123',
          user_id: 'user-456',
          version_label: 'v1.0.0'
        }
      ];
      prisma.terms_acceptance.findMany.mockResolvedValue(mockTermsAcceptances);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockTermsAcceptances);
      expect(prisma.terms_acceptance.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find terms acceptances with filters', async () => {
      const mockTermsAcceptances = [
        {
          id: 'ta-1',
          user_id: 'user-123',
          version_label: 'v1.0.0'
        }
      ];
      prisma.terms_acceptance.findMany.mockResolvedValue(mockTermsAcceptances);

      const result = await findMany({ 
        user_id: 'user-123', 
        version_label: 'v1.0.0'
      }, 0, 10);

      expect(result).toEqual(mockTermsAcceptances);
      expect(prisma.terms_acceptance.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123',
          version_label: 'v1.0.0'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find terms acceptances with custom pagination', async () => {
      const mockTermsAcceptances = [];
      prisma.terms_acceptance.findMany.mockResolvedValue(mockTermsAcceptances);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockTermsAcceptances);
      expect(prisma.terms_acceptance.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find terms acceptances with custom orderBy', async () => {
      const mockTermsAcceptances = [];
      prisma.terms_acceptance.findMany.mockResolvedValue(mockTermsAcceptances);

      const result = await findMany({}, 0, 20, { accepted_at: 'asc' });

      expect(result).toEqual(mockTermsAcceptances);
      expect(prisma.terms_acceptance.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { accepted_at: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.terms_acceptance.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count terms acceptances without filters', async () => {
      prisma.terms_acceptance.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.terms_acceptance.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count terms acceptances with filters', async () => {
      prisma.terms_acceptance.count.mockResolvedValue(5);

      const result = await count({ 
        user_id: 'user-123',
        version_label: 'v1.0.0'
      });

      expect(result).toBe(5);
      expect(prisma.terms_acceptance.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          user_id: 'user-123',
          version_label: 'v1.0.0'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.terms_acceptance.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create terms acceptance', async () => {
      const termsAcceptanceData = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        version_label: 'v1.0.0',
        accepted_at: new Date('2026-01-19')
      };
      const mockTermsAcceptance = { id: 'ta-123', ...termsAcceptanceData };
      prisma.terms_acceptance.create.mockResolvedValue(mockTermsAcceptance);

      const result = await create(termsAcceptanceData);

      expect(result).toEqual(mockTermsAcceptance);
      expect(prisma.terms_acceptance.create).toHaveBeenCalledWith({
        data: termsAcceptanceData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.terms_acceptance.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.terms_acceptance.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.terms_acceptance.create.mockRejectedValue(new Error('Unexpected error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete terms acceptance', async () => {
      const mockTermsAcceptance = {
        id: 'ta-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.terms_acceptance.update.mockResolvedValue(mockTermsAcceptance);

      const result = await softDelete('ta-123');

      expect(result).toEqual(mockTermsAcceptance);
      expect(prisma.terms_acceptance.update).toHaveBeenCalledWith({
        where: { id: 'ta-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if terms acceptance not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.terms_acceptance.update.mockRejectedValue(error);

      await expect(softDelete('ta-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.terms_acceptance.update.mockRejectedValue(new Error('Unexpected error'));

      await expect(softDelete('ta-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
