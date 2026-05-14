/**
 * PACS link repository tests
 *
 * @module tests/modules/pacs-link/repositories
 * @description Tests for PACS link repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const pacsLinkRepository = require('@repositories/pacs-link/pacs-link.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  pacs_link: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('PACS Link Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find PACS link by id', async () => {
      const mockPacsLink = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        imaging_study_id: '456e7890-e89b-12d3-a456-426614174000',
        url: 'https://pacs.example.com/study/123',
        expires_at: new Date('2024-12-31T23:59:59.000Z')
      };
      prisma.pacs_link.findFirst.mockResolvedValue(mockPacsLink);

      const result = await pacsLinkRepository.findById('123e4567-e89b-12d3-a456-426614174000');
      expect(result).toEqual(mockPacsLink);
      expect(prisma.pacs_link.findFirst).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000', deleted_at: null },
        include: {}
      });
    });

    it('should return null if PACS link not found', async () => {
      prisma.pacs_link.findFirst.mockResolvedValue(null);

      const result = await pacsLinkRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should include relations when specified', async () => {
      const mockPacsLink = { id: '123', url: 'https://pacs.example.com' };
      prisma.pacs_link.findFirst.mockResolvedValue(mockPacsLink);

      const include = { imaging_study: true };
      await pacsLinkRepository.findById('123', include);

      expect(prisma.pacs_link.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pacs_link.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many PACS links with pagination', async () => {
      const mockPacsLinks = [
        { id: '1', url: 'https://pacs1.example.com' },
        { id: '2', url: 'https://pacs2.example.com' }
      ];
      prisma.pacs_link.findMany.mockResolvedValue(mockPacsLinks);

      const result = await pacsLinkRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockPacsLinks);
      expect(prisma.pacs_link.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters when provided', async () => {
      const filters = { imaging_study_id: '123' };
      prisma.pacs_link.findMany.mockResolvedValue([]);

      await pacsLinkRepository.findMany(filters);

      expect(prisma.pacs_link.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, imaging_study_id: '123' }
        })
      );
    });

    it('should apply custom orderBy when provided', async () => {
      prisma.pacs_link.findMany.mockResolvedValue([]);

      await pacsLinkRepository.findMany({}, 0, 20, { expires_at: 'asc' });

      expect(prisma.pacs_link.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy: { expires_at: 'asc' }
        })
      );
    });

    it('should include relations when specified', async () => {
      prisma.pacs_link.findMany.mockResolvedValue([]);

      await pacsLinkRepository.findMany({}, 0, 20, {}, { imaging_study: true });

      expect(prisma.pacs_link.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include: { imaging_study: true }
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.pacs_link.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count PACS links', async () => {
      prisma.pacs_link.count.mockResolvedValue(42);

      const result = await pacsLinkRepository.count({});
      expect(result).toBe(42);
      expect(prisma.pacs_link.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      const filters = { imaging_study_id: '123' };
      prisma.pacs_link.count.mockResolvedValue(10);

      await pacsLinkRepository.count(filters);

      expect(prisma.pacs_link.count).toHaveBeenCalledWith({
        where: { deleted_at: null, imaging_study_id: '123' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pacs_link.count.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create PACS link', async () => {
      const mockData = {
        imaging_study_id: '456e7890-e89b-12d3-a456-426614174000',
        url: 'https://pacs.example.com/study/123'
      };
      const mockPacsLink = { id: '123', ...mockData };
      prisma.pacs_link.create.mockResolvedValue(mockPacsLink);

      const result = await pacsLinkRepository.create(mockData);
      expect(result).toEqual(mockPacsLink);
      expect(prisma.pacs_link.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.pacs_link.create.mockRejectedValue(error);

      await expect(pacsLinkRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'imaging_study_id' };
      prisma.pacs_link.create.mockRejectedValue(error);

      await expect(pacsLinkRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.pacs_link.create.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update PACS link', async () => {
      const mockData = { url: 'https://new-pacs.example.com' };
      const mockUpdated = { id: '123', ...mockData };
      prisma.pacs_link.update.mockResolvedValue(mockUpdated);

      const result = await pacsLinkRepository.update('123', mockData);
      expect(result).toEqual(mockUpdated);
      expect(prisma.pacs_link.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError when PACS link not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.pacs_link.update.mockRejectedValue(error);

      await expect(pacsLinkRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.pacs_link.update.mockRejectedValue(error);

      await expect(pacsLinkRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'imaging_study_id' };
      prisma.pacs_link.update.mockRejectedValue(error);

      await expect(pacsLinkRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.pacs_link.update.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete PACS link', async () => {
      const mockDeleted = { id: '123', deleted_at: new Date() };
      prisma.pacs_link.update.mockResolvedValue(mockDeleted);

      const result = await pacsLinkRepository.softDelete('123');
      expect(result).toEqual(mockDeleted);
      expect(prisma.pacs_link.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when PACS link not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.pacs_link.update.mockRejectedValue(error);

      await expect(pacsLinkRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.pacs_link.update.mockRejectedValue(new Error('DB Error'));

      await expect(pacsLinkRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
