const express = require('express');
const shiftCloseController = require('@controllers/shift-close/shift-close.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  approveShiftCloseSchema,
  createShiftCloseSchema,
  listShiftClosesQuerySchema,
  shiftCloseIdParamsSchema,
  updateShiftCloseSchema,
} = require('@validations/shift-close/shift-close.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listShiftClosesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  shiftCloseController.listShiftCloses
);

router.get(
  '/:id',
  validateRequest({ params: shiftCloseIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  shiftCloseController.getShiftCloseById
);

router.post(
  '/',
  validateRequest({ body: createShiftCloseSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  shiftCloseController.createShiftClose
);

router.put(
  '/:id',
  validateRequest({ params: shiftCloseIdParamsSchema, body: updateShiftCloseSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  shiftCloseController.updateShiftClose
);

router.post(
  '/:id/approve',
  validateRequest({ params: shiftCloseIdParamsSchema, body: approveShiftCloseSchema }),
  authenticate(),
  authorize([PERMISSIONS.LAST_OFFICE_APPROVE, PERMISSIONS.FINANCIAL_APPROVE], 'permission'),
  shiftCloseController.approveShiftClose
);

module.exports = router;
