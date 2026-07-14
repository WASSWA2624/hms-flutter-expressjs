const express = require('express');
const patientReportController = require('@controllers/patient-report/patient-report.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createPatientReportJobSchema,
  listSectionsQuerySchema,
  patientReportJobIdParamsSchema,
  recordPrintEventSchema,
} = require('@validations/patient-report/patient-report.schema');

const router = express.Router();

/**
 * @route /api/v1/patient-reports/sections
 */
router.get(
  '/sections',
  validateRequest({ query: listSectionsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientReportController.listSections
);

/**
 * @route /api/v1/patient-reports/print-events
 */
router.post(
  '/print-events',
  validateRequest({ body: recordPrintEventSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientReportController.recordPrintEvent
);

/**
 * @route /api/v1/patient-reports/jobs
 */
router.post(
  '/jobs',
  validateRequest({ body: createPatientReportJobSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientReportController.createJob
);

/**
 * @route /api/v1/patient-reports/jobs/:id
 */
router.get(
  '/jobs/:id',
  validateRequest({ params: patientReportJobIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientReportController.getJobById
);

/**
 * @route /api/v1/patient-reports/jobs/:id/download
 */
router.get(
  '/jobs/:id/download',
  validateRequest({ params: patientReportJobIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientReportController.downloadJob
);

module.exports = router;
