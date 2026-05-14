/**
 * Clinical term controller
 */

const clinicalTermService = require('@services/clinical-term/clinical-term.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendNoContent } = require('@lib/response');

const buildContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  roles: req.user?.roles || [],
  role: req.user?.role,
  ip_address: req.ip,
});

const listClinicalTermSuggestions = asyncHandler(async (req, res) => {
  const result = await clinicalTermService.listClinicalTermSuggestions(req.query, buildContext(req));
  return sendSuccess(res, 200, 'messages.clinical_term.suggestions.success', result);
});

const listClinicalTermFavorites = asyncHandler(async (req, res) => {
  const result = await clinicalTermService.listClinicalTermFavorites(req.query, buildContext(req));
  return sendSuccess(res, 200, 'messages.clinical_term_favorite.list.success', result);
});

const createClinicalTermFavorite = asyncHandler(async (req, res) => {
  const result = await clinicalTermService.createClinicalTermFavorite(req.body, buildContext(req));
  return sendSuccess(res, 201, 'messages.clinical_term_favorite.create.success', result);
});

const deleteClinicalTermFavorite = asyncHandler(async (req, res) => {
  await clinicalTermService.deleteClinicalTermFavorite(req.params.id, buildContext(req));
  return sendNoContent(res);
});

module.exports = {
  listClinicalTermSuggestions,
  listClinicalTermFavorites,
  createClinicalTermFavorite,
  deleteClinicalTermFavorite,
};

