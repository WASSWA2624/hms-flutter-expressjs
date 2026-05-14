/**
 * System change log routes
 *
 * @module modules/system-change-log/routes
 * @description System change log endpoints mounted at /api/v1/system-change-logs
 */

const express = require('express');
const router = express.Router();
const systemChangeLogController = require('@controllers/system-change-log/system-change-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createSystemChangeLogSchema,
  updateSystemChangeLogSchema,
  approveSystemChangeLogSchema,
  implementSystemChangeLogSchema,
  systemChangeLogIdParamsSchema,
  listSystemChangeLogsQuerySchema,
} = require('@validations/system-change-log/system-change-log.schema');

const COMPLIANCE_READ_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const COMPLIANCE_WRITE_SCOPES = COMPLIANCE_READ_SCOPES;

router.get(
  '/',
  validateRequest({ query: listSystemChangeLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  systemChangeLogController.listSystemChangeLogs
);

router.get(
  '/:id',
  validateRequest({ params: systemChangeLogIdParamsSchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  systemChangeLogController.getSystemChangeLogById
);

router.post(
  '/',
  validateRequest({ body: createSystemChangeLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  systemChangeLogController.createSystemChangeLog
);

router.put(
  '/:id',
  validateRequest({ params: systemChangeLogIdParamsSchema, body: updateSystemChangeLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  systemChangeLogController.updateSystemChangeLog
);

router.post(
  '/:id/approve',
  validateRequest({ params: systemChangeLogIdParamsSchema, body: approveSystemChangeLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  systemChangeLogController.approveSystemChangeLog
);

router.post(
  '/:id/implement',
  validateRequest({ params: systemChangeLogIdParamsSchema, body: implementSystemChangeLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  systemChangeLogController.implementSystemChangeLog
);

module.exports = router;
