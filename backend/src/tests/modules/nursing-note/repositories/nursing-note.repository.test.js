/**
 * Nursing note repository tests
 *
 * @module tests/modules/nursing-note/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  nursing_note: {
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
} = require('@repositories/nursing-note/nursing-note.repository');

const prisma = require('@prisma/client');

describe('Nursing Note Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find nursing note by ID', async () => {
      const mockNote = {
        id: 'note-123',
        admission_id: 'admission-123',
        nurse_user_id: 'user-123',
        note: 'Nursing note content',
        deleted_at: null
      };
      prisma.nursing_note.findFirst.mockResolvedValue(mockNote);

      const result = await findById('note-123');

      expect(result).toEqual(mockNote);
      expect(prisma.nursing_note.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'note-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if nursing note not found', async () => {
      prisma.nursing_note.findFirst.mockResolvedValue(null);

      const result = await findById('note-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.nursing_note.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('note-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should apply soft delete filter by default', async () => {
      prisma.nursing_note.findFirst.mockResolvedValue(null);

      await findById('note-123');

      expect(prisma.nursing_note.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null
          })
        })
      );
    });
  });

  describe('findMany', () => {
    it('should find many nursing notes with pagination', async () => {
      const mockNotes = [
        { id: 'note-1', note: 'Note 1', deleted_at: null },
        { id: 'note-2', note: 'Note 2', deleted_at: null }
      ];
      prisma.nursing_note.findMany.mockResolvedValue(mockNotes);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockNotes);
      expect(prisma.nursing_note.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      prisma.nursing_note.findMany.mockResolvedValue([]);

      await findMany({ admission_id: 'admission-123' }, 0, 20);

      expect(prisma.nursing_note.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            admission_id: 'admission-123',
            deleted_at: null
          })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.nursing_note.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count nursing notes', async () => {
      prisma.nursing_note.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.nursing_note.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters in count', async () => {
      prisma.nursing_note.count.mockResolvedValue(5);

      await count({ nurse_user_id: 'user-123' });

      expect(prisma.nursing_note.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          nurse_user_id: 'user-123'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.nursing_note.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create nursing note', async () => {
      const mockNote = {
        id: 'note-123',
        admission_id: 'admission-123',
        nurse_user_id: 'user-123',
        note: 'Nursing note content'
      };
      prisma.nursing_note.create.mockResolvedValue(mockNote);

      const result = await create(mockNote);

      expect(result).toEqual(mockNote);
      expect(prisma.nursing_note.create).toHaveBeenCalledWith({
        data: mockNote
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.nursing_note.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique violation');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.nursing_note.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.nursing_note.create.mockRejectedValue(new Error('Unexpected error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update nursing note', async () => {
      const mockNote = {
        id: 'note-123',
        note: 'Updated note'
      };
      prisma.nursing_note.update.mockResolvedValue(mockNote);

      const result = await update('note-123', { note: 'Updated note' });

      expect(result).toEqual(mockNote);
      expect(prisma.nursing_note.update).toHaveBeenCalledWith({
        where: { id: 'note-123' },
        data: { note: 'Updated note' }
      });
    });

    it('should throw HttpError if nursing note not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.nursing_note.update.mockRejectedValue(error);

      await expect(update('note-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.nursing_note.update.mockRejectedValue(error);

      await expect(update('note-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete nursing note', async () => {
      const mockNote = {
        id: 'note-123',
        deleted_at: new Date()
      };
      prisma.nursing_note.update.mockResolvedValue(mockNote);

      const result = await softDelete('note-123');

      expect(result).toEqual(mockNote);
      expect(prisma.nursing_note.update).toHaveBeenCalledWith({
        where: { id: 'note-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if nursing note not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.nursing_note.update.mockRejectedValue(error);

      await expect(softDelete('note-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.nursing_note.update.mockRejectedValue(new Error('Unexpected error'));

      await expect(softDelete('note-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
