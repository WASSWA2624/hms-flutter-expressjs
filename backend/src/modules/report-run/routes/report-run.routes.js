const express = require('express');
const reportRunController = require('@controllers/report-run/report-run.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createReportRunSchema,
  listReportRunsQuerySchema,
  reportRunIdParamsSchema,
  reportRunMutationBodySchema,
  updateReportRunSchema,
} = require('@validations/report-run/report-run.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listReportRunsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportRunController.listReportRuns
);

router.get(
  '/:id',
  validateRequest({ params: reportRunIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportRunController.getReportRunById
);

router.post(
  '/',
  validateRequest({ body: createReportRunSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportRunController.createReportRun
);

router.put(
  '/:id',
  validateRequest({ params: reportRunIdParamsSchema, body: updateReportRunSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportRunController.updateReportRun
);

router.delete(
  '/:id',
  validateRequest({ params: reportRunIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  reportRunController.deleteReportRun
);

router.post(
  '/:id/retry',
  validateRequest({ params: reportRunIdParamsSchema, body: reportRunMutationBodySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportRunController.retryReportRun
);

router.post(
  '/:id/cancel',
  validateRequest({ params: reportRunIdParamsSchema, body: reportRunMutationBodySchema.partial() }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportRunController.cancelReportRun
);

router.get(
  '/:id/download',
  validateRequest({ params: reportRunIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportRunController.downloadReportRun
);

module.exports = router;
