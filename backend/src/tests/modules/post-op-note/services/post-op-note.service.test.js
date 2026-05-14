/**
 * Post-op note service tests
 *
 * @module tests/modules/post-op-note/services
 * @description Tests for the Post-op note business logic layer
 */

const postOpNoteService = require('@services/post-op-note/post-op-note.service');
const postOpNoteRepository = require('@repositories/post-op-note/post-op-note.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/post-op-note/post-op-note.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Post-op note Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';
  const noteId = '550e8400-e29b-41d4-a716-446655440000';
  const theatreCaseId = '550e8400-e29b-41d4-a716-446655440001';
  const encounterId = '550e8400-e29b-41d4-a716-446655440002';
  const patientId = '550e8400-e29b-41d4-a716-446655440003';

  const mockPostOpNote = {
    id: noteId,
    human_friendly_id: 'PON0001',
    theatre_case_id: theatreCaseId,
    note: 'Stable after surgery',
    record_status: 'DRAFT',
    theatre_case: {
      id: theatreCaseId,
      human_friendly_id: 'TC0001',
      encounter: {
        id: encounterId,
        human_friendly_id: 'ENC0001',
        tenant_id: 'tenant-1',
        patient: {
          id: patientId,
          human_friendly_id: 'PAT0001',
          first_name: 'John',
          last_name: 'Doe',
        },
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier }) =>
      identifier ? { id: identifier } : null
    );
  });

  describe('listpostOpNotes', () => {
    it('should list Post-op notes with pagination', async () => {
      postOpNoteRepository.findMany.mockResolvedValue([mockPostOpNote]);
      postOpNoteRepository.count.mockResolvedValue(1);

      const result = await postOpNoteService.listpostOpNotes({}, 1, 20, 'created_at', 'desc');

      expect(result.post_op_notes).toEqual([
        expect.objectContaining({
          id: noteId,
          display_id: 'PON0001',
          encounter_display_id: 'ENC0001',
          patient_display_id: 'PAT0001',
          patient_display_name: 'John Doe',
          record_status: 'DRAFT',
        }),
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('should apply encounter_id filter through theatre_case scope', async () => {
      postOpNoteRepository.findMany.mockResolvedValue([mockPostOpNote]);
      postOpNoteRepository.count.mockResolvedValue(1);

      await postOpNoteService.listpostOpNotes({ encounter_id: encounterId }, 1, 20, null, 'asc');

      expect(postOpNoteRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          theatre_case: expect.objectContaining({
            encounter_id: encounterId,
          }),
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply record_status filter', async () => {
      postOpNoteRepository.findMany.mockResolvedValue([mockPostOpNote]);
      postOpNoteRepository.count.mockResolvedValue(1);

      await postOpNoteService.listpostOpNotes({ record_status: 'FINALIZED' }, 1, 20, null, 'asc');

      expect(postOpNoteRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          record_status: 'FINALIZED',
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply search filters across note and related identifiers', async () => {
      postOpNoteRepository.findMany.mockResolvedValue([mockPostOpNote]);
      postOpNoteRepository.count.mockResolvedValue(1);

      await postOpNoteService.listpostOpNotes({ search: 'stable' }, 1, 20, null, 'asc');

      expect(postOpNoteRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({
              note: { contains: 'stable' },
            }),
          ]),
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      postOpNoteRepository.findMany.mockResolvedValue([mockPostOpNote]);
      postOpNoteRepository.count.mockResolvedValue(45);

      const result = await postOpNoteService.listpostOpNotes({}, 2, 20, null, 'asc');

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true,
      });
    });

    it('should throw HttpError on repository error', async () => {
      postOpNoteRepository.findMany.mockRejectedValue(new Error('Database error'));

      await expect(postOpNoteService.listpostOpNotes({}, 1, 20, null, 'asc')).rejects.toThrow(
        HttpError
      );
    });
  });

  describe('getpostOpNoteById', () => {
    it('should get Post-op note by id', async () => {
      postOpNoteRepository.findById.mockResolvedValue(mockPostOpNote);

      const result = await postOpNoteService.getpostOpNoteById(noteId);

      expect(result).toEqual(
        expect.objectContaining({
          id: noteId,
          display_id: 'PON0001',
          patient_display_name: 'John Doe',
        })
      );
      expect(postOpNoteRepository.findById).toHaveBeenCalledWith(noteId);
    });

    it('should throw HttpError when Post-op note not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(postOpNoteService.getpostOpNoteById('non-existent-id')).rejects.toThrow(HttpError);
    });
  });

  describe('createpostOpNote', () => {
    it('should create Post-op note and default record_status to DRAFT', async () => {
      const createData = {
        theatre_case_id: theatreCaseId,
        note: 'Stable after surgery',
      };
      postOpNoteRepository.create.mockResolvedValue(mockPostOpNote);
      postOpNoteRepository.findById.mockResolvedValue(mockPostOpNote);

      const result = await postOpNoteService.createpostOpNote(createData, userId, ipAddress);

      expect(result).toEqual(
        expect.objectContaining({
          id: noteId,
          display_id: 'PON0001',
          record_status: 'DRAFT',
        })
      );
      expect(postOpNoteRepository.create).toHaveBeenCalledWith({
        ...createData,
        record_status: 'DRAFT',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'CREATE',
        entity: 'post_op_note',
        entity_id: noteId,
        diff: { after: mockPostOpNote },
        ip_address: ipAddress,
      });
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.foreign_key_field', 400);
      postOpNoteRepository.create.mockRejectedValue(httpError);

      await expect(
        postOpNoteService.createpostOpNote({ theatre_case_id: theatreCaseId }, userId, ipAddress)
      ).rejects.toThrow(httpError);
    });
  });

  describe('updatepostOpNote', () => {
    it('should update Post-op note', async () => {
      const updatedPostOpNote = {
        ...mockPostOpNote,
        record_status: 'FINALIZED',
      };

      postOpNoteRepository.findById
        .mockResolvedValueOnce(mockPostOpNote)
        .mockResolvedValueOnce(updatedPostOpNote);
      postOpNoteRepository.update.mockResolvedValue(updatedPostOpNote);

      const result = await postOpNoteService.updatepostOpNote(
        noteId,
        { record_status: 'FINALIZED' },
        userId,
        ipAddress
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: noteId,
          record_status: 'FINALIZED',
        })
      );
      expect(postOpNoteRepository.update).toHaveBeenCalledWith(noteId, {
        record_status: 'FINALIZED',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'UPDATE',
        entity: 'post_op_note',
        entity_id: noteId,
        diff: {
          before: mockPostOpNote,
          after: updatedPostOpNote,
        },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when Post-op note not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        postOpNoteService.updatepostOpNote('non-existent-id', { note: 'x' }, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletepostOpNote', () => {
    it('should delete Post-op note', async () => {
      postOpNoteRepository.findById.mockResolvedValue(mockPostOpNote);
      postOpNoteRepository.softDelete.mockResolvedValue(mockPostOpNote);

      await postOpNoteService.deletepostOpNote(noteId, userId, ipAddress);

      expect(postOpNoteRepository.findById).toHaveBeenCalledWith(noteId);
      expect(postOpNoteRepository.softDelete).toHaveBeenCalledWith(noteId);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'DELETE',
        entity: 'post_op_note',
        entity_id: noteId,
        diff: { before: mockPostOpNote },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when Post-op note not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(postOpNoteService.deletepostOpNote('non-existent-id', userId, ipAddress)).rejects.toThrow(
        HttpError
      );
    });
  });
});
