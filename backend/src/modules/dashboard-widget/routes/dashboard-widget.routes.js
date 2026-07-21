const express = require('express');
const dashboardWidgetController = require('@controllers/dashboard-widget/dashboard-widget.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createDashboardWidgetSchema,
  dashboardSummaryQuerySchema,
  dashboardWidgetIdParamsSchema,
  listDashboardWidgetsQuerySchema,
  updateDashboardWidgetSchema,
} = require('@validations/dashboard-widget/dashboard-widget.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listDashboardWidgetsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  dashboardWidgetController.listDashboardWidgets
);

router.get(
  '/summary',
  validateRequest({ query: dashboardSummaryQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  dashboardWidgetController.getDashboardSummary
);

router.get(
  '/:id',
  validateRequest({ params: dashboardWidgetIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  dashboardWidgetController.getDashboardWidgetById
);

router.post(
  '/',
  validateRequest({ body: createDashboardWidgetSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  dashboardWidgetController.createDashboardWidget
);

router.put(
  '/:id',
  validateRequest({ params: dashboardWidgetIdParamsSchema, body: updateDashboardWidgetSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  dashboardWidgetController.updateDashboardWidget
);

router.delete(
  '/:id',
  validateRequest({ params: dashboardWidgetIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  dashboardWidgetController.deleteDashboardWidget
);

module.exports = router;
