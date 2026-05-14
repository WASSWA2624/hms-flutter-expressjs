const officeContextService = require('@services/office-context/office-context.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');
const { buildContext } = require('@lib/last-office/shared');

const listOfficeContexts = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, sort_by, order, ...filters } = req.query;
  const result = await officeContextService.listOfficeContexts(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.office_context.list_success', result.officeContexts, result.pagination);
});

const getCurrentOfficeContext = asyncHandler(async (req, res) => {
  const result = await officeContextService.getCurrentOfficeContext(req.query, buildContext(req));
  sendSuccess(res, 200, 'messages.office_context.get_success', result);
});

const getOfficeContextById = asyncHandler(async (req, res) => {
  const result = await officeContextService.getOfficeContextById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.office_context.get_success', result);
});

const createOfficeContext = asyncHandler(async (req, res) => {
  const result = await officeContextService.createOfficeContext(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.office_context.create_success', result);
});

const updateOfficeContext = asyncHandler(async (req, res) => {
  const result = await officeContextService.updateOfficeContext(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.office_context.update_success', result);
});

const closeOfficeContext = asyncHandler(async (req, res) => {
  const result = await officeContextService.closeOfficeContext(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.office_context.update_success', result);
});

module.exports = {
  closeOfficeContext,
  createOfficeContext,
  getCurrentOfficeContext,
  getOfficeContextById,
  listOfficeContexts,
  updateOfficeContext,
};
