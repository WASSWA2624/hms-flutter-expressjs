const express = require('express');
const officeContextController = require('@controllers/office-context/office-context.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  closeOfficeContextSchema,
  createOfficeContextSchema,
  currentOfficeContextQuerySchema,
  listOfficeContextsQuerySchema,
  officeContextIdParamsSchema,
  updateOfficeContextSchema,
} = require('@validations/office-context/office-context.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listOfficeContextsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  officeContextController.listOfficeContexts
);

router.get(
  '/current',
  validateRequest({ query: currentOfficeContextQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  officeContextController.getCurrentOfficeContext
);

router.get(
  '/:id',
  validateRequest({ params: officeContextIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  officeContextController.getOfficeContextById
);

router.post(
  '/',
  validateRequest({ body: createOfficeContextSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  officeContextController.createOfficeContext
);

router.put(
  '/:id',
  validateRequest({ params: officeContextIdParamsSchema, body: updateOfficeContextSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  officeContextController.updateOfficeContext
);

router.post(
  '/:id/close',
  validateRequest({ params: officeContextIdParamsSchema, body: closeOfficeContextSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  officeContextController.closeOfficeContext
);

module.exports = router;
