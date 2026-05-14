/**
 * Anesthesia record controller
 *
 * @module modules/anesthesia-record/controllers
 * @description Request handlers for anesthesia record endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const anesthesiaRecordService = require('@services/anesthesia-record/anesthesia-record.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List anesthesia records with pagination
 * GET /api/v1/anesthesia-records
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAnesthesiaRecords = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;
  const {
    theatre_case_id,
    anesthetist_user_id,
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
    anesthetist_user_id,
    encounter_id,
    patient_id,
    status,
    record_status,
    scheduled_from,
    scheduled_to,
    search
  };

  const result = await anesthesiaRecordService.listAnesthesiaRecords(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.anesthesia_record.list.success', result.anesthesia_records, result.pagination);
});

/**
 * Get anesthesia record by ID
 * GET /api/v1/anesthesia-records/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAnesthesiaRecordById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const anesthesiaRecord = await anesthesiaRecordService.getAnesthesiaRecordById(
    id,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.anesthesia_record.get.success', anesthesiaRecord);
});

/**
 * Create new anesthesia record
 * POST /api/v1/anesthesia-records
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAnesthesiaRecord = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const anesthesiaRecord = await anesthesiaRecordService.createAnesthesiaRecord(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.anesthesia_record.create.success', anesthesiaRecord);
});

/**
 * Update anesthesia record
 * PUT /api/v1/anesthesia-records/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAnesthesiaRecord = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const anesthesiaRecord = await anesthesiaRecordService.updateAnesthesiaRecord(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.anesthesia_record.update.success', anesthesiaRecord);
});

/**
 * Delete anesthesia record (soft delete)
 * DELETE /api/v1/anesthesia-records/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAnesthesiaRecord = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await anesthesiaRecordService.deleteAnesthesiaRecord(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listAnesthesiaRecords,
  getAnesthesiaRecordById,
  createAnesthesiaRecord,
  updateAnesthesiaRecord,
  deleteAnesthesiaRecord
};
