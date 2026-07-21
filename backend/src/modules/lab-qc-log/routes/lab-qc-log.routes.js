/**
 * Lab QC log routes
 *
 * @module modules/lab-qc-log/routes
 * @description Lab QC log endpoints mounted at /api/v1/lab-qc-logs
 */

const express = require('express');
const labQcLogController = require('@controllers/lab-qc-log/lab-qc-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabQcLogSchema,
  updateLabQcLogSchema,
  labQcLogIdParamsSchema,
  listLabQcLogsQuerySchema} = require('@validations/lab-qc-log/lab-qc-log.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabQcLogsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labQcLogController.listLabQcLogs
);

router.get(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labQcLogController.getLabQcLogById
);

router.post(
  '/',
  validateRequest({ body: createLabQcLogSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labQcLogController.createLabQcLog
);

router.put(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema, body: updateLabQcLogSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labQcLogController.updateLabQcLog
);

router.delete(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labQcLogController.deleteLabQcLog
);

module.exports = router;
