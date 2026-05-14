/**
 * Shift template controller
 */
const shiftTemplateService = require('@services/shift-template/shift-template.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const list = asyncHandler(async (req, res) => {
  const { tenant_id, facility_id, shift_type, is_active, page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc' } = req.query;
  const result = await shiftTemplateService.listShiftTemplates(
    { tenant_id, facility_id, shift_type, is_active },
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip
  );
  sendPaginated(res, 'messages.shift_template.list.success', result.items, result.pagination);
});

const getById = asyncHandler(async (req, res) => {
  const item = await shiftTemplateService.getById(req.params.id, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.shift_template.get.success', item);
});

const create = asyncHandler(async (req, res) => {
  const item = await shiftTemplateService.create(req.body, req.user?.id, req.ip);
  sendSuccess(res, 201, 'messages.shift_template.create.success', item);
});

const update = asyncHandler(async (req, res) => {
  const item = await shiftTemplateService.update(req.params.id, req.body, req.user?.id, req.ip);
  sendSuccess(res, 200, 'messages.shift_template.update.success', item);
});

const remove = asyncHandler(async (req, res) => {
  await shiftTemplateService.remove(req.params.id, req.user?.id, req.ip);
  sendNoContent(res);
});

module.exports = { list, getById, create, update, remove };
