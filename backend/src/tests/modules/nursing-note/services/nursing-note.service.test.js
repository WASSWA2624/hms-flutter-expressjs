/**
 * Nursing note service tests
 *
 * @module tests/modules/nursing-note/services
 * Per testing.mdc: Mock all repository and external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock repository and audit before requiring service
jest.mock('@repositories/nursing-note/nursing-note.repository');
jest.mock('@lib/audit');

const nursingNoteRepository = require('@repositories/nursing-note/nursing-note.repository');
const { createAuditLog } = require('@lib/audit');
const nursingNoteService = require('@services/nursing-note/nursing-note.service');

describe('Nursing Note Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listNursingNotes', () => {
    it('should list nursing notes with pagination', async () => {
      const mockNotes = [
        { id: 'note-1', note: 'Note 1' },
        { id: 'note-2', note: 'Note 2' }
      ];
      nursingNoteRepository.findMany.mockResolvedValue(mockNotes);
      nursingNoteRepository.count.mockResolvedValue(10);

      const result = await nursingNoteService.listNursingNotes(
        {},
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );

      expect(result.nursingNotes).toEqual(mockNotes);
      expect(result.pagination.total).toBe(10);
      expect(result.pagination.page).toBe(1);
      expect(result.pagination.limit).toBe(20);
    });

    it('should apply filters correctly', async () => {
      nursingNoteRepository.findMany.mockResolvedValue([]);
      nursingNoteRepository.count.mockResolvedValue(0);

      await nursingNoteService.listNursingNotes(
        { admission_id: 'admission-123' },
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );

      expect(nursingNoteRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ admission_id: 'admission-123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });
  });

  describe('getNursingNoteById', () => {
    it('should get nursing note by ID', async () => {
      const mockNote = { id: 'note-123', note: 'Note content' };
      nursingNoteRepository.findById.mockResolvedValue(mockNote);

      const result = await nursingNoteService.getNursingNoteById(
        'note-123',
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockNote);
      expect(nursingNoteRepository.findById).toHaveBeenCalledWith('note-123');
    });

    it('should throw HttpError if nursing note not found', async () => {
      nursingNoteRepository.findById.mockResolvedValue(null);

      await expect(
        nursingNoteService.getNursingNoteById('note-123', 'user-123', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createNursingNote', () => {
    it('should create nursing note and audit log', async () => {
      const mockData = {
        admission_id: 'admission-123',
        nurse_user_id: 'user-123',
        note: 'Note content'
      };
      const mockNote = { id: 'note-123', ...mockData };
      nursingNoteRepository.create.mockResolvedValue(mockNote);

      const result = await nursingNoteService.createNursingNote(
        mockData,
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockNote);
      expect(nursingNoteRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'nursing_note',
          entity_id: 'note-123'
        })
      );
    });
  });

  describe('updateNursingNote', () => {
    it('should update nursing note and audit log', async () => {
      const mockBefore = { id: 'note-123', note: 'Old note' };
      const mockAfter = { id: 'note-123', note: 'New note' };
      nursingNoteRepository.findById.mockResolvedValue(mockBefore);
      nursingNoteRepository.update.mockResolvedValue(mockAfter);

      const result = await nursingNoteService.updateNursingNote(
        'note-123',
        { note: 'New note' },
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'nursing_note'
        })
      );
    });

    it('should throw HttpError if nursing note not found', async () => {
      nursingNoteRepository.findById.mockResolvedValue(null);

      await expect(
        nursingNoteService.updateNursingNote('note-123', {}, 'user-123', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteNursingNote', () => {
    it('should delete nursing note and audit log', async () => {
      const mockNote = { id: 'note-123', note: 'Note content' };
      nursingNoteRepository.findById.mockResolvedValue(mockNote);
      nursingNoteRepository.softDelete.mockResolvedValue(mockNote);

      await nursingNoteService.deleteNursingNote('note-123', 'user-123', '127.0.0.1');

      expect(nursingNoteRepository.softDelete).toHaveBeenCalledWith('note-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'DELETE',
          entity: 'nursing_note'
        })
      );
    });

    it('should throw HttpError if nursing note not found', async () => {
      nursingNoteRepository.findById.mockResolvedValue(null);

      await expect(
        nursingNoteService.deleteNursingNote('note-123', 'user-123', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });
});
