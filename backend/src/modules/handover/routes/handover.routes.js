const express = require('express');
const handoverController = require('@controllers/handover/handover.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  acceptHandoverSchema,
  createHandoverSchema,
  handoverIdParamsSchema,
  listHandoversQuerySchema,
  updateHandoverSchema,
} = require('@validations/handover/handover.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listHandoversQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  handoverController.listHandovers
);

router.get(
  '/:id',
  validateRequest({ params: handoverIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  handoverController.getHandoverById
);

router.post(
  '/',
  validateRequest({ body: createHandoverSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  handoverController.createHandover
);

router.put(
  '/:id',
  validateRequest({ params: handoverIdParamsSchema, body: updateHandoverSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  handoverController.updateHandover
);

router.post(
  '/:id/accept',
  validateRequest({ params: handoverIdParamsSchema, body: acceptHandoverSchema }),
  authenticate(),
  authorize([PERMISSIONS.LAST_OFFICE_WRITE, PERMISSIONS.LAST_OFFICE_APPROVE], 'permission'),
  handoverController.acceptHandover
);

module.exports = router;
