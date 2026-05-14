const breakGlassReviewService = require('@services/break-glass-review/break-glass-review.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated, sendSuccess } = require('@lib/response');

const buildContext = (req) => ({
  user: req.user || {},
  user_id: req.user?.id || req.user?.user_id || null,
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.body?.tenant_id || null,
  ip_address: req.ip,
});

const listBreakGlassReviews = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, ...filters } = req.query;
  const result = await breakGlassReviewService.listBreakGlassReviews(filters, Number(page), Number(limit), buildContext(req));
  sendPaginated(res, 'messages.break_glass_review.list_success', result.reviews, result.pagination);
});

const getBreakGlassReviewById = asyncHandler(async (req, res) => {
  const result = await breakGlassReviewService.getBreakGlassReviewById(req.params.id);
  sendSuccess(res, 200, 'messages.break_glass_review.get_success', result);
});

const createBreakGlassReview = asyncHandler(async (req, res) => {
  const result = await breakGlassReviewService.createBreakGlassReview(req.body, buildContext(req));
  sendSuccess(res, 201, 'messages.break_glass_review.create_success', result);
});

module.exports = {
  createBreakGlassReview,
  getBreakGlassReviewById,
  listBreakGlassReviews,
};
