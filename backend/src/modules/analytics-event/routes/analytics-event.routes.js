const express = require('express');
const analyticsEventController = require('@controllers/analytics-event/analytics-event.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  analyticsEventIdParamsSchema,
  createAnalyticsEventSchema,
  listAnalyticsEventsQuerySchema,
  updateAnalyticsEventSchema,
} = require('@validations/analytics-event/analytics-event.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listAnalyticsEventsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  analyticsEventController.listAnalyticsEvents
);

router.get(
  '/:id',
  validateRequest({ params: analyticsEventIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  analyticsEventController.getAnalyticsEventById
);

router.post(
  '/',
  validateRequest({ body: createAnalyticsEventSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  analyticsEventController.createAnalyticsEvent
);

router.put(
  '/:id',
  validateRequest({ params: analyticsEventIdParamsSchema, body: updateAnalyticsEventSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  analyticsEventController.updateAnalyticsEvent
);

router.delete(
  '/:id',
  validateRequest({ params: analyticsEventIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  analyticsEventController.deleteAnalyticsEvent
);

module.exports = router;
