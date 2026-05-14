const abacPolicyService = require('@services/abac-policy/abac-policy.service');
const { asyncHandler } = require('@lib/async');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.body?.tenant_id || null,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.body?.facility_id || null,
  branch_id: req.user?.branch_id || req.user?.branchId || req.body?.branch_id || null,
  ip_address: req.ip,
});

const listAbacPolicies = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, ...filters } = req.query;
  const result = await abacPolicyService.listAbacPolicies(filters, Number(page), Number(limit), buildContext(req));
  sendPaginated(res, 'messages.abac_policy.list_success', result.policies, result.pagination);
});

const getAbacPolicyById = asyncHandler(async (req, res) => {
  const result = await abacPolicyService.getAbacPolicyById(req.params.id);
  sendSuccess(res, 200, 'messages.abac_policy.get_success', result);
});

const createAbacPolicy = asyncHandler(async (req, res) => {
  const result = await abacPolicyService.createAbacPolicy(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.abac_policy.create_success', result);
});

const updateAbacPolicy = asyncHandler(async (req, res) => {
  const result = await abacPolicyService.updateAbacPolicy(req.params.id, req.body, buildContext(req));
  sendSuccess(res, 200, 'messages.abac_policy.update_success', result);
});

const deleteAbacPolicy = asyncHandler(async (req, res) => {
  await abacPolicyService.deleteAbacPolicy(req.params.id, buildContext(req));
  sendNoContent(res);
});

module.exports = {
  createAbacPolicy,
  deleteAbacPolicy,
  getAbacPolicyById,
  listAbacPolicies,
  updateAbacPolicy,
};
