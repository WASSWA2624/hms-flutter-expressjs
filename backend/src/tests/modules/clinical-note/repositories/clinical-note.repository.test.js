/**
 * Clinical note repository tests
 *
 * @module tests/modules/clinical-note/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  clinical_note: {
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
} = require('@repositories/clinical-note/clinical-note.repository');

const prisma = require('@prisma/client');

describe('Clinical Note Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find clinical note by ID', async () => {
      const mockNote = {
        id: 'note-123',
        encounter_id: 'encounter-123',
        author_user_id: 'user-123',
        note: 'Clinical note content',
        deleted_at: null
      };
      prisma.clinical_note.findFirst.mockResolvedValue(mockNote);

      const result = await findById('note-123');

      expect(result).toEqual(mockNote);
      expect(prisma.clinical_note.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'note-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if clinical note not found', async () => {
      prisma.clinical_note.findFirst.mockResolvedValue(null);

      const result = await findById('note-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.clinical_note.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('note-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many clinical notes with pagination', async () => {
      const mockNotes = [
        { id: 'note-1', note: 'Note 1' },
        { id: 'note-2', note: 'Note 2' }
      ];
      prisma.clinical_note.findMany.mockResolvedValue(mockNotes);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockNotes);
      expect(prisma.clinical_note.findMany).toHaveBeenCalled();
    });
  });

  describe('count', () => {
    it('should count clinical notes', async () => {
      prisma.clinical_note.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create clinical note', async () => {
      const mockNote = {
        id: 'note-123',
        encounter_id: 'encounter-123',
        author_user_id: 'user-123',
        note: 'Clinical note content'
      };
      prisma.clinical_note.create.mockResolvedValue(mockNote);

      const result = await create(mockNote);

      expect(result).toEqual(mockNote);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.clinical_note.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update clinical note', async () => {
      const mockNote = {
        id: 'note-123',
        note: 'Updated note'
      };
      prisma.clinical_note.update.mockResolvedValue(mockNote);

      const result = await update('note-123', { note: 'Updated note' });

      expect(result).toEqual(mockNote);
    });

    it('should throw HttpError if clinical note not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.clinical_note.update.mockRejectedValue(error);

      await expect(update('note-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete clinical note', async () => {
      const mockNote = {
        id: 'note-123',
        deleted_at: new Date()
      };
      prisma.clinical_note.update.mockResolvedValue(mockNote);

      const result = await softDelete('note-123');

      expect(result).toEqual(mockNote);
      expect(prisma.clinical_note.update).toHaveBeenCalledWith({
        where: { id: 'note-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
