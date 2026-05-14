const breakGlassAccessService = require('@services/break-glass-access/break-glass-access.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.body?.tenant_id || null,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.body?.facility_id || null,
  branch_id: req.user?.branch_id || req.user?.branchId || req.body?.branch_id || null,
  ip_address: req.ip,
});

const listBreakGlassAccesses = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, ...filters } = req.query;
  const result = await breakGlassAccessService.listBreakGlassAccesses(filters, Number(page), Number(limit), buildContext(req));
  sendPaginated(res, 'messages.break_glass_access.list_success', result.accesses, result.pagination);
});

const getBreakGlassAccessById = asyncHandler(async (req, res) => {
  const result = await breakGlassAccessService.getBreakGlassAccessById(req.params.id, buildContext(req));
  sendSuccess(res, 200, 'messages.break_glass_access.get_success', result);
});

const createBreakGlassAccess = asyncHandler(async (req, res) => {
  const result = await breakGlassAccessService.createBreakGlassAccess(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.break_glass_access.create_success', result);
});

const revokeBreakGlassAccess = asyncHandler(async (req, res) => {
  const result = await breakGlassAccessService.revokeBreakGlassAccess(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.break_glass_access.revoke_success', result);
});

module.exports = {
  createBreakGlassAccess,
  getBreakGlassAccessById,
  listBreakGlassAccesses,
  revokeBreakGlassAccess,
};
