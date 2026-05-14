/**
 * Audit log routes
 *
 * @module modules/audit-log/routes
 * @description Route definitions for audit log endpoints.
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
  auditLogIdParamsSchema,
  userIdParamsSchema,
  entityParamsSchema,
  listAuditLogsQuerySchema
} = require('@modules/audit-log/schemas/audit-log.schema');

// Controller
const auditLogController = require('@modules/audit-log/controllers/audit-log.controller');

const COMPLIANCE_READ_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @route GET /api/v1/audit-logs/user/:userId
 * @desc Get audit logs by user ID
 * @access Private (requires authentication)
 */
router.get(
  '/user/:userId',
  validate({ params: userIdParamsSchema, query: listAuditLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  auditLogController.getAuditLogsByUserId
);

/**
 * @route GET /api/v1/audit-logs/entity/:entity/:entityId
 * @desc Get audit logs by entity
 * @access Private (requires authentication)
 */
router.get(
  '/entity/:entity/:entityId',
  validate({ params: entityParamsSchema, query: listAuditLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  auditLogController.getAuditLogsByEntity
);

/**
 * @route GET /api/v1/audit-logs/:id
 * @desc Get audit log by ID
 * @access Private (requires authentication)
 */
router.get(
  '/:id',
  validate({ params: auditLogIdParamsSchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  auditLogController.getAuditLogById
);

/**
 * @route GET /api/v1/audit-logs
 * @desc Get paginated list of audit logs
 * @access Private (requires authentication)
 */
router.get(
  '/',
  validate({ query: listAuditLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  auditLogController.getAuditLogs
);

module.exports = router;
