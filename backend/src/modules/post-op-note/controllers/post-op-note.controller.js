/**
 * Post-op note controller
 *
 * @module modules/post-op-note/controllers
 * @description Request handlers for Post-op note endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const postOpNoteService = require('@services/post-op-note/post-op-note.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List Post-op notes with pagination
 * GET /api/v1/post-op-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listpostOpNotes = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const {
    theatre_case_id,
    encounter_id,
    patient_id,
    status,
    record_status,
    scheduled_from,
    scheduled_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    theatre_case_id,
    encounter_id,
    patient_id,
    status,
    record_status,
    scheduled_from,
    scheduled_to,
    search
  };

  const result = await postOpNoteService.listpostOpNotes(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.post_op_note.list.success', result.post_op_notes, result.pagination);
});

/**
 * Get Post-op note by ID
 * GET /api/v1/post-op-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getpostOpNoteById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const postOpNote = await postOpNoteService.getpostOpNoteById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.post_op_note.get.success', postOpNote);
});

/**
 * Create new Post-op note
 * POST /api/v1/post-op-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createpostOpNote = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const postOpNote = await postOpNoteService.createpostOpNote(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.post_op_note.create.success', postOpNote);
});

/**
 * Update Post-op note
 * PUT /api/v1/post-op-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatepostOpNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const postOpNote = await postOpNoteService.updatepostOpNote(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.post_op_note.update.success', postOpNote);
});

/**
 * Delete Post-op note (soft delete)
 * DELETE /api/v1/post-op-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletepostOpNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await postOpNoteService.deletepostOpNote(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listpostOpNotes,
  getpostOpNoteById,
  createpostOpNote,
  updatepostOpNote,
  deletepostOpNote
};
