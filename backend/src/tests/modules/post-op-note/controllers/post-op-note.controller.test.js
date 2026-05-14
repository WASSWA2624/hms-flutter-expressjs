/**
 * Post-op note controller tests
 *
 * @module tests/modules/post-op-note/controllers
 * @description Tests for Post-op note request handlers
 * Per testing.mdc: Controller tests must mock services
 */

const postOpNoteController = require('@controllers/post-op-note/post-op-note.controller');
const postOpNoteService = require('@services/post-op-note/post-op-note.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('@services/post-op-note/post-op-note.service');
jest.mock('@lib/response');

describe('Post-op note Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listpostOpNotes', () => {
    const mockResult = {
      post_op_notes: [
        {
          id: '550e8400-e29b-41d4-a716-446655440000',
          encounter_id: '550e8400-e29b-41d4-a716-446655440001',
          scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
          status: 'SCHEDULED'
        }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list Post-op notes with default pagination', async () => {
      req.query = {};
      postOpNoteService.listpostOpNotes.mockResolvedValue(mockResult);

      await postOpNoteController.listpostOpNotes(req, res);

      expect(postOpNoteService.listpostOpNotes).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.post_op_note.list.success',
        mockResult.post_op_notes,
        mockResult.pagination
      );
    });

    it('should list Post-op notes with custom pagination', async () => {
      req.query = { page: '2', limit: '10', sort_by: 'scheduled_at', order: 'desc' };
      postOpNoteService.listpostOpNotes.mockResolvedValue(mockResult);

      await postOpNoteController.listpostOpNotes(req, res);

      expect(postOpNoteService.listpostOpNotes).toHaveBeenCalledWith(
        expect.any(Object),
        2,
        10,
        'scheduled_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should list Post-op notes with filters', async () => {
      req.query = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'SCHEDULED',
        scheduled_from: '2026-01-20T00:00:00.000Z',
        scheduled_to: '2026-01-20T23:59:59.000Z'
      };
      postOpNoteService.listpostOpNotes.mockResolvedValue(mockResult);

      await postOpNoteController.listpostOpNotes(req, res);

      expect(postOpNoteService.listpostOpNotes).toHaveBeenCalledWith(
        expect.objectContaining({
          encounter_id: '550e8400-e29b-41d4-a716-446655440001',
          status: 'SCHEDULED',
          scheduled_from: '2026-01-20T00:00:00.000Z',
          scheduled_to: '2026-01-20T23:59:59.000Z'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getpostOpNoteById', () => {
    const mockpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    it('should get Post-op note by id', async () => {
      req.params = { id: mockpostOpNote.id };
      postOpNoteService.getpostOpNoteById.mockResolvedValue(mockpostOpNote);

      await postOpNoteController.getpostOpNoteById(req, res);

      expect(postOpNoteService.getpostOpNoteById).toHaveBeenCalledWith(
        mockpostOpNote.id,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.post_op_note.get.success',
        mockpostOpNote
      );
    });
  });

  describe('createpostOpNote', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: '2026-01-20T10:00:00.000Z',
      status: 'SCHEDULED'
    };

    const mockCreatedpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create Post-op note', async () => {
      req.body = createData;
      postOpNoteService.createpostOpNote.mockResolvedValue(mockCreatedpostOpNote);

      await postOpNoteController.createpostOpNote(req, res);

      expect(postOpNoteService.createpostOpNote).toHaveBeenCalledWith(
        createData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.post_op_note.create.success',
        mockCreatedpostOpNote
      );
    });
  });

  describe('updatepostOpNote', () => {
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockUpdatedpostOpNote = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'IN_PROGRESS'
    };

    it('should update Post-op note', async () => {
      req.params = { id: mockUpdatedpostOpNote.id };
      req.body = updateData;
      postOpNoteService.updatepostOpNote.mockResolvedValue(mockUpdatedpostOpNote);

      await postOpNoteController.updatepostOpNote(req, res);

      expect(postOpNoteService.updatepostOpNote).toHaveBeenCalledWith(
        mockUpdatedpostOpNote.id,
        updateData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.post_op_note.update.success',
        mockUpdatedpostOpNote
      );
    });
  });

  describe('deletepostOpNote', () => {
    it('should delete Post-op note', async () => {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      req.params = { id };
      postOpNoteService.deletepostOpNote.mockResolvedValue();

      await postOpNoteController.deletepostOpNote(req, res);

      expect(postOpNoteService.deletepostOpNote).toHaveBeenCalledWith(
        id,
        'user-123',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
