const express = require('express');
const dayCloseController = require('@controllers/day-close/day-close.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  approveDayCloseSchema,
  createDayCloseSchema,
  dayCloseIdParamsSchema,
  listDayClosesQuerySchema,
  updateDayCloseSchema,
} = require('@validations/day-close/day-close.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listDayClosesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  dayCloseController.listDayCloses
);

router.get(
  '/:id',
  validateRequest({ params: dayCloseIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  dayCloseController.getDayCloseById
);

router.post(
  '/',
  validateRequest({ body: createDayCloseSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  dayCloseController.createDayClose
);

router.put(
  '/:id',
  validateRequest({ params: dayCloseIdParamsSchema, body: updateDayCloseSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  dayCloseController.updateDayClose
);

router.post(
  '/:id/approve',
  validateRequest({ params: dayCloseIdParamsSchema, body: approveDayCloseSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_APPROVE, 'permission'),
  dayCloseController.approveDayClose
);

module.exports = router;
