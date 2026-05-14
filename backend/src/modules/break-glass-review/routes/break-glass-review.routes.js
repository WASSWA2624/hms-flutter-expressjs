const express = require('express');
const breakGlassReviewController = require('@controllers/break-glass-review/break-glass-review.controller');
const { authorize, authenticate } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  breakGlassReviewIdParamsSchema,
  createBreakGlassReviewSchema,
  listBreakGlassReviewsQuerySchema,
} = require('@validations/break-glass-review/break-glass-review.schema');

const router = express.Router();

router.get('/', validateRequest({ query: listBreakGlassReviewsQuerySchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassReviewController.listBreakGlassReviews);
router.get('/:id', validateRequest({ params: breakGlassReviewIdParamsSchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassReviewController.getBreakGlassReviewById);
router.post('/', validateRequest({ body: createBreakGlassReviewSchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassReviewController.createBreakGlassReview);

module.exports = router;
