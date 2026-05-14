const express = require('express');
const reportDefinitionController = require('@controllers/report-definition/report-definition.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createReportDefinitionSchema,
  listReportDefinitionsQuerySchema,
  reportDefinitionIdParamsSchema,
  runReportDefinitionNowSchema,
  updateReportDefinitionSchema,
} = require('@validations/report-definition/report-definition.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listReportDefinitionsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportDefinitionController.listReportDefinitions
);

router.get(
  '/:id',
  validateRequest({ params: reportDefinitionIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportDefinitionController.getReportDefinitionById
);

router.post(
  '/',
  validateRequest({ body: createReportDefinitionSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportDefinitionController.createReportDefinition
);

router.put(
  '/:id',
  validateRequest({ params: reportDefinitionIdParamsSchema, body: updateReportDefinitionSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportDefinitionController.updateReportDefinition
);

router.delete(
  '/:id',
  validateRequest({ params: reportDefinitionIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  reportDefinitionController.deleteReportDefinition
);

router.post(
  '/:id/run-now',
  validateRequest({ params: reportDefinitionIdParamsSchema, body: runReportDefinitionNowSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportDefinitionController.runReportDefinitionNow
);

module.exports = router;
