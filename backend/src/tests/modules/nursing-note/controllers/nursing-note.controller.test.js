/**
 * Nursing note controller tests
 *
 * @module tests/modules/nursing-note/controllers
 * Per testing.mdc: Mock all service dependencies
 */

jest.mock('@services/nursing-note/nursing-note.service');
jest.mock('@lib/response');

const nursingNoteService = require('@services/nursing-note/nursing-note.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const nursingNoteController = require('@controllers/nursing-note/nursing-note.controller');

describe('Nursing Note Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listNursingNotes', () => {
    it('should list nursing notes successfully', async () => {
      const mockResult = {
        nursingNotes: [{ id: 'note-1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      nursingNoteService.listNursingNotes.mockResolvedValue(mockResult);

      req.query = { page: '1', limit: '20' };

      await nursingNoteController.listNursingNotes(req, res);

      expect(nursingNoteService.listNursingNotes).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.nursing_note.list.success',
        mockResult.nursingNotes,
        mockResult.pagination
      );
    });
  });

  describe('getNursingNoteById', () => {
    it('should get nursing note by ID successfully', async () => {
      const mockNote = { id: 'note-123', note: 'Content' };
      nursingNoteService.getNursingNoteById.mockResolvedValue(mockNote);

      req.params = { id: 'note-123' };

      await nursingNoteController.getNursingNoteById(req, res);

      expect(nursingNoteService.getNursingNoteById).toHaveBeenCalledWith(
        'note-123',
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.nursing_note.get.success',
        mockNote
      );
    });
  });

  describe('createNursingNote', () => {
    it('should create nursing note successfully', async () => {
      const mockNote = { id: 'note-123' };
      nursingNoteService.createNursingNote.mockResolvedValue(mockNote);

      req.body = {
        admission_id: 'admission-123',
        nurse_user_id: 'user-123',
        note: 'Content'
      };

      await nursingNoteController.createNursingNote(req, res);

      expect(nursingNoteService.createNursingNote).toHaveBeenCalledWith(
        req.body,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.nursing_note.create.success',
        mockNote
      );
    });
  });

  describe('updateNursingNote', () => {
    it('should update nursing note successfully', async () => {
      const mockNote = { id: 'note-123', note: 'Updated' };
      nursingNoteService.updateNursingNote.mockResolvedValue(mockNote);

      req.params = { id: 'note-123' };
      req.body = { note: 'Updated' };

      await nursingNoteController.updateNursingNote(req, res);

      expect(nursingNoteService.updateNursingNote).toHaveBeenCalledWith(
        'note-123',
        req.body,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.nursing_note.update.success',
        mockNote
      );
    });
  });

  describe('deleteNursingNote', () => {
    it('should delete nursing note successfully', async () => {
      nursingNoteService.deleteNursingNote.mockResolvedValue();

      req.params = { id: 'note-123' };

      await nursingNoteController.deleteNursingNote(req, res);

      expect(nursingNoteService.deleteNursingNote).toHaveBeenCalledWith(
        'note-123',
        'user-123',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
