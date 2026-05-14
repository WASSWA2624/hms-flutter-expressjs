/**
 * Shift swap request routes
 *
 * @module modules/shift-swap-request/routes
 * @description Shift swap request endpoints mounted at /api/v1/shift-swap-requests
 */

const express = require('express');
const router = express.Router();
const shiftSwapRequestController = require('@controllers/shift-swap-request/shift-swap-request.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createShiftSwapRequestSchema,
  updateShiftSwapRequestSchema,
  shiftSwapRequestIdParamsSchema,
  listShiftSwapRequestsQuerySchema,
} = require('@validations/shift-swap-request/shift-swap-request.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get(
  '/',
  validateRequest({ query: listShiftSwapRequestsQuerySchema }),
  authenticate(),
  authorize(HR_READ_SCOPES, 'permission'),
  shiftSwapRequestController.listShiftSwapRequests
);

router.get(
  '/:id',
  validateRequest({ params: shiftSwapRequestIdParamsSchema }),
  authenticate(),
  authorize(HR_READ_SCOPES, 'permission'),
  shiftSwapRequestController.getShiftSwapRequestById
);

router.post(
  '/',
  validateRequest({ body: createShiftSwapRequestSchema }),
  authenticate(),
  authorize(HR_WRITE_SCOPES, 'permission'),
  shiftSwapRequestController.createShiftSwapRequest
);

router.put(
  '/:id',
  validateRequest({ params: shiftSwapRequestIdParamsSchema, body: updateShiftSwapRequestSchema }),
  authenticate(),
  authorize(HR_WRITE_SCOPES, 'permission'),
  shiftSwapRequestController.updateShiftSwapRequest
);

router.delete(
  '/:id',
  validateRequest({ params: shiftSwapRequestIdParamsSchema }),
  authenticate(),
  authorize(HR_WRITE_SCOPES, 'permission'),
  shiftSwapRequestController.deleteShiftSwapRequest
);

module.exports = router;
