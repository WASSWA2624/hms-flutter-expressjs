/**
 * Data processing log routes
 *
 * @module modules/data-processing-log/routes
 * @description Route definitions for data processing log endpoints.
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
  createDataProcessingLogSchema,
  updateDataProcessingLogSchema,
  dataProcessingLogIdParamsSchema,
  listDataProcessingLogsQuerySchema
} = require('@modules/data-processing-log/schemas/data-processing-log.schema');

// Controller
const dataProcessingLogController = require('@modules/data-processing-log/controllers/data-processing-log.controller');

const COMPLIANCE_READ_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const COMPLIANCE_WRITE_SCOPES = COMPLIANCE_READ_SCOPES;

/**
 * @route GET /api/v1/data-processing-logs/:id
 * @desc Get data processing log by ID
 * @access Private (requires authentication)
 */
router.get(
  '/:id',
  validate({ params: dataProcessingLogIdParamsSchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  dataProcessingLogController.getDataProcessingLogById
);

/**
 * @route GET /api/v1/data-processing-logs
 * @desc Get paginated list of data processing logs
 * @access Private (requires authentication)
 */
router.get(
  '/',
  validate({ query: listDataProcessingLogsQuerySchema }),
  authorize(COMPLIANCE_READ_SCOPES, 'permission'),
  dataProcessingLogController.getDataProcessingLogs
);

/**
 * @route POST /api/v1/data-processing-logs
 * @desc Create new data processing log
 * @access Private (requires authentication)
 */
router.post(
  '/',
  validate({ body: createDataProcessingLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  dataProcessingLogController.createDataProcessingLog
);

/**
 * @route PUT /api/v1/data-processing-logs/:id
 * @desc Update data processing log
 * @access Private (requires authentication)
 */
router.put(
  '/:id',
  validate({ params: dataProcessingLogIdParamsSchema, body: updateDataProcessingLogSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  dataProcessingLogController.updateDataProcessingLog
);

/**
 * @route DELETE /api/v1/data-processing-logs/:id
 * @desc Delete data processing log (soft delete)
 * @access Private (requires authentication)
 */
router.delete(
  '/:id',
  validate({ params: dataProcessingLogIdParamsSchema }),
  authorize(COMPLIANCE_WRITE_SCOPES, 'permission'),
  dataProcessingLogController.deleteDataProcessingLog
);

module.exports = router;
