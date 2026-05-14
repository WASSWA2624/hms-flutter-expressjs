/**
 * Clinical note controller
 *
 * @module modules/clinical-note/controllers
 * @description Request handlers for clinical note endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const clinicalNoteService = require('@services/clinical-note/clinical-note.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List clinical notes with pagination
 * GET /api/v1/clinical-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listClinicalNotes = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    author_user_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    author_user_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await clinicalNoteService.listClinicalNotes(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.clinical_note.list.success', result.clinicalNotes, result.pagination);
});

/**
 * Get clinical note by ID
 * GET /api/v1/clinical-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getClinicalNoteById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalNote = await clinicalNoteService.getClinicalNoteById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.clinical_note.get.success', clinicalNote);
});

/**
 * Create new clinical note
 * POST /api/v1/clinical-notes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createClinicalNote = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalNote = await clinicalNoteService.createClinicalNote(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.clinical_note.create.success', clinicalNote);
});

/**
 * Update clinical note
 * PUT /api/v1/clinical-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateClinicalNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalNote = await clinicalNoteService.updateClinicalNote(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.clinical_note.update.success', clinicalNote);
});

/**
 * Delete clinical note (soft delete)
 * DELETE /api/v1/clinical-notes/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteClinicalNote = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await clinicalNoteService.deleteClinicalNote(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listClinicalNotes,
  getClinicalNoteById,
  createClinicalNote,
  updateClinicalNote,
  deleteClinicalNote
};
