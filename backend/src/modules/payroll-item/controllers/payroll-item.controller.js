/**
 * Payroll item controller
 *
 * @module modules/payroll-item/controllers
 * @description Request handlers for payroll item endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const payrollItemService = require('@services/payroll-item/payroll-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List payroll items with pagination
 * GET /api/v1/payroll-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPayrollItems = asyncHandler(async (req, res) => {
  const {
    payroll_run_id,
    staff_profile_id,
    currency,
    amount_min,
    amount_max,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    payroll_run_id,
    staff_profile_id,
    currency,
    amount_min,
    amount_max
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await payrollItemService.listPayrollItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.payroll_item.list.success', result.payrollItems, result.pagination);
});

/**
 * Get payroll item by ID
 * GET /api/v1/payroll-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPayrollItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollItem = await payrollItemService.getPayrollItemById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.payroll_item.get.success', payrollItem);
});

/**
 * Create new payroll item
 * POST /api/v1/payroll-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPayrollItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollItem = await payrollItemService.createPayrollItem(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.payroll_item.create.success', payrollItem);
});

/**
 * Update payroll item
 * PUT /api/v1/payroll-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePayrollItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollItem = await payrollItemService.updatePayrollItem(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.payroll_item.update.success', payrollItem);
});

/**
 * Delete payroll item (soft delete)
 * DELETE /api/v1/payroll-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePayrollItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await payrollItemService.deletePayrollItem(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPayrollItems,
  getPayrollItemById,
  createPayrollItem,
  updatePayrollItem,
  deletePayrollItem
};
