/**
 * Payroll run controller
 *
 * @module modules/payroll-run/controllers
 * @description Request handlers for payroll run endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const payrollRunService = require('@services/payroll-run/payroll-run.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List payroll runs with pagination
 * GET /api/v1/payroll-runs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPayrollRuns = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    status,
    period_start_from,
    period_start_to,
    period_end_from,
    period_end_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    status,
    period_start_from,
    period_start_to,
    period_end_from,
    period_end_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await payrollRunService.listPayrollRuns(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.payroll_run.list.success', result.payrollRuns, result.pagination);
});

/**
 * Get payroll run by ID
 * GET /api/v1/payroll-runs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPayrollRunById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollRun = await payrollRunService.getPayrollRunById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.payroll_run.get.success', payrollRun);
});

/**
 * Create new payroll run
 * POST /api/v1/payroll-runs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPayrollRun = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollRun = await payrollRunService.createPayrollRun(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.payroll_run.create.success', payrollRun);
});

/**
 * Update payroll run
 * PUT /api/v1/payroll-runs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePayrollRun = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const payrollRun = await payrollRunService.updatePayrollRun(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.payroll_run.update.success', payrollRun);
});

/**
 * Delete payroll run (soft delete)
 * DELETE /api/v1/payroll-runs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePayrollRun = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await payrollRunService.deletePayrollRun(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPayrollRuns,
  getPayrollRunById,
  createPayrollRun,
  updatePayrollRun,
  deletePayrollRun
};
