/**
 * PHI access log routes
 *
 * @module modules/phi-access-log/routes
 * @description Route definitions for PHI access log endpoints.
 * Per module-creation.mdc: Mount endpoints as per P010_api_endpoints.mdc
 * Per api.mdc: All routes must be under /api/v1
 */

const express = require('express');
const router = express.Router();

// Middleware
const validate = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');

// Schemas
const {
  createPhiAccessLogSchema,
  phiAccessLogIdParamsSchema,
  userIdParamsSchema,
  listPhiAccessLogsQuerySchema
} = require('@modules/phi-access-log/schemas/phi-access-log.schema');

// Controller
const phiAccessLogController = require('@modules/phi-access-log/controllers/phi-access-log.controller');

const COMPLIANCE_READ_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const COMPLIANCE_WRITE_SCOPES = COMPLIANCE_READ_SCOPES;

/**
 * @route GET /api/v1/phi-access-logs/user/:userId
 * @desc Get PHI access logs by user ID
 * @access Private (requires authentication)
 */
router.get(
  '/user/:userId',
  validate({ params: userIdParamsSchema, query: listPhiAccessLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  phiAccessLogController.getPhiAccessLogsByUserId
);

/**
 * @route GET /api/v1/phi-access-logs/:id
 * @desc Get PHI access log by ID
 * @access Private (requires authentication)
 */
router.get(
  '/:id',
  validate({ params: phiAccessLogIdParamsSchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  phiAccessLogController.getPhiAccessLogById
);

/**
 * @route GET /api/v1/phi-access-logs
 * @desc Get paginated list of PHI access logs
 * @access Private (requires authentication)
 */
router.get(
  '/',
  validate({ query: listPhiAccessLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  phiAccessLogController.getPhiAccessLogs
);

/**
 * @route POST /api/v1/phi-access-logs
 * @desc Create new PHI access log
 * @access Private (requires authentication)
 */
router.post(
  '/',
  validate({ body: createPhiAccessLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  phiAccessLogController.createPhiAccessLog
);

module.exports = router;
