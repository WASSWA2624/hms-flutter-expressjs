/**
 * Nursing note controller
 *
 * @module modules/nursing-note/controllers
 * @description Request handlers for nursing note endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const nursingNoteService = require('@services/nursing-note/nursing-note.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List nursing notes with pagination
 * GET /api/v1/nursing-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listNursingNotes = asyncHandler(async (req, res) => {
  const {
    admission_id,
    nurse_user_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    nurse_user_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await nursingNoteService.listNursingNotes(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.nursing_note.list.success', result.nursingNotes, result.pagination);
});

/**
 * Get nursing note by ID
 * GET /api/v1/nursing-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getNursingNoteById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const nursingNote = await nursingNoteService.getNursingNoteById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nursing_note.get.success', nursingNote);
});

/**
 * Create new nursing note
 * POST /api/v1/nursing-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createNursingNote = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const nursingNote = await nursingNoteService.createNursingNote(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.nursing_note.create.success', nursingNote);
});

/**
 * Update nursing note
 * PUT /api/v1/nursing-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateNursingNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const nursingNote = await nursingNoteService.updateNursingNote(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.nursing_note.update.success', nursingNote);
});

/**
 * Delete nursing note (soft delete)
 * DELETE /api/v1/nursing-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteNursingNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await nursingNoteService.deleteNursingNote(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listNursingNotes,
  getNursingNoteById,
  createNursingNote,
  updateNursingNote,
  deleteNursingNote
};
