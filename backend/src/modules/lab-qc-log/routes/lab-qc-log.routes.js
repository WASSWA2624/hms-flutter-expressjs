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
const { ROLES } = require('@config/roles');
const {
  createLabQcLogSchema,
  updateLabQcLogSchema,
  labQcLogIdParamsSchema,
  listLabQcLogsQuerySchema,
} = require('@validations/lab-qc-log/lab-qc-log.schema');

const router = express.Router();

const LAB_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LAB_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

router.get(
  '/',
  validateRequest({ query: listLabQcLogsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labQcLogController.listLabQcLogs
);

router.get(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labQcLogController.getLabQcLogById
);

router.post(
  '/',
  validateRequest({ body: createLabQcLogSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labQcLogController.createLabQcLog
);

router.put(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema, body: updateLabQcLogSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labQcLogController.updateLabQcLog
);

router.delete(
  '/:id',
  validateRequest({ params: labQcLogIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labQcLogController.deleteLabQcLog
);

module.exports = router;
