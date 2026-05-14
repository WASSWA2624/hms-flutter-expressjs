/**
 * Transfer request routes
 *
 * @module modules/transfer-request/routes
 * @description Transfer request endpoints mounted at /api/v1/transfer-requests
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const transferRequestController = require('@controllers/transfer-request/transfer-request.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createTransferRequestSchema,
  updateTransferRequestSchema,
  transferRequestIdParamsSchema,
  listTransferRequestsQuerySchema
} = require('@validations/transfer-request/transfer-request.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List transfer requests with pagination and filters
 * @method GET
 * @route /api/v1/transfer-requests/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [from_ward_id] - Filter by source ward ID (UUID)
 * @queryParams {string} [to_ward_id] - Filter by destination ward ID (UUID)
 * @queryParams {string} [status] - Filter by status (REQUESTED/APPROVED/IN_PROGRESS/COMPLETED/CANCELLED)
 * @queryParams {string} [search] - Search query
 * @bodyParams None
 * @returns {Object} Paginated list of transfer requests
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listTransferRequestsQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  transferRequestController.listTransferRequests
);

/**
 * @description Get transfer request by ID
 * @method GET
 * @route /api/v1/transfer-requests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Transfer request ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Transfer request data
 * @throws 401 Unauthorized
 * @throws 404 Transfer request not found
 */
router.get(
  '/:id',  validateRequest({ params: transferRequestIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  transferRequestController.getTransferRequestById
);

/**
 * @description Create new transfer request
 * @method POST
 * @route /api/v1/transfer-requests/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} [from_ward_id] - Source ward ID (UUID)
 * @bodyParams {string} [to_ward_id] - Destination ward ID (UUID)
 * @bodyParams {string} [status] - Transfer status (REQUESTED/APPROVED/IN_PROGRESS/COMPLETED/CANCELLED, defaults to REQUESTED)
 * @bodyParams {string} [requested_at] - Request timestamp (ISO 8601 datetime, defaults to current time)
 * @returns {Object} Created transfer request
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createTransferRequestSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  transferRequestController.createTransferRequest
);

/**
 * @description Update transfer request
 * @method PUT
 * @route /api/v1/transfer-requests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Transfer request ID (UUID)
 * @queryParams None
 * @bodyParams {string} [admission_id] - Admission ID (UUID)
 * @bodyParams {string} [from_ward_id] - Source ward ID (UUID)
 * @bodyParams {string} [to_ward_id] - Destination ward ID (UUID)
 * @bodyParams {string} [status] - Transfer status (REQUESTED/APPROVED/IN_PROGRESS/COMPLETED/CANCELLED)
 * @bodyParams {string} [requested_at] - Request timestamp (ISO 8601 datetime)
 * @returns {Object} Updated transfer request
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Transfer request not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: transferRequestIdParamsSchema, body: updateTransferRequestSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  transferRequestController.updateTransferRequest
);

/**
 * @description Delete transfer request (soft delete)
 * @method DELETE
 * @route /api/v1/transfer-requests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Transfer request ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Transfer request not found
 */
router.delete(
  '/:id',  validateRequest({ params: transferRequestIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  transferRequestController.deleteTransferRequest
);

module.exports = router;
