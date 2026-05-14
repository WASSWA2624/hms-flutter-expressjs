/**
 * Post-op note repository tests
 *
 * @module tests/modules/post-op-note/repositories
 * @description Tests for Post-op note data access layer
 * Per testing.mdc: Repository tests must mock Prisma
 */

const postOpNoteRepository = require('@repositories/post-op-note/post-op-note.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  post_op_note: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Post-op note Repository', () => {
  const defaultIncludeMatcher = expect.objectContaining(postOpNoteRepository.BASE_INCLUDE);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      note: '550e8400-e29b-41d4-a716-446655440002',
      notes: 'Test notes',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should find Post-op note by id', async () => {
      prisma.post_op_note.findFirst.mockResolvedValue(mockpostOpNote);

      const result = await postOpNoteRepository.findById(mockpostOpNote.id);

      expect(result).toEqual(mockpostOpNote);
      expect(prisma.post_op_note.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockpostOpNote.id,
          deleted_at: null
        },
        include: defaultIncludeMatcher
      });
    });

    it('should return null if Post-op note not found', async () => {
      prisma.post_op_note.findFirst.mockResolvedValue(null);

      const result = await postOpNoteRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.post_op_note.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include relations', async () => {
      const include = { encounter: true };
      prisma.post_op_note.findFirst.mockResolvedValue(mockpostOpNote);

      await postOpNoteRepository.findById(mockpostOpNote.id, include);

      expect(prisma.post_op_note.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockpostOpNote.id,
          deleted_at: null
        },
        include: expect.objectContaining({
          ...postOpNoteRepository.BASE_INCLUDE,
          ...include
        })
      });
    });
  });

  describe('findMany', () => {
    const mockpostOpNotes = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
        note: '550e8400-e29b-41d4-a716-446655440002',
        notes: 'Test notes',
        deleted_at: null
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        encounter_id: '550e8400-e29b-41d4-a716-446655440003',
        scheduled_at: new Date('2026-01-21T11:00:00.000Z'),
        status: 'IN_PROGRESS',
        deleted_at: null
      }
    ];

    it('should find many Post-op notes', async () => {
      prisma.post_op_note.findMany.mockResolvedValue(mockpostOpNotes);

      const result = await postOpNoteRepository.findMany();

      expect(result).toEqual(mockpostOpNotes);
      expect(prisma.post_op_note.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.post_op_note.findMany.mockResolvedValue([mockpostOpNotes[0]]);

      await postOpNoteRepository.findMany(filters);

      expect(prisma.post_op_note.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            status: 'SCHEDULED'
          })
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.post_op_note.findMany.mockResolvedValue(mockpostOpNotes);

      await postOpNoteRepository.findMany({}, 10, 5);

      expect(prisma.post_op_note.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 10,
          take: 5
        })
      );
    });

    it('should apply ordering', async () => {
      const orderBy = { scheduled_at: 'asc' };
      prisma.post_op_note.findMany.mockResolvedValue(mockpostOpNotes);

      await postOpNoteRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.post_op_note.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.post_op_note.findMany.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count Post-op notes', async () => {
      prisma.post_op_note.count.mockResolvedValue(10);

      const result = await postOpNoteRepository.count();

      expect(result).toBe(10);
      expect(prisma.post_op_note.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = { status: 'SCHEDULED' };
      prisma.post_op_note.count.mockResolvedValue(5);

      const result = await postOpNoteRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.post_op_note.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'SCHEDULED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.post_op_note.count.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      note: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED'
    };

    const mockCreatedpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create Post-op note', async () => {
      prisma.post_op_note.create.mockResolvedValue(mockCreatedpostOpNote);

      const result = await postOpNoteRepository.create(createData);

      expect(result).toEqual(mockCreatedpostOpNote);
      expect(prisma.post_op_note.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.post_op_note.create.mockRejectedValue(error);

      await expect(postOpNoteRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.post_op_note.create.mockRejectedValue(error);

      await expect(postOpNoteRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.post_op_note.create.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.create(createData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockUpdatedpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      note: '550e8400-e29b-41d4-a716-446655440002',
      status: 'IN_PROGRESS',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 2
    };

    it('should update Post-op note', async () => {
      prisma.post_op_note.update.mockResolvedValue(mockUpdatedpostOpNote);

      const result = await postOpNoteRepository.update(mockUpdatedpostOpNote.id, updateData);

      expect(result).toEqual(mockUpdatedpostOpNote);
      expect(prisma.post_op_note.update).toHaveBeenCalledWith({
        where: { id: mockUpdatedpostOpNote.id },
        data: updateData
      });
    });

    it('should throw HttpError when Post-op note not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.post_op_note.update.mockRejectedValue(error);

      await expect(postOpNoteRepository.update('non-existent-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['encounter_id'] };
      prisma.post_op_note.update.mockRejectedValue(error);

      await expect(postOpNoteRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.post_op_note.update.mockRejectedValue(error);

      await expect(postOpNoteRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.post_op_note.update.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.update('some-id', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const mockDeletedpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440001',
      note: '550e8400-e29b-41d4-a716-446655440002',
      notes: 'Test notes',
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: new Date(),
      version: 1
    };

    it('should soft delete Post-op note', async () => {
      prisma.post_op_note.update.mockResolvedValue(mockDeletedpostOpNote);

      const result = await postOpNoteRepository.softDelete(mockDeletedpostOpNote.id);

      expect(result).toEqual(mockDeletedpostOpNote);
      expect(prisma.post_op_note.update).toHaveBeenCalledWith({
        where: { id: mockDeletedpostOpNote.id },
        data: expect.objectContaining({
          deleted_at: expect.any(Date)
        })
      });
    });

    it('should throw HttpError when Post-op note not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.post_op_note.update.mockRejectedValue(error);

      await expect(postOpNoteRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.post_op_note.update.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteRepository.softDelete('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
