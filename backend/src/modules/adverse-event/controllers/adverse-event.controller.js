/**
 * Adverse Event controller
 *
 * @module modules/adverse-event/controllers
 * @description Controllers for adverse event endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use response helpers for consistent output.
 */

const adverseEventService = require('@services/adverse-event/adverse-event.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List adverse events
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listAdverseEvents = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    ...filters
  } = req.query;

  const result = await adverseEventService.listAdverseEvents(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.adverse_event.list.success',
    result.items,
    result.pagination
  );
};

/**
 * Get adverse event by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getAdverseEventById = async (req, res) => {
  const { id } = req.params;

  const adverseEvent = await adverseEventService.getAdverseEventById(id);

  if (!adverseEvent) {
    throw new HttpError('errors.adverse_event.not_found', 404);
  }

  return sendSuccess(res, 200, 'messages.adverse_event.get.success', adverseEvent);
};

/**
 * Create adverse event
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createAdverseEvent = async (req, res) => {
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const adverseEvent = await adverseEventService.createAdverseEvent(data, auditContext);

  return sendSuccess(res, 201, 'messages.adverse_event.create.success', adverseEvent);
};

/**
 * Update adverse event
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateAdverseEvent = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const adverseEvent = await adverseEventService.updateAdverseEvent(id, data, auditContext);

  return sendSuccess(res, 200, 'messages.adverse_event.update.success', adverseEvent);
};

/**
 * Delete adverse event (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteAdverseEvent = async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  await adverseEventService.deleteAdverseEvent(id, auditContext);

  return res.status(204).send();
};

module.exports = {
  listAdverseEvents,
  getAdverseEventById,
  createAdverseEvent,
  updateAdverseEvent,
  deleteAdverseEvent
};
